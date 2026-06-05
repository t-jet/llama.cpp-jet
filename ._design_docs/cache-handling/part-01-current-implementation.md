# Cache Handling in `llama-server` - Part 1: Current Implementation

Source: [../cache-handling.md](../cache-handling.md)

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

