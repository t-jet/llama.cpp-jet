# Stage 35 rework: checkpoint placement routing

Source: [../cache-handling-phase35-design.md](../cache-handling-phase35-design.md)

## Status

Status: REWORK DESIGN READY FOR REVIEW, 2026-07-07
Owner: Architect
Track: checkpoint placement
Gate: merge execution blocked until this part passes independent review and
Manager gate.

This part routes the Manager-approved pre-merge REWORK-REQUIRED row for
upstream checkpoint placement at every user message. It does not approve merge
execution or production code changes.

## Upstream SHA row

| SHA | Subject | Pre-merge row decision | Files or surfaces named by analysis |
| --- | --- | --- | --- |
| `73618f27a801` | `server: improve user message detection and create checkpoints at every user message (#24176)` | REWORK-REQUIRED | `common/chat.*`, `common/common.h`, `tests/test-chat.cpp`, `tools/server/server-common.*`, `server-context.cpp`, `server-task.h` |

Source tip for the accepted pre-merge analysis:
`origin/upstream_master` at `108f186d1701d56133a0239dd6754c8814374cbf`.

## Affected contract owners

| Owner | Contract that must survive |
| --- | --- |
| Stage 9 | Checkpoint admission attaches descriptor-owned payloads only after boundary, checksum, namespace, workload profile, and pair-state validation. |
| Stage 9 part 3 | Prepared-prompt boundaries drive checkpoint placement; raw prompt rescanning is not a checkpoint placement contract. |
| Architecture part 9 | Chat path emits prompt-span boundaries at message ends and end-of-prompt for checkpoint validation. |
| Stage 13 | Chat route metadata comes from prompt preparation and stays internal; public schemas do not gain cache fields. |
| Stage 5 | Checkpoint descriptors inherit target/draft pair-state rules. |
| Stage 25 | Checkpoint admission and payload attachment remain inside `tx_save` or the approved checkpoint transaction path. |

## Risk

Upstream now creates checkpoints at every user message. Local architecture
already added an invariant for per-message prompt-span boundaries because MTP
checkpoints can occur at message ends before the final assistant role header.
The risk is a semantic mismatch: upstream user-message detection may add
placement points that do not match local prompt-span checksum rules, or it may
use chat parsing facts before the route adapter has built
`PreparedPromptMetadata`.

A compile-clean merge can still break checkpoint safety if it admits a
checkpoint from a raw message marker, skips checksum validation, changes the
meaning of `MESSAGE_END`, or treats user-message checkpoints as public route
behavior instead of internal cache metadata.

## Required analysis before merge

Developer must complete this analysis before running any merge command:

| Analysis item | Required result |
| --- | --- |
| Placement source trace | Identify whether upstream placement uses tokenized chat metadata, raw text search, role markers, or parser events. |
| Boundary compatibility | Compare upstream user-message checkpoints to architecture part 9 prompt-span boundaries at `[0, message_token_end]`. |
| Checksum validation | Prove every admitted checkpoint validates token span and checksum before descriptor attachment. |
| Prompt-template impact | Record any changed chat template rendering or user-message detection behavior that can move token ends. |
| Route adapter trace | Trace OpenAI-compatible chat prompt preparation into `PreparedPromptMetadata`; do not infer compatibility from tests alone. |
| Fallback behavior | Define bounded diagnostics when user-message placement lacks safe boundary metadata. |
| Test impact | Identify existing unit, chat-template, and MTP checkpoint rows that must rerun or be amended. |

If upstream placement cannot be reconciled with prompt-span boundary validation,
the row remains REWORK-REQUIRED.

## Allowed integration conditions

Integration is allowed only when all conditions hold:

- The rework design review and Manager gate pass for this part.
- Upstream user-message checkpoints map to validated prompt-span boundaries or
  are disabled for hybrid checkpoint admission with a bounded diagnostic.
- Checkpoint descriptors attach only after namespace, pair state, checksum,
  boundary, and workload-profile validation pass.
- Architecture part 9 remains true for chat paths: per-message prompt-span
  boundaries and end-of-prompt boundary are emitted where structured message
  metadata exists.
- No public request or response schema changes are required for checkpoint
  placement.
- Raw prompt text is not used as the durable source of checkpoint identity.
- MTP fixture behavior is not weakened; unsupported placement gets a bounded
  miss or unsupported-runtime reason, not a false hit.

## Regression evidence required after closed rework

Minimum expanded evidence for this track:

- Unit test for `cache_metadata_from_chat_messages` or equivalent path proving
  prompt-span boundaries at user-message ends and end-of-prompt.
- Focused checkpoint admission test proving user-message checkpoint validates
  token span and checksum before descriptor attach.
- Negative test where a shifted user-message boundary rejects admission and
  emits a bounded diagnostic.
- Public chat-completion probe on a checkpoint-capable or MTP-capable fixture
  when available: first miss, later positive `cache_n` or checkpoint admission
  counter, and no boundary mismatch logs.
- Metrics shape check for checkpoint counters and bounded labels.
- Fresh upstream staleness check at regression time.

If the fixture is unavailable, Developer must provide focused C++ evidence for
metadata and admission plus a Manager-approved fixture gap before regression can
close.

## Durable doc updates if behavior changes

If merge analysis changes behavior, update the owning durable doc before merge
execution:

| Behavior change | Durable doc that must change |
| --- | --- |
| Checkpoint placement rule changes | `cache-handling-phase9-design/part-03-restore-strategy-and-prepared-prompt-boundaries.md` |
| Checkpoint descriptor admission or ownership changes | `cache-handling-phase9-design/part-02-checkpoint-payload-lifecycle-and-interfaces.md` |
| Checkpoint metrics or diagnostics change | `cache-handling-phase9-design/part-04-pairing-cold-store-metrics-and-diagnostics.md` |
| Chat-path prompt-span invariant changes | `cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md` |
| Route metadata construction changes | `cache-handling-phase13-design/part-02-metadata-construction-and-parity-rules.md` |
| Pair-state or transaction ownership changes | Stage 5 part 03 and Stage 25 part 03 respectively |

## Handoff

Next owner: independent Architect review, then Manager gate.

Handoff state: RE-REVIEW REQUIRED. Merge execution, regression runs, commits,
pushes, PRs, and reviewer responses remain unauthorized.
