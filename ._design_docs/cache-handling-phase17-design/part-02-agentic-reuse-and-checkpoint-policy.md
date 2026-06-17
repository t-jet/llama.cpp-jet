# Stage 17 design: agentic reuse and checkpoint policy -- Part 2

Source: [../cache-handling-phase17-design.md](../cache-handling-phase17-design.md)

## Agentic prompt classes

Stage 17 classifies large chat prompts by boundary shape and prompt identity
evidence:

| Class | Shape | Intended reuse |
| --- | --- | --- |
| Exact repeat | Same namespace, token count, checksum, and boundary evidence. | Exact full-state blob or checkpoint restore. |
| Same branch continuation | Same agent conversation continues from current branch tip. | Restore exact branch tip when available; otherwise recompute safely. |
| New user turn | Same system/tool prefix, new conversation-specific user span. | Prefix reuse policy evidence only in Stage 17. |
| Different agent same prefix | Same system/tool prefix, different agent instance or first user branch. | Prefix reuse policy evidence only in Stage 17. |
| Different namespace | Runtime, model, tokenizer, tool, adapter, media, or draft identity differs. | Reject reuse. |

## Exact restore policy

Exact restore remains the only Stage 17 restore implementation target. An exact
restore is allowed only when:

- namespace matches
- pair state matches
- token count matches
- token-span checksum matches
- descriptor integrity and residency checks pass
- target/draft restore can apply atomically
- route and workload profile support the selected restore type

Any mismatch falls back to recompute and records a bounded miss reason.

## Prefix restore policy

Large agentic prompts often share a system and tool prefix while the user turn
changes. Prefix restore could save work, but it is only correct when the cache
can prove that the restored model state represents the requested prefix under
the same namespace and prompt rendering rules.

Stage 17 designs evidence and policy for prefix restore but does not require
prefix restore implementation. This keeps code scope smaller and preserves
correctness while the evidence proves whether prompt drift is exact-miss noise
or a real prefix-reuse opportunity.

A future prefix restore implementation must satisfy all checks below:

- Same namespace and pair state.
- Candidate prefix token span is a strict prefix of the requested tokens.
- Prefix token checksum matches the requested token prefix.
- Prefix ends at an approved semantic boundary.
- Candidate payload is valid, paired, and restorable before live mutation.
- The remaining suffix can be processed as normal prompt input from the
  restored state without replaying generated output.
- Checkpoint-dependent and MTP workloads use checkpoint-safe restore points,
  not arbitrary token offsets.

Until those checks are implemented, prefix candidates are classified as
`unsafe_prefix_rejected`, not hits.

## Semantic branch points

For agentic chat prompts, reusable prefix candidates should be admitted at
semantic branch points:

- end of shared system and developer setup
- end of tool definition block
- immediately before the first user boundary that starts the
  conversation-specific branch
- final prompt state after inference completes

Intermediate checkpoints inside one setup block should not be admitted merely
because the runtime emitted them. They consume payload budget and rarely help
reuse when later requests diverge by user turn or agent instance.

## Checkpoint-density policy

Stage 17 reduces dense checkpoint admission for agentic chats by default.
Runtime checkpoint creation can still occur, but cache admission should prefer
semantic branch points instead of every nearby internal checkpoint.

Admission rules:

1. Honor `--ctx-checkpoints 0` as disabling checkpoint creation and therefore
   checkpoint cache admission.
2. Honor `--ctx-checkpoints N` as the upper bound on runtime checkpoints that
   may be considered for cache admission.
3. Honor `--checkpoint-min-step N` as a hard minimum spacing for non-semantic
   checkpoint admissions.
4. Admit semantic branch-point checkpoints even when nearby non-semantic
   checkpoints are skipped, subject to the `--ctx-checkpoints` bound.
5. Skip dense non-semantic checkpoints when they do not improve the selected
   branch policy.
6. Keep exact full-state blobs available as exact accelerators.

The implementation should expose skipped-admission diagnostics by bounded
reason, not by prompt text.

## Compatibility exception

For checkpoint-dependent, SWA, recurrent, RS-limited, target-plus-draft, and
MTP-heavy modes, checkpoints remain canonical branch structure when required
for correctness. Stage 17 must not disable checkpoint admission that the
workload profile marks as required.

The exception is narrow:

- keep required checkpoint nodes for continuity
- apply spacing and semantic filtering only to optional extra checkpoints
- preserve Stage 9 checkpoint-first restore behavior
- preserve Stage 16 prompt-span boundary invariant for chat paths

## Interfaces

The restore planner needs:

- an agentic prompt classifier from prepared metadata
- first-user boundary and shared-prefix boundary discovery
- a prefix-candidate evaluator that can return `unsafe_prefix_rejected`
- checkpoint admission policy with semantic and spacing decisions
- counters for admitted and skipped checkpoints by reason

The policy belongs in the cache controller and checkpoint admission path.
HTTP-layer prompt preparation only supplies structured metadata.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Prefix restore accepts a false prefix. | Invalid model state. | Stage 17 rejects prefix candidates until full validation exists. |
| Dense checkpoints are needed by a model. | Missed restore opportunity or correctness risk. | Compatibility exception for checkpoint-dependent and MTP cases. |
| Semantic boundary detection is incomplete. | Lower hit rate. | Fall back to exact restore and bounded diagnostics. |
| `--ctx-checkpoints` behavior changes too much. | Operator surprise. | Treat it as an upper bound and document skipped admission reasons. |

