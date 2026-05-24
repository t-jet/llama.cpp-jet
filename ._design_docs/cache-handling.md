# Cache Handling in `llama-server`

This note documents the cache-elimination and cache-invalidation rules that are implemented today in the server.

The server has three related but distinct mechanisms:

1. The prompt cache, which stores full serialized prompt state in host RAM.
2. Context checkpoints, which store partial rollback state attached to a live prompt or a cached prompt.
3. Live slot state, which may be cleared, saved, or purged independently of prompt-cache eviction.

## Current Implementation

The following sections describe the cache-handling rules that are implemented today.

### Prompt Cache

#### When it exists

- The prompt cache is enabled only when `--cache-ram` is nonzero.
- The cache byte limit is `cache_ram_mib` converted to bytes.
- The cache token limit is initialized from `n_ctx`.

Relevant code:

- `tools/server/server-context.cpp`: prompt-cache creation and slot-save behavior
- `tools/server/server-task.h`: `server_prompt_cache`, `server_prompt`
- `tools/server/server-task.cpp`: prompt-cache allocation, load, and eviction

#### What a cache entry contains

Each cached prompt stores:

- the prompt token sequence
- the full serialized target state
- the full serialized draft state, if present
- any attached context checkpoints

The current resident size of an entry is:

- `data.main.size()`
- plus `data.drft.size()`
- plus the sizes of all attached checkpoints

#### Insert-time elimination rules

When saving a prompt into the cache, the implementation first applies prefix-based elimination rules:

1. If an existing cached prompt fully contains the new prompt, the save is skipped.
   - Implementation: compare the longest common prefix with the new prompt, and if it equals the new prompt length, do not add a duplicate or weaker entry.
2. If the new prompt fully contains an existing cached prompt, the older cached prompt is removed as obsolete.
   - Implementation: erase any cached entry whose entire token list is a prefix of the new prompt.

These rules are content-based. They are separate from capacity eviction.

#### Admission rules

After the prefix checks, a new cache entry is rejected if either of these is true:

1. Its estimated raw size exceeds the prompt-cache byte limit.
2. Its token count exceeds the prompt-cache token limit.

The size estimate is currently:

- existing prompt metadata and attached checkpoint size
- plus raw serialized target-state size
- plus raw serialized draft-state size

This is a save rejection, not an eviction of older entries.

#### Allocation-failure rule

If memory allocation for a new cache entry fails:

1. The cache logs the failure.
2. The cache shrinks its own byte limit to roughly 40% of the current resident cache size.
3. The normal eviction pass is run immediately.
4. The current save attempt is abandoned.

#### Capacity-eviction rules

The cache eviction order is FIFO, not LRU.

The implementation stores entries in insertion order and always removes `states.front()` when limits are exceeded.

Two capacity passes are applied in `server_prompt_cache::update()`:

1. Byte-limit pass
   - While total resident cache bytes exceed the configured byte limit, remove the oldest entry.
2. Token-limit pass
   - Compute the current average bytes per token across the cache.
   - Estimate a dynamic token allowance as `limit_size / size_per_token`.
   - Use `max(limit_tokens, estimated_allowance)` as the effective token cap.
   - While total cached tokens exceed that effective cap, remove the oldest entry.

Important consequences:

- The prompt cache is not a true LRU cache.
- Byte pressure is handled before token pressure.
- The effective token cap can rise above the configured base token limit when the byte budget suggests it can fit.

#### Cache-hit behavior

Prompt-cache hits are also destructive from the cache's point of view:

1. The server selects a cached prompt only if it improves both:
   - `f_keep`: common-prefix fraction relative to the cached prompt length
   - `sim`: common-prefix fraction relative to the incoming prompt length
2. Entries with `f_keep < 0.25` are ignored.
3. When a cached prompt is restored successfully, the chosen entry is moved into the slot and erased from the cache.

So prompt-cache entries are one-shot reusable entries, not persistent shared records.

### Context Checkpoints

#### What a checkpoint contains

Each checkpoint stores:

- `n_tokens`
- `pos_min`
- `pos_max`
- serialized target partial-state bytes
- serialized draft partial-state bytes, if present

Checkpoint size is currently defined as:

- `data_tgt.size() + data_dft.size()`

#### Creation preconditions

Checkpoint creation is attempted only when:

- per-task checkpointing is still enabled
- `--ctx-checkpoints` is greater than zero
- the checkpoint-frequency logic decides a new checkpoint should be created

#### Checkpoint elimination rules

Checkpoint pruning is oldest-first.

There are three steady-state pruning rules and one invalidation rule.

#### 1. Hard count limit before insertion

Before creating a new checkpoint, the server enforces `--ctx-checkpoints`:

- while the current checkpoint count is greater than or equal to the configured limit, erase the oldest checkpoint

This guarantees that a new checkpoint can be appended.

#### 2. Pre-allocation trimming for upcoming checkpoint memory

Before allocating the next checkpoint blob, the server computes:

- `checkpoint_budget`: current full-state serialized size of target plus draft
- `checkpoint_reserve`: partial-state serialized size needed for the new checkpoint

Then it removes oldest checkpoints while:

- `current_checkpoint_bytes + checkpoint_reserve > checkpoint_budget`

This is a pre-allocation safety rule. It tries to make room before serializing the next checkpoint.

#### 3. Post-insert trimming against the live checkpoint budget

After a checkpoint is appended, the server trims again while:

- total checkpoint bytes exceed `checkpoint_budget`
- and more than one checkpoint remains

So the live checkpoint list is kept under the full-state-size budget, but the implementation avoids trimming the last remaining checkpoint in this pass.

#### 4. Position-based invalidation after context rollback or shift

After restoring or adjusting context, the server erases checkpoints whose position range is no longer valid:

- any checkpoint with `pos_max > pos_next` is removed

This removes checkpoints that refer to future positions beyond the current restored prompt position.

#### Checkpoint-disable rule

If exporting a checkpoint fails:

1. Further checkpoint creation is disabled for that task.
2. All already-saved checkpoints for that task are cleared.
3. The speculative checkpoint helper is also cleared.

This is a hard fail-open rule that preserves inference by abandoning checkpoint reuse.

#### Checkpoint trimming during prompt-cache save

When a live slot is saved into the prompt cache, its attached checkpoints are trimmed again.

The rule is:

- while there is more than one checkpoint and the total checkpoint bytes exceed the full prompt-state size being cached, erase the oldest checkpoint

This keeps cached-checkpoint memory from growing larger than the full prompt-state blob that the prompt-cache entry already stores.

### Live Slot State

These rules do not evict prompt-cache entries directly, but they do remove reusable state from active slots.

#### Slot reuse selection

When choosing a slot for a new task:

1. The server may first try to find an idle slot whose current prompt has enough LCP similarity with the new prompt.
2. If that does not produce a match, it chooses the least recently used idle slot.

This LRU rule applies to live-slot selection, not to prompt-cache eviction.

#### Save-and-clear idle slots

If `--cache-idle-slots` is enabled, then when a new task starts:

1. Every idle slot with tokens is saved to the prompt cache.
2. That slot is then cleared from live context.
3. The prompt cache eviction pass is run.

This turns idle live state into prompt-cache state, after which normal FIFO cache eviction rules apply.

`--cache-idle-slots` is automatically disabled unless both of these are true:

- `--kv-unified` is enabled
- `--cache-ram` is enabled

#### Purging idle live slots under KV pressure

If decoding cannot find enough free space in the KV cache, the server tries to recover by clearing one idle live slot:

1. Find the first idle slot that still has prompt tokens.
2. Clear its prompt and KV state.
3. Retry batching.

If no such idle slot exists, the server falls back to reducing batch size.

This is a direct purge of live slot state. It does not save the purged slot first.

#### Other live-state invalidation

The server also invalidates live prompt state in some feature-specific cases, for example:

- clearing slot prompt tokens when a LoRA change requires cache invalidation
- rewriting cached live tokens after prompt truncation or context shifting

These are not prompt-cache eviction rules, but they do affect how much reusable state remains in a slot.

### Summary of Current Policy

- Prompt cache elimination is currently FIFO plus prefix-obsolescence removal.
- Prompt-cache entries can also be rejected on admission if their raw estimated size or token count exceeds limits.
- Prompt-cache hits consume and remove the chosen entry.
- Context checkpoints are pruned oldest-first by count, by byte budget before allocation, by byte budget after insertion, and by position invalidation after rollback or shift.
- Live slots are selected by LRU when needed, but prompt-cache eviction itself is not LRU.
- Idle live slots can be saved and cleared, or purged directly under KV pressure.

## Agentic Workflow Analysis

The current implementation is usable for agentic workflows, but it fits some handoff patterns much better than others.

For a controller-style workflow where several agents pass control back and forth, the main question is whether each agent can keep either:

- a live slot of its own, or
- a stable prompt-cache entry that survives repeated returns

Today, the implementation handles the first case better than the second.

### Where the current design fits reasonably well

The current design works acceptably when the workflow looks mostly like a small set of long-lived branches:

1. If the number of active agents is less than or equal to the number of usable slots, each agent can often return to its previous live slot with little or no prompt-cache traffic.
2. If `--cache-idle-slots` is enabled, idle agent state can be spilled from live KV memory into the prompt cache when another task starts.
3. Checkpoints help when one agent repeatedly revisits nearby positions inside its own evolving prompt lineage.

In other words, the current system is strongest when reuse is local, contiguous, and mostly slot-affine.

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

### Recommended Implementation Shape

For an incremental implementation, the practical order is:

1. add an explicit CLI flag for the alternate agentic or checkpoint-aware cache mode
2. make prompt-cache restores non-destructive within that mode
3. replace FIFO eviction with LRU as the smallest correctness-preserving improvement
4. evolve that into segmented LRU or 2Q once reuse metadata is available
5. add optional root protection or pinning for controller-style workflows
6. only then consider more advanced admission control or adaptive frequency mechanisms if benchmarks justify them

This staged path keeps the first version understandable while preserving a clean path toward better agentic-workflow behavior.

## Feasibility Assessment of Additional Ideas

The ideas in `cache-ideas.md` do not all fit the current `llama-server` architecture equally well.

Some are incremental extensions of what already exists. Others require replacing the current data model, where:

- the HTTP layer applies chat templates and tokenization before work reaches `server_context`
- `server_context` sees flattened `server_tokens`, not original message objects
- the prompt cache stores full token sequences plus full serialized target and draft state blobs
- checkpoints are lineage-local attachments to a live prompt or cached prompt, not first-class shared branch nodes

This whole improvement set makes the most sense as an alternate cache mode behind an explicit CLI flag.

- The current implementation should remain the default path for plain-transformer workloads.
- The alternate mode is more justified for branch-heavy agentic workflows and for models where safe rollback is limited enough that checkpoints become the primary reusable restore points.

The following assessments are based on those constraints.

### Special note on non-plain-transformer models

The current code already distinguishes models whose reusable state cannot be managed purely by remembering a token prefix.

- During prompt processing, the server creates checkpoints when the target context only supports full rollback, supports only bounded rollback, or uses SWA. Concretely, the current decision gate is based on `COMMON_CONTEXT_SEQ_RM_TYPE_FULL`, `COMMON_CONTEXT_SEQ_RM_TYPE_RS`, or `n_swa > 0`.
- When the live memory can no longer safely preserve the old prefix, the server searches for a checkpoint and restores partial state from checkpoint bytes. If no suitable checkpoint exists, it falls back to full prompt re-processing.
- Exact prompt-cache hits are different. The current prompt-cache load path restores full serialized target state and full serialized draft state directly from stored blobs stored in the prompt-cache entry itself, so exact-state restore is not limited to checkpoint boundaries.
- For MTP variants, including Qwen 3.6 MTP-style target plus draft setups, the important rule is that target and draft state move together. The current code already does that for prompt-cache entries and for checkpoints.

The consequence is:

- for plain transformers, tokens and full-state blobs often cover most useful reuse cases
- for SWA, hybrid, recurrent, RS-limited, and MTP-heavy cases, tokens and checksums are primarily lookup metadata
- for those models, full-state blobs are still useful as exact restore objects, but checkpoints are the better canonical branch points between those exact snapshots
- so the natural long-term shape is hybrid: frequently used full-state blobs stay hot, colder full-state blobs can be demoted, and checkpoints provide the branch structure underneath

### 1. Keep only checkpoints and checksums plus token-count metadata between them

Feasibility: possible as an opt-in long-term redesign, but it should not replace full-state blobs entirely. The stronger direction is a hybrid design, not a checkpoint-only design.

- Today, each prompt-cache entry stores a full `server_tokens` sequence and a full serialized target state, plus a full serialized draft state when `ctx_dft` exists.
- Today, `server_prompt_cache::load()` assumes a complete state blob can be loaded directly into a slot. The restore path does not traverse a checkpoint graph and replay a suffix from an intermediate branch point.
- Today, checkpoints are not first-class cache nodes. They are attached to one `server_prompt`, pruned oldest-first, and used only as rollback aids inside that prompt lineage.
- In the current code, exact prompt-cache hits still restore full serialized target and draft blobs directly. That makes those blobs a natural hot exact-restore tier for selected roots or leaves.
- A blob-only redesign would make the branch structure depend too much on when `prompt_save()` happened to run. That is acceptable for a first incremental cache improvement, but it is weaker than explicit branch points for checkpoint-dependent models.
- The place where checkpoints become necessary is not the exact hit itself, but branch rollback and prefix reuse after the safe rollback window has been exceeded.
- Replacing the current flat cache with checkpoint nodes plus hashed spans would require a new branch index or tree, new admission and eviction logic, and a new restore path that can resume from an interior checkpoint rather than only from a full prompt snapshot.
- This idea is more feasible for multimodal prompts than it first appears because media chunks already receive an FNV content hash before they enter `server_tokens`. That helps with media identity, but it does not remove the need for a new cache graph and matching scheme for text spans.
- The current server also avoids creating checkpoints immediately after multimodal chunks, so a checkpoint-centric design would need new multimodal checkpoint work before it could become a general replacement.
- If this direction is explored, it should stay optional. The better end state is: full-state blobs remain available as exact-restore objects, with hot or cold placement determined by usage, while checkpoints become the primary branch nodes and tokens plus checksums become the metadata used to locate the right branch and boundary.

Assessment:

- promising as a research path for branch-heavy or memory-sensitive workflows
- especially relevant for models whose safe reuse is checkpoint-first rather than token-first
- should be treated as a hybrid target, not as an argument to discard full-state blobs
- not the best first implementation step
- should come only after the in-memory reuse policy for full-state blobs is fixed

### 2. Set checkpoint boundaries at message boundaries instead of token boundaries

Feasibility: medium, and much stronger if boundaries are defined after prompt preparation rather than before it.

- The HTTP layer owns JSON parsing, chat-template application, and tokenization. By the time a request reaches `server_context`, it has already been flattened into `server_tokens`.
- That means `server_context` does not know where original user, assistant, tool, or system messages ended.
- The clean boundary definition is therefore not the raw message JSON. It is the prepared prompt after the template has inserted role markers, separators, generation prefixes, multimodal placeholders, and any other syntax the model expects.
- Re-discovering those boundaries by scanning the final prompt string heuristically would be brittle.
- A cleaner design is to extend the prompt-preparation layer so it returns boundary spans together with the prepared prompt, similar in spirit to how `common_chat_templates_apply()` already returns grammar triggers and preserved tokens.
- The HTTP layer could then tokenize the prepared prompt and convert those spans into token or position boundaries carried on `server_task`.
- If the alternate cache mode wants analogous boundaries for `/completion`, it should route those inputs through the same prepared-prompt interface, or a lightweight wrapper that produces equivalent markers. The current `/completion` path does not apply chat templates today, so that part would be new behavior.
- Truly raw prompt arrays would still need token-based or position-based fallback rules when no prepared-prompt boundaries exist.
- The current server also skips checkpoint creation after multimodal chunks, so message-boundary checkpointing would still need separate rules when a message ends with image or audio content.

Assessment:

- good as a prepared-prompt boundary source, not as raw-message metadata
- best implemented as an explicit template or prompt-preparation API addition
- not a clean replacement for token or position based checkpointing
- worth considering only after boundary metadata is explicitly carried into `server_context`

### 3. Offload to a cold on-disk cache layer

Feasibility: medium, but only after both checkpoint payloads and full-state blob payloads are separated from the in-RAM branch index.

- There is already a file-based slot save and restore feature, which proves that on-disk state transfer is viable in principle.
- That existing feature is much narrower than the proposed cold layer. It saves only the target context, not the draft context, uses a manual API, is not integrated with prompt-cache eviction, and is explicitly unsupported for multimodal requests.
- This fits best with a hybrid design where exact full-state blobs and checkpoints both have hot and cold residency based on usage, while branch lookup metadata stays resident in RAM.
- For this idea set, the cold-layer target is not only checkpoint payload bytes. Less frequently used full-state prompt-cache blobs should also be eligible for cold offload to free host RAM.
- In practice that means keeping the branch index hot in memory: token or checksum spans, branch topology, `n_tokens`, `pos_min`, `pos_max`, usage data, and residency metadata. The bulky bytes behind both prompt-cache full-state blobs and checkpoints should be eligible to move to disk.
- The current implementation cannot do that directly because both kinds of payload are inline today: full-state blob bytes live in `server_prompt.data.main` and `server_prompt.data.drft`, while checkpoint bytes live inside `common_prompt_checkpoint`, with no indirection or resident or not-resident state.
- The current cache policy runs inside the single-threaded `server_context`. Synchronous disk IO would therefore directly affect scheduling latency unless the design explicitly accepts that tradeoff or introduces more machinery.
- Full parity would still need to preserve target plus draft coupling and handle multimodal branches carefully.

Assessment:

- feasible as a staged feature
- the right shape for this idea set is usage-based payload offload for both full-state blobs and checkpoints, not RAM-only blobs plus cold-only checkpoints
- easiest if introduced after the in-memory branch index and reuse policy are made explicit
- depends on adding payload handles or descriptors rather than using the current inline blob and checkpoint storage

### 4. Think about cache as a wood and trees

Feasibility: strong conceptual direction, but architectural rather than incremental.

- This model matches controller and worker branching much better than the current flat FIFO list.
- The current prompt cache actively removes shorter ancestors when a longer descendant is saved. That is the opposite of a tree that preserves reusable branch roots.
- A real tree or wood model would need branch points to become first-class cache nodes with parent-child relationships, reference semantics, and reuse metadata.
- That is closely related to non-destructive hits, protected roots, and checksum-based branch traversal. In practice these are not separate features; they are pieces of the same redesign.

Assessment:

- likely the right long-term mental model for agentic workflows
- too large to be the first implementation step
- best approached only after the simpler segmented-reuse policy is in place

### 5. Do not separate cache between slots

Feasibility: partly already implemented.

- The prompt cache is already shared across slots. Any idle slot can save into it, and any later slot can restore from it.
- What remains slot-local is live KV state and the checkpoint list attached to the slot's current prompt lineage.
- So this idea is already true for the prompt cache in a limited sense. The missing piece is a shared branch-store model where slots reference common cache nodes instead of moving entries into slot ownership on restore.

Assessment:

- partially implemented today
- fully realizing it depends on non-destructive hits and a shared branch-node model

### 6. Keep MTP and draft-model cache state synchronized with the main model

Feasibility: mostly already true for the in-memory cache and checkpoints; the bigger remaining issue is making checkpoint-first restore explicit for the models that need it.

- Prompt-cache entries already store both the target state and the draft state.
- Checkpoints already store both target and draft partial state.
- Prompt save, prompt load, checkpoint export, and checkpoint restore already treat `ctx_tgt` and `ctx_dft` as a pair when a draft context exists, including MTP-style draft contexts.
- For MTP models such as Qwen 3.6 MTP-style setups, exact full-state prompt-cache restore and checkpoint restore already follow the same target-plus-draft pairing rule.
- The remaining design question is not whether target and draft should stay synchronized. They should. The real question is how to organize reuse: exact full-state blobs should stay available as exact-return objects, with hot or cold placement driven by usage, but the alternate cache mode should still treat checkpoints as the primary reusable branch points for those models.
- The main remaining gap is the file-based slot save and restore path, which currently serializes only the target context and does not support multimodal requests.
- Any future cold layer should preserve the current rule that main and draft state move together rather than introducing separate offload or eviction policies for them, whether the payload being moved is a full-state blob or a checkpoint.

Assessment:

- largely solved for RAM-resident exact-state restore and checkpoint restore
- not yet solved for a disk-backed checkpoint-payload layer
- should be treated as a design constraint and as a reason to make the alternate mode checkpoint-first on these models

### 7. Reuse model-generated tokens up to the point where external information is needed

Feasibility: low as a general server cache feature; maybe viable only as a very narrow deterministic mode.

- This is output memoization, not prompt-state reuse.
- The current cache stores prompt processing state. It does not index generated continuations or replay model output.
- Correctness depends on decoding settings, backend determinism, tool results, and user inputs. The current server already documents that prompt caching can change exact logits, so output replay has stricter correctness requirements than prompt reuse.
- The server can detect tool-call structure at the protocol layer, but that does not by itself make output reuse safe. Safe replay would likely need greedy or otherwise tightly constrained decoding plus explicitly trusted workflow rules.

Assessment:

- not a natural extension of the current prompt cache
- better treated as a separate deterministic output-cache feature, if pursued at all
- high risk of surprising behavior if generalized too early

### 8. Support explicit markers for cacheable positions, similar to Anthropic prompt caching

Feasibility: medium, and one of the strongest near-term extensions.

- There is currently no cache marker, cache-control, pinning, or protected-root metadata anywhere in the request path or slot state.
- The Anthropic-compatible endpoint currently converts requests into the same normal chat pipeline, so any marker support would need to survive request conversion, chat-template application, and tokenization.
- Once marker metadata reaches `server_context`, it fits naturally with the ADR recommendation for protected branch roots or pinning.
- This is much more incremental than replacing the cache with a full checkpoint tree, and it directly addresses the controller-style need to preserve short shared roots.

Assessment:

- one of the best candidate follow-ups after non-destructive hits and reuse-aware eviction
- pairs naturally with message-boundary metadata for chat requests
- gives the user or controller an explicit way to declare branch roots as important

### Net Finding

The ideas fall into three broad groups.

Global constraint:

- this should be an alternate CLI-selected cache mode, not the default replacement for the current prompt cache
- it is more justified for checkpoint-dependent or branch-heavy workloads than for plain transformers
- the most coherent shape is hybrid: full-state blobs as the exact-restore layer with usage-based hot or cold residency, and checkpoints as the canonical branch structure where rollback is limited

Near-term and incremental:

- a CLI flag that selects the alternate cache mode
- non-destructive prompt-cache hits and reuse-aware eviction around the existing full-state prompt-cache blobs
- explicit protected roots or cache markers
- prepared-prompt boundary metadata, once boundary positions are emitted by the prompt-preparation layer and carried into `server_context`

Medium-term and staged:

- a hybrid cache with usage-based offload for both full-state blobs and checkpoint payloads while keeping branch metadata resident in RAM

Long-term and architectural:

- checkpoint-first cache entries with checksum-based traversal
- an explicit tree or wood of shared branch nodes
- fully slot-independent branch pointers into a shared cache graph

Already largely handled in RAM:

- full-state target and draft blobs for exact prompt-cache hits
- synchronized target and draft state for prompt-cache entries and checkpoints

High-risk and probably separate from prompt caching proper:

- replaying generated model output up to tool or user boundaries

### Recommended Staging Relative to These Ideas

The practical order still looks like this:

1. add an explicit CLI flag for the alternate cache mode and keep the current cache path as default
2. make prompt-cache hits non-destructive in that mode and treat the existing full-state blobs as the exact-restore tier
3. replace FIFO eviction with LRU, then segmented LRU or 2Q
4. add protected roots or explicit cache markers for the full-state blob tier
5. extend prompt preparation to emit boundary positions and carry them into `server_context`
6. for checkpoint-dependent models, treat checkpoints as primary reusable branch points while keeping target plus draft state paired
7. separate payload descriptors from payload bytes for both full-state blobs and checkpoints
8. add a cold layer that offloads less-used full-state blobs and checkpoint payloads based on usage, while keeping branch metadata resident in RAM
9. only then experiment with fuller checkpoint-first or tree-based cache representations above that hybrid base
10. treat generated-output replay as separate feature work, not as a direct continuation of prompt-cache refactoring
