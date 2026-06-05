# Stage 9 design: checkpoint integration and workload profiles -- Part 1: scope and workload profiles

Source: [../cache-handling-phase9-design.md](../cache-handling-phase9-design.md)

## Goal

Stage 9 makes checkpoint payloads part of the branch graph instead of keeping
them as lineage-local slot artifacts. The restore planner uses an explicit
workload profile to choose whether exact blobs or checkpoints are the primary
restore structure.

## Stage 8 baseline carried forward

Stage 8 closed with these properties:

- branch nodes can be payload-bearing or metadata-only
- payload eviction and branch pruning are separate lifecycle events
- re-materialization validates request tokens before replay
- validation mismatch creates a new branch from the latest validated ancestor
- equivalent validated branches are deduplicated
- cold cleanup checks descriptor ownership before deleting payload data

Stage 9 builds on that baseline. It does not replace the Stage 8 mismatch,
deduplication, pruning, or cleanup rules.

## Workload profiles

The cache controller derives one workload profile for each task namespace. The
profile is part of the compatibility namespace and must participate in branch
lookup, descriptor admission, and restore planning.

| Profile | Meaning | Restore preference |
| --- | --- | --- |
| `plain_transformer` | A normal transformer context where exact full-state restore is valid and efficient. | Prefer the deepest valid exact blob. Use checkpoints only when valid and cheaper than recompute. |
| `checkpoint_dependent` | A model or context mode constrained by SWA, recurrent state, rollback limits, RS limits, or an equivalent restriction. | Traverse checkpoint nodes first. Treat exact blobs as accelerators or roots, not as the source of branch continuity. |
| `target_plus_draft` | A runtime with a target and model-backed draft context. This is a pairing overlay on either restore profile. | Apply the chosen restore strategy to the target/draft pair atomically. |

`target_plus_draft` does not replace `plain_transformer` or
`checkpoint_dependent`. It records that the payload has a draft side and that
pairing rules apply to save, restore, promotion, demotion, and eviction.

## Profile detection

Profile detection must use initialized runtime facts and request configuration,
not caller-provided hints.

Inputs include:

- target model capabilities known after load
- active context mode, including SWA, recurrent, RS-limited, or rollback-limited behavior
- initialized draft-context shape from Stage 5, including separate draft and MTP modes
- request route and prompt form only where it changes available boundary metadata
- tokenizer, template, LoRA, control vector, multimodal projector, and media-layout compatibility data already carried by the namespace

Detection rules:

1. If the initialized runtime has SWA, recurrent behavior, RS limits,
   rollback limits, or an equivalent context restriction, use
   `checkpoint_dependent`.
2. Otherwise use `plain_transformer`.
3. If a draft context exists, attach the `target_plus_draft` overlay and include
   the richer speculative-mode identity in the compatibility key.
4. If the controller cannot classify a runtime safely, treat it as
   `checkpoint_dependent` only when checkpoint metadata and payloads are usable.
   Otherwise log an unsupported-profile fallback and recompute.

The controller must not infer a profile from prompt text or from a request
field supplied by the client.

## Namespace behavior

The workload profile is part of the namespace. Branches from different profiles
must not match each other unless a later reviewed design defines an explicit
compatibility bridge.

Namespace material for Stage 9 includes:

- target model identity
- draft model identity or draft absence
- speculative context mode, including MTP versus non-MTP draft context
- tokenizer and prompt-template compatibility
- active adapters and control vectors
- multimodal projector identity and media token layout when present
- workload profile and target/draft overlay

If any namespace field is missing or mismatched, the planner rejects the
candidate and falls back without refreshing hit counters or recency for the
rejected node.

## Interface impact

Stage 9 adds or extends internal interfaces only.

| Interface | Stage 9 requirement |
| --- | --- |
| `BranchNode` | May reference both an exact blob descriptor and a checkpoint descriptor. Either reference may be absent. |
| `PayloadDescriptor` | `payload_kind` must distinguish exact blob from checkpoint. Pair state, version, size, checksum, store reference, and residency state remain required. |
| `RestorePlan` | Must record the strategy, selected node, selected payload kind, required promotions, validation result, and fallback reason. |
| `PreparedPromptMetadata` | Supplies boundary spans used for checkpoint placement and validation. Missing metadata triggers degraded diagnostics. |
| Cache controller | Selects the workload profile, validates namespace, ranks candidates, and owns checkpoint admission decisions. |

No new HTTP fields, route shapes, or `/slots` semantics are part of Stage 9.
