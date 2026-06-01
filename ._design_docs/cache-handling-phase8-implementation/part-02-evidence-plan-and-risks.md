# Stage 8 implementation plan - Part 2

Source: [../cache-handling-phase8-implementation.md](../cache-handling-phase8-implementation.md)
Continuation of [Part 1](part-01-implementation-plan.md).

## Evidence plan

Each implementation step must update this log, or a part file if the log
grows, before the next step starts. The evidence entry must include:

- changed file paths
- behavior change
- exact build command and result
- exact focused test command and result
- metrics or diagnostics sample when the step changes observability
- coverage result or a clear reason coverage could not be gathered
- any deviation from this plan and how it was resolved

Expected command set after implementation opens:

```powershell
cmake --build build --config Release --target test-step13-stage8 -j 4
ctest --test-dir build -C Release -R test-step13-stage8 --output-on-failure
cmake --build build --config Release --target test-cache-controller -j 4
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
cmake --build build --config Release --target llama-server -j 4
pytest tools/server/tests/unit/test_cache_modes.py
```

Add Stage 6/7 step-target reruns when a change touches cold demotion,
promotion, startup wiring, or branch graph behavior.

## Metrics and diagnostics evidence

Implementation evidence must include samples for the new Stage 8
observability surface:

- cache_metadata_only_retentions_total (counter, namespace+reason labels)
- cache_node_rematerializations_total (counter, namespace+result labels)
- cache_node_rematerialization_bytes_total (counter, namespace label)
- cache_validation_mismatches_total (counter, namespace+method labels)
- cache_mismatch_parent_selections_total (counter, namespace+source labels)
- cache_equivalent_branch_deduplications_total (counter, namespace+action)
- cache_branch_pruning_total (counter, namespace+result+reason labels)
- cache_branch_pruned_metadata_bytes_total (counter, namespace label)
- cache_cold_cleanup_total (counter, namespace+result labels)
- cache_branch_metadata_admission_rejections_total (counter,
  namespace+reason labels)

Diagnostics log events to verify:

- metadata_only_retained
- rematerialization_plan
- rematerialization_validation_mismatch
- rematerialization_committed
- rematerialization_fallback
- mismatch_parent_selected
- equivalent_branch_reused
- equivalent_branch_canonicalized
- branch_prune_candidate_rejected
- branch_pruned
- cold_cleanup_committed
- cold_cleanup_blocked
- branch_metadata_admission_rejected

Metric additions must not remove Stage 4, Stage 5, Stage 6, or Stage 7
metric names.

## Doc update plan

| Document | Update | When |
| --- | --- | --- |
| cache-handling-phase8-implementation.md | Status, gate progress, evidence links | After each step |
| cache-handling-phase8-implementation/part-XX-*.md | Evidence parts as log grows | After each step |
| cache-handling-test-plan.md | Reusable Stage 8 QA rules | After implementation |
| document-index.md | New part references | After implementation |

## Tests/evidence plan

| Area | Required evidence | Steps |
| --- | --- | --- |
| Metadata-only transition | Forest tests: payload eviction preserves topology, is_metadata_only set, slot-ref blocks eviction, pair-state eviction clears both sides | 8.1 |
| Branch pruning safety | Forest tests: leaf prune, protected-root reject, active-ref reject, descendant reject, metadata bytes decrease | 8.2 |
| Equivalent-branch lookup | Forest tests: token path match, payload-bearing preferred, canonical selection deterministic, cross-namespace reject | 8.3 |
| Deterministic ranking | Forest tests: all 8 tie-breakers, mismatch-parent selection with partial validation and ties | 8.4 |
| Re-materialization validation | Forest+controller tests: full match, checksum mismatch, token mismatch, missing ancestor, fallback | 8.5 |
| Successful materialization | Controller tests: payload save, is_metadata_only flip, usage update, target/draft atomic, save failure fallback | 8.6 |
| Mismatch handling | Controller tests: new branch under deepest ancestor, mismatched node unchanged, diagnostics | 8.7 |
| Deduplication admission | Controller tests: equivalent reuse, re-materialization, canonicalization, concurrent atomic admission | 8.8 |
| Budget enforcement | Forest+controller tests: safe leaf prune, protected-root exclusion, active-ref exclusion, admission rejection | 8.9 |
| Cold cleanup safety | Fake cold store tests: owned descriptor deleted, retained descendant blocked, pair cleaned together | 8.10 |
| Metrics and diagnostics | Focused stat tests + Python metric shape: all 11 counters, all 13 log events, no removed names | 8.11 |
| Build and regression | Build all targets, run all cache tests, record results | 8.12-8.13 |

## Known risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Re-materialization can be expensive when the nearest payload-bearing ancestor is far from the selected node. | Metrics expose bytes materialized and per-node cost. The design accepts this as a correctness requirement. |
| Conservative pruning may leave metadata over budget when only protected or topology-required nodes remain. | The correct outcome is admission rejection or explicit over-budget diagnostics. Tests verify this. |
| Equivalent-branch canonicalization can race under concurrent requests. | Admission must be atomic with lookup. The forest mutex guards both operations. Tests cover concurrent admission. |
| Cold cleanup bugs can delete restorable payloads. | Ownership checks are blocking, not advisory. Tests prove retained descendants block deletion. |
| Token-span storage can grow metadata quickly. | Budget tests include realistic long-branch cases. The pruning score prefers high-byte-cost candidates. |
| Stage 7 flat entry migration may leave orphaned entries. | The hybrid controller already creates branch nodes for all entries. Stage 8 eviction and pruning handle orphaned descriptors. |
| Concurrency coverage may depend on sanitizer availability. | Run TSAN where supported; otherwise record the limitation and keep deterministic mixed-thread tests. |

## Review readiness

This plan is ready for independent review when the reviewer can confirm:

- It references the accepted Stage 8 design baseline and design review gate
  PASS with advisory findings 8-01 through 8-05.
- It keeps code implementation closed until independent plan review and
  manager approval.
- It names affected modules, dependencies, tests, metrics, diagnostics,
  build evidence, and risks.
- It preserves Stage 4 protected-root payload budget behavior, Stage 5
  descriptor validation, Stage 6 cold residency contracts, and Stage 7
  branch graph semantics.
- It does not introduce Stage 9 checkpoint-first restore or new public HTTP
  endpoints.
- Advisory findings 8-01 through 8-05 are explicitly addressed in the plan.
