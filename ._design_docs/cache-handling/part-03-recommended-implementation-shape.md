# Cache Handling in `llama-server` - Part 3: Recommended Implementation Shape

Source: [../cache-handling.md](../cache-handling.md)

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
