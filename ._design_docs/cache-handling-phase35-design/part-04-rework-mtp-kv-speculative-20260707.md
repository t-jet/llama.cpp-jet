# Stage 35 rework: MTP, KV, and speculative routing

Source: [../cache-handling-phase35-design.md](../cache-handling-phase35-design.md)

## Status

Status: REWORK DESIGN READY FOR REVIEW, 2026-07-07
Owner: Architect
Track: MTP/KV/speculative
Gate: merge execution blocked until this part passes independent review and
Manager gate.

This part routes the Manager-approved pre-merge REWORK-REQUIRED rows for new
speculative architectures, MTP flows, and KV cache layouts. It does not approve
merge execution or production code changes.

## Upstream SHA rows

| SHA | Subject | Pre-merge row decision | Files or surfaces named by analysis |
| --- | --- | --- | --- |
| `88a39274ecf8` | `spec: add EAGLE3 speculative decoding support (#18039)` | REWORK-REQUIRED | `common/speculative.cpp`, `src/llama-context.*`, `src/llama-graph.*`, `src/models/eagle3.cpp`, model metadata, arch tests |
| `d789527482d9` | `spec : Support Step3.5/3.7 flash mtp3 (#24340)` | REWORK-REQUIRED | `common/speculative.cpp`, `include/llama.h`, `src/llama-context.*`, `src/models/step35.cpp` |
| `d1b34251bc57` | `spec : add DFlash support (#22105)` | REWORK-REQUIRED | `common/speculative.cpp`, `common/common.h`, `src/llama-context.cpp`, `src/llama-graph.cpp`, `src/models/dflash.cpp` |
| `8c146a836630` | `DeepSeek V4 (#24162)` | REWORK-REQUIRED | `models/templates/deepseek-ai-DeepSeek-V4.jinja`, `src/llama-kv-cache-dsv4.*`, `src/llama-kv-cache-iswa.*`, `src/llama-kv-cache.*`, `src/models/deepseek4.cpp` |

Source tip for the accepted pre-merge analysis:
`origin/upstream_master` at `108f186d1701d56133a0239dd6754c8814374cbf`.

## Affected contract owners

| Owner | Contract that must survive |
| --- | --- |
| Architecture part 6 | Draft context modes are compatibility inputs. Binary `target_only` versus `target_and_draft` pair state must not encode speculative algorithm. |
| Stage 5 | Target and draft bytes save, restore, validate, and evict as one descriptor-owned unit. A target-plus-draft runtime must not restore `target_only`. |
| Stage 9 | Checkpoint and exact descriptors inherit Stage 5 pair state; MTP target-derived and separate-draft contexts stay namespace-isolated. |
| Stage 25 | `tx_save`, `tx_restore`, `tx_apply_restore`, promotion, demotion, and eviction keep atomic transaction ownership. |
| Stage 34 | I-34-01 idempotent save and I-34-02 slow-read-outside-lock remain binding for target/draft payload reads. |
| Architecture | Hybrid mode remains opt-in and legacy/default behavior stays upstream-compatible when hybrid is disabled. |

## Risk

These upstream commits add model-backed speculative paths and new KV-cache
implementations. The risk is not only build conflict. A compile-clean merge can
still break local cache correctness if a new draft context is treated as normal
target-only state, if MTP mode identity is omitted from the namespace, if KV
rotation or ISWA state is saved without descriptor compatibility checks, or if
slow target/draft state reads move back under `cache_state_mutex_`.

DeepSeek V4 adds new KV-cache files. EAGLE3, Step MTP, and DFlash touch
speculative setup and graph/context state. These are protected surfaces because
the local cache serializes live context state and assumes target/draft pair
integrity.

## Required analysis before merge

Developer must complete this analysis before running any merge command:

| Analysis item | Required result |
| --- | --- |
| Runtime shape inventory | For each SHA, record whether the merged runtime creates no draft context, separate draft context, target-derived MTP context, or separate-model MTP context. |
| Namespace diff | List every new speculative, KV layout, context type, SWA/ISWA, model arch, and draft identity field that must enter the cache compatibility key. |
| Pair-state audit | Prove each new runtime maps to `target_only` or `target_and_draft` under Stage 5 rules; no third pair state is added. |
| Transaction audit | Trace new save, restore, promotion, demotion, and checkpoint paths to Stage 25 `tx_*` ownership. |
| Slow-read audit | Confirm target and draft `llama_state_seq_get_data_ext` reads still follow I-34-02 and do not hold `cache_state_mutex_`. |
| Checkpoint audit | Confirm MTP and DeepSeek KV checkpoint payloads validate token span, checksum, workload profile, and pair state before admission. |
| Metric and diagnostic audit | Record whether upstream speculative metrics are additive, renamed, or incompatible with bounded public label policy. |

If any item cannot be proven from code inspection, the row remains
REWORK-REQUIRED and merge execution stays blocked.

## Allowed integration conditions

Integration is allowed only when all conditions hold:

- The rework design review and Manager gate pass for this part.
- Every new speculative runtime has an explicit compatibility-key mapping.
- Descriptor pair state remains binary and enforced before live mutation.
- New KV-cache layout state is either fully covered by descriptor validation or
  excluded from hybrid cache with a bounded unsupported-runtime diagnostic.
- Stage 25 transaction boundaries remain intact.
- Stage 34 idempotent save and slow-read placement remain intact.
- Public metric additions keep bounded labels and unique HELP/TYPE blocks.
- Any unresolved runtime is recorded as DEFER or unsupported, not silently
  integrated as a cache-capable path.

## Regression evidence required after closed rework

Minimum expanded evidence for this track:

- Clean build and focused `ctest -R cache` log.
- Controller tests for pair-state mismatch, MTP namespace isolation, and
  target/draft eviction as one unit.
- Public MTP-capable probe when a fixture is available: first miss, later
  positive `cache_n`, positive hybrid hit delta, and no pair mismatch logs.
- Checkpoint admission evidence for MTP or checkpoint-capable fixture:
  non-zero checkpoint admission or a bounded unsupported-runtime reason.
- Metrics shape check for cache and speculative metrics: bounded labels and
  unique HELP/TYPE blocks.
- Focused coverage report if feature-mode source files changed, citing the
  markdown combined and product-only blocks, not XML root attributes.
- Fresh upstream staleness check at regression time.

## Durable doc updates if behavior changes

If merge analysis changes behavior, update the owning durable doc before merge
execution:

| Behavior change | Durable doc that must change |
| --- | --- |
| New speculative compatibility discriminator | `cache-handling-architecture/part-06-stage-5-draft-context-modes-and-pairing.md` |
| New descriptor field, pair validation rule, or ownership rule | `cache-handling-phase5-design/part-02-interfaces-components-and-data-model.md` and part 03 |
| New checkpoint placement or validation rule for MTP/KV state | `cache-handling-phase9-design/part-02-checkpoint-payload-lifecycle-and-interfaces.md` and part 04 |
| Transaction boundary or lock placement change | `cache-handling-phase25-design/part-02-atomic-transaction-protocol.md` and part 03 |
| I-34-01 or I-34-02 adjustment | `cache-handling-phase34-design/part-04-design-correction-idempotent-save-and-path-b-20260705.md` |
| Architecture-level invariant change | `cache-handling-architecture.md` or a new architecture part |

## Handoff

Next owner: independent Architect review, then Manager gate.

Handoff state: RE-REVIEW REQUIRED. Merge execution, regression runs, commits,
pushes, PRs, and reviewer responses remain unauthorized.
