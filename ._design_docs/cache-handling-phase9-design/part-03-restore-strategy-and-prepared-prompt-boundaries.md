# Stage 9 design: restore strategy and prepared-prompt boundaries -- Part 3

Source: [../cache-handling-phase9-design.md](../cache-handling-phase9-design.md)

## Restore planner inputs

The Stage 9 restore planner receives:

- prepared prompt tokens and task metadata
- workload profile and target/draft overlay
- compatibility namespace
- branch lookup candidates
- descriptor residency and integrity metadata
- boundary spans from `PreparedPromptMetadata` when available
- cold-promotion availability from the I/O layer

The planner must validate compatibility before ranking candidates. It must not
count rejected candidates as hits.

## Plain-transformer strategy

For `plain_transformer` workloads:

1. Validate namespace and pair state.
2. Prefer the deepest valid exact blob candidate.
3. If the exact blob is cold, request paired promotion before live mutation.
4. If no exact blob is valid, consider a checkpoint only when the checkpoint
   matches the selected branch path, boundary constraints, and runtime state.
5. If the selected node is metadata-only, use Stage 8 path validation before
   re-materialization.
6. Fall back to recompute when descriptor validation, promotion, or restore
   application fails.

Checkpoint use in this profile is opportunistic. It must not make plain
transformer workloads slower or less predictable than the exact-blob path.

## Checkpoint-dependent strategy

For `checkpoint_dependent` workloads:

1. Validate namespace and pair state.
2. Traverse checkpoint-bearing nodes as the canonical branch path.
3. Prefer the deepest valid checkpoint candidate that satisfies runtime
   restrictions and boundary rules.
4. Use exact blobs as accelerators or roots when they are valid for the same
   branch path.
5. If a selected checkpoint payload is cold, request paired promotion before
   live mutation.
6. If the selected checkpoint node is metadata-only, re-materialize from the
   nearest retained payload-bearing ancestor or root after validation.
7. Fall back to recompute when no safe checkpoint path exists.

For these workloads, exact blobs do not replace checkpoint branch continuity.
They can shorten replay, but the checkpoint graph remains authoritative for
branch traversal.

## Prepared-prompt boundary behavior

Checkpoint placement should use prepared-prompt boundaries when the task has
them. Boundary-aware placement is allowed for:

- system or developer setup spans
- message boundaries
- tool call and tool response spans
- media placeholder spans
- generation prompt boundaries

Placement rules:

- Attach checkpoints at boundary ends when the runtime emits a checkpoint close
  enough to the boundary for the controller to validate the same token span.
- Do not create a boundary-attached checkpoint from raw prompt text rescanning.
- Store the boundary ID or stable boundary fingerprint in checkpoint metadata.
- Treat labels and marker strings as untrusted metadata. They must not affect
  file paths or shell commands.
- If boundary metadata is missing, use token or position fallback and emit a
  degraded-boundary diagnostic.

For `/completion`, Stage 9 may use token or position fallback. The design does
not add new request fields to make completion requests boundary-aware.

## Boundary validation

When a checkpoint claims a prepared boundary, restore validation must confirm:

- token span length matches
- checksum or equivalent token-range validation matches
- namespace and workload profile match
- boundary kind is compatible with the selected placement rule
- media spans and projector identity match for multimodal prompts

If validation fails, the planner rejects that checkpoint and follows the Stage 8
mismatch-parent rules when branch metadata partially validated.

## Target and draft restore application

The planner can choose a checkpoint or exact blob, but restore application must
remain atomic for the active pair state.

For `target_only`:

- apply target state only
- reject descriptors that require a draft side

For `target_and_draft`:

- promote or load both sides before live mutation
- validate both sides before applying either side
- apply target and draft as one transaction
- on apply failure, leave the slot in a known-empty or known-valid state and
  recompute

Partial restore is not a valid fallback.

## Fallback behavior

Every restore failure falls back to a valid slower path. Required fallback
reasons include:

- namespace mismatch
- unsupported workload profile
- missing boundary metadata for a boundary-required checkpoint
- token or checksum validation mismatch
- missing hot or cold payload
- descriptor version mismatch
- checksum mismatch
- partial target/draft availability
- promotion timeout or worker failure
- live restore application failure

The fallback path must emit diagnostics and must not mutate the chosen branch
node as if the restore succeeded.
