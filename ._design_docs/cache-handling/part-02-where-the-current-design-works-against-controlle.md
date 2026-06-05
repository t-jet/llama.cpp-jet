# Cache Handling in `llama-server` - Part 2: Where the current design works against controller patterns

Source: [../cache-handling.md](../cache-handling.md)

### Where the current design works against controller patterns

Controller-style handoffs usually create several sibling branches that all share an important short root prompt. The current cache policy is not optimized for that shape.

#### 1. Prompt-cache hits are destructive

When a cached prompt is restored, the entry is removed from the prompt cache.

That is a poor fit for a hot controller root that many agents may revisit repeatedly. A branch point that is valuable precisely because it is shared is treated as a one-shot object.

#### 2. FIFO eviction does not protect hot branch roots

The prompt cache evicts the oldest entry, not the least useful or least recently reused entry.

In a controller workflow, a frequently reused controller prompt can still be evicted simply because many newer worker prompts were saved after it. The policy tracks insertion order, not reuse value.

#### 3. Prefix-obsolescence removal favors longer descendants over shorter branch points

If a newly saved worker prompt fully contains an older controller prompt, the older cached controller prompt is removed as obsolete.

That makes sense for linear prompt growth, but it is a weak fit for branching workflows. In a controller pattern, the shorter controller state is often the more reusable asset because many future worker branches start from it.

#### 4. Prompt selection prefers strictly better similarity on both axes

The prompt-cache lookup replaces the current slot state only when a cached entry is strictly better on both preserved-context fraction and similarity to the incoming prompt.

In branch-heavy handoffs, a shorter controller root may be a better semantic branch point while tying, not strictly beating, the current slot on one of those metrics. That means some potentially useful branch-point restores may not be chosen.

#### 5. Checkpoints are lineage-local, not branch-addressable

Checkpoints are indexed by prompt position metadata and help restore earlier positions inside one prompt lineage.

They are not a general branch store for controller and worker identities, and they do not provide an explicit way to keep several sibling branch roots resident as named reusable states.

#### 6. `--cache-idle-slots` can create churn in short-turn workflows

Saving every idle slot whenever a new task starts can help preserve state, but in a controller pattern with many short back-and-forth turns it also creates repeated serialization and repeated FIFO insertion into the prompt cache.

That can increase turnover exactly when the workflow would benefit from keeping a few hot shared roots stable.

### Net fit for multi-agent handoff workloads

The current implementation is a reasonable fit when:

- there are enough slots to keep the controller and its most active workers live
- most reuse happens by returning to the same slot
- prompt evolution is mostly monotonic within each agent
- checkpoints are used as local rollback aids rather than as a cross-agent branch store

The current implementation is a weak fit when:

- several agents alternate rapidly through a shared controller state
- the number of active branches exceeds the number of slots
- the most valuable reusable states are short shared roots rather than the newest longest prompts
- reuse value depends on revisiting the same branch point many times, not just once

### What this means for future cache work

For controller-style workflows, the bigger policy mismatches are:

1. destructive prompt-cache hits
2. FIFO eviction instead of reuse-aware eviction
3. automatic removal of shorter prefix states when a longer descendant is cached
4. lack of a first-class notion of protected or pinned branch roots
5. prompt selection based only on token-prefix heuristics rather than explicit workflow identity

So the current implementation can support agentic handoffs, but it is tuned more for linear prompt reuse and slot spillover than for stable multi-branch controller patterns.

## ADR: Cache Policy for Agentic Workflows

### Status

Proposed.

### Context

For controller-style agentic workflows, the cache should optimize for repeated returns to a small set of shared branch roots and near-root descendants. That workload differs from simple linear prompt growth in three important ways:

1. The most valuable cached states are often short shared roots, not the newest longest descendants.
2. A useful cached state is often reused many times, so destructive cache hits are counterproductive.
3. Cache entries are large and uneven in size, so byte-aware eviction matters more than entry count alone.

The current FIFO prompt cache with destructive hits and prefix-obsolescence removal is therefore not a strong fit for the target workload.

### Decision Drivers

The best policy for `llama.cpp` should balance these constraints:

- improve reuse for controller and worker handoffs
- preserve hot shared roots instead of treating them as obsolete one-shot entries
- remain simple enough to implement inside the current server architecture
- work with resident-byte accounting
- stay optional and leave the current cache path available for plain-transformer workloads
- improve checkpoint-centric reuse for models whose rollback window is limited
- avoid expensive global bookkeeping or background threads
- behave predictably in a single-threaded `server_context`

### Options Considered

#### Option 1. Plain LRU with non-destructive hits

Under this option:

- cache hits do not erase the restored entry
- every hit promotes the entry to most-recently-used
- byte-limit eviction removes the least-recently-used entry first
- prefix-obsolescence removal is either removed or narrowed substantially

Advantages:

- much better fit than FIFO for repeated controller-root reuse
- conceptually simple and easy to explain
- incremental to the current implementation
- naturally composes with byte-based budgeting because resident bytes remain the main budget signal

Drawbacks:

- LRU is recency-aware, not frequency-aware
- a temporary burst of one-off worker branches can still displace a controller root if it is not touched often enough
- LRU alone does not distinguish between a very large state and a smaller state with similar reuse value
- it still lacks explicit protection for branch roots that are known to be strategically important

Assessment:

- strong minimum improvement
- likely good enough for many workloads
- not the best long-term fit for controller-heavy branch reuse

#### Option 2. LFU or LFU-like reuse-frequency cache

Under this option:

- entries accumulate a reuse score
- eviction prefers entries with the lowest observed reuse count or combined reuse score
- hits are non-destructive

Advantages:

- better than LRU at protecting hot controller roots that are revisited frequently over time
- more robust against bursts of cold worker branches

Drawbacks:

- pure LFU adapts poorly when the workflow changes phase and older popularity stops mattering
- it needs aging or decay to avoid stale popularity dominating forever
- it is harder to reason about and tune than LRU
- frequency alone is not enough because entry size matters a lot in this cache

Assessment:

- attractive in theory for shared roots
- too awkward as a first implementation unless combined with a more practical recency mechanism

#### Option 3. ARC or TinyLFU-style adaptive cache

Under this option:

- the cache combines recency and frequency signals
- admission and eviction adapt based on observed reuse behavior
- hot roots and recently active branches both get some protection

Advantages:

- strongest general-purpose cache behavior in mixed workloads
- adapts better than plain LRU or pure LFU when workflows shift between phases
- can protect both hot roots and recently reactivated branches

Drawbacks:

- significantly more implementation complexity
- more metadata and policy machinery for relatively small numbers of very large entries
- harder to validate and tune in the current server
- a poor first step if the main goal is to land a maintainable improvement soon

Assessment:

- good theoretical target class
- too complex for an initial `llama.cpp` server implementation

#### Option 4. Segmented LRU or 2Q with resident-byte accounting and optional pinning

Under this option:

- cache hits are non-destructive
- newly inserted entries go into a probationary segment
- entries that are reused move into a protected segment
- eviction happens from the probationary segment first, then from the protected segment if needed
- byte accounting remains based on resident stored bytes
- selected states such as controller roots may be optionally pinned or protected from normal prefix-obsolescence removal

Advantages:

- better fit than plain LRU for repeated controller-root reuse
- naturally distinguishes one-hit worker branches from genuinely reusable shared roots
- much simpler than ARC or TinyLFU
- works well with current resident-byte budgeting
- maps cleanly to the current server's limited metadata model
- optional pinning provides an explicit escape hatch for known branch roots

Drawbacks:

- more complex than plain LRU
- still heuristic, not globally optimal
- optional pinning requires either API support or internal heuristics for identifying protected roots
- can retain stale protected entries if protection policy is too aggressive

Assessment:

- best balance between cache quality and implementation practicality
- the strongest candidate for `llama.cpp`

### Decision

If this work is pursued, it should be an alternate cache mode selected by an explicit CLI flag, not a replacement for the current default cache path.

The recommended direction for `llama.cpp` is:

1. make prompt-cache hits non-destructive
2. replace FIFO eviction with resident-byte-aware segmented LRU or 2Q behavior
3. stop treating all shorter prefix states as automatically obsolete
4. add an explicit notion of protected branch roots, either via pinning or a narrow protection policy

In short, the best option to implement is a size-aware segmented recency cache for prompt states, not a pure FIFO cache and not a fully adaptive ARC or TinyLFU design.

### Why This Is the Best Fit for `llama.cpp`

This option is the best fit because it respects the codebase's current constraints:

- it can be implemented as an evolution of the existing prompt-cache container rather than a separate subsystem
- it keeps policy decisions local to `server_context` and `server_prompt_cache`
- it uses resident-byte accounting that already exists
- it can remain behind an explicit CLI flag so plain-transformer users keep the current behavior
- it improves multi-agent reuse without requiring a first-class distributed workflow scheduler
- it avoids the complexity cost of advanced adaptive caches while addressing the main failure modes of FIFO

### Expected Advantages in `llama.cpp`

If implemented well, this approach should provide:

1. better retention of hot controller roots across many worker handoffs
2. less churn from one-off descendant prompts
3. fewer cases where the most reusable short root is displaced by newer but less valuable long descendants
4. a clearer path to optional workflow-aware features such as named roots, pinned prompts, or branch identifiers
5. a better fit for models whose reusable branch points are defined by checkpoints rather than by arbitrary token offsets

### Expected Drawbacks in `llama.cpp`

The tradeoffs are real:

1. the implementation is more complex than the current FIFO list
2. cache behavior becomes somewhat less transparent because there are protected and probationary states
3. non-destructive hits may keep more resident state alive, so byte accounting becomes more important
4. pinning or root protection can be abused and may reduce effective cache capacity if overused
5. this still does not make checkpoints into a general branch store; checkpoints remain lineage-local rollback aids

### Explicit Non-Decision

This ADR does not recommend implementing a fully adaptive ARC or TinyLFU-style cache as the first step.

Those algorithms may produce better hit rates in some mixed workloads, but they are not the best first option for `llama.cpp` because the incremental engineering cost is high relative to the expected immediate benefit.

