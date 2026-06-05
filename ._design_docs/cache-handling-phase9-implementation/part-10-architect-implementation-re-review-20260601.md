# Stage 9 Architect implementation re-review - 2026-06-01

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)
Reviewer: Architect (independent)
Gate: Implementation re-review after Part 9 corrections
Verdict: PASS

## Scope and gate status

This re-review checks the latest Stage 9 corrections for S9-IMPL-06 and
S9-IMPL-07. It also confirms that S9-IMPL-01 through S9-IMPL-05 remain closed
or bounded as recorded in the prior implementation review and re-review.

Gate status: PASS. Stage 9 implementation review is ready for Manager handoff
and QA planning. QA still needs to treat model-backed checkpoint-dependent HTTP
coverage as a known evidence gap unless a suitable fixture is available.

## Sources reviewed

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-phase9-design.md`
- `._design_docs/cache-handling-phase9-design/part-01-scope-and-workload-profiles.md`
- `._design_docs/cache-handling-phase9-design/part-02-checkpoint-payload-lifecycle-and-interfaces.md`
- `._design_docs/cache-handling-phase9-design/part-03-restore-strategy-and-prepared-prompt-boundaries.md`
- `._design_docs/cache-handling-phase9-design/part-04-pairing-cold-store-metrics-and-diagnostics.md`
- `._design_docs/cache-handling-phase9-design/part-05-testability-traceability-exclusions-and-risks.md`
- `._design_docs/cache-handling-phase9-implementation.md`
- `._design_docs/cache-handling-phase9-implementation/part-01-implementation-plan.md`
- `._design_docs/cache-handling-phase9-implementation/part-02-evidence-plan-and-risks.md`
- `._design_docs/cache-handling-phase9-implementation/part-06-architect-implementation-review-20260601.md`
- `._design_docs/cache-handling-phase9-implementation/part-07-implementation-review-corrections-20260601.md`
- `._design_docs/cache-handling-phase9-implementation/part-08-architect-implementation-re-review-20260601.md`
- `._design_docs/cache-handling-phase9-implementation/part-09-cold-checkpoint-restore-corrections-20260601.md`

## Code and tests reviewed

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-graph.cpp`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`

## Finding disposition

| ID | Disposition | Notes |
| --- | --- | --- |
| S9-IMPL-01 | Closed | Checkpoint descriptors carry placement metadata, and admission plus restore validation recheck boundary/span/checksum metadata. The focused boundary tests remain consistent with the design. |
| S9-IMPL-02 | Closed | `checkpoint_dependent` selection still rejects exact-only branches as canonical restore paths. Exact blobs remain available for plain transformer restores. |
| S9-IMPL-03 | Closed | Checkpoint payloads participate in hot-budget eviction and descriptor accounting. The checkpoint budget eviction test still covers the corrected path. |
| S9-IMPL-04 | Closed | Checkpoint hit and restore rows are recorded and exported with profile, residency, pair-state, and restore-result labels. |
| S9-IMPL-05 | Bounded advisory | Focused controller and metrics evidence is adequate for implementation review. Model-backed HTTP and public task-flow boundary evidence remain QA or follow-up evidence items, as already documented. |
| S9-IMPL-06 | Closed | Candidate selection and checkpoint-path validation now use descriptor reachability instead of hot-byte readiness. Cold checkpoint descriptors can be selected for checkpoint-dependent restore, and the restore paths request async promotion before live slot mutation. |
| S9-IMPL-07 | Closed for implementation review | The new cold-checkpoint test records a restore row with real enum labels and checks that serialized metric evidence does not contain namespace or token material. The Prometheus exporter consumes the same restore row data. Public `/metrics` evidence remains a QA evidence item, not a blocker for this implementation review. |

## Review decisions

S9-IMPL-06 is fixed. `entry_has_payload_descriptor_for_restore()` accepts valid
hot, cold, demoting, or promoting descriptors while still rejecting missing,
evicted, wrong-owner, wrong-kind, or malformed descriptor references.
`select_restore_candidate()` and `checkpoint_path_valid_for_restore()` use that
descriptor-level predicate, so a cold checkpoint-dependent candidate reaches
the restore path. `try_restore_from_cache()` and `load_slot()` then detect cold
residency, call `promote_payload()`, record a failed checkpoint restore row, and
return a cache miss before slot mutation.

S9-IMPL-07 is adequate for implementation review. The focused metric evidence
now covers `cache_checkpoint_restores_by_shape` with
`profile=checkpoint_dependent`, `payload_residency=cold`,
`pair_state=target_only`, and `result=failure`. The server Prometheus exporter
iterates the same row set for `cache_checkpoint_restores_total`, so the code
path no longer depends on constant labels. A live public `/metrics` scrape is
still useful in QA, but the implementation review does not need to block on it.

No new blocking or major findings were found in the reviewed scope.

## Verification run

- `cmake --build build --config Release --target test-cache-controller`: PASS
- `.\build\bin\Release\test-cache-controller.exe`: PASS, 59 tests
- `cmake --build build --config Release --target test-step10-metrics`: PASS
- `.\build\bin\Release\test-step10-metrics.exe`: PASS
- `ctest --test-dir build -C Release -R "test-cache-controller|test-step10-metrics" --output-on-failure`: PASS, 2/2 tests

## Remaining risks

- No model-backed checkpoint-dependent HTTP row was run in this correction pass.
  QA should either run one with a suitable SWA, recurrent, hybrid, or MTP fixture
  or keep the documented substitute-evidence limit explicit in the QA report.
- Public Prometheus scrape evidence should be collected during QA if a server
  fixture is available. The implementation review accepts the exporter code path
  plus focused metrics evidence.

## Next action

Next owner: Manager.

Handoff state: PASS. Manager may open Stage 9 QA planning with the evidence
limits above carried forward.
