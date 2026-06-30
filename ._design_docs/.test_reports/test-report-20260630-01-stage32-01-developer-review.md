# Stage 32 Developer test-results review 2026-06-30 01

VERDICT: FAIL - product fixes required

## Scope

Review subject:

- `._design_docs/.test_reports/test-report-20260630-01-stage32-01.md`

Inputs checked:

- `._design_docs/cache-handling-phase32-design.md`
- `._design_docs/cache-handling-phase32-implementation.md`
- `._design_docs/cache-handling-test-plan/part-36-stage32-live-comparison-rerun.md`
- `_test_output/stage32-cache-modes-20260630-01/summary.json`
- `_test_output/stage32-cache-modes-20260630-01/stage32-proof/cache-reuse-by-class.json`
- `_test_output/stage32-cache-modes-20260630-01/stage32-proof/hybrid-hit-deltas.json`
- `_test_output/stage32-cache-modes-20260630-01/stage32-proof/bounded-label-scan.json`
- `_test_output/stage32-cache-modes-20260630-01/stage32-proof/namespace-metric-forms.json`
- `_test_output/stage32-cache-modes-20260630-01/server.err.log`

No code was changed in this review.

## Failure classification

| Finding | Classification | Owner | Rationale |
| --- | --- | --- | --- |
| Zero live hybrid reuse on completed exact-repeat traffic | Product bug | Developer | The workload contains real exact duplicates: 78 exact rows, 41 unique exact message bodies, 22 duplicate groups, and 59 exact rows that belong to duplicate groups. Completed hybrid legs still had `cache_hit_true=0`, `cache_n_gt_zero=0`, and `hit_delta=0`. Server logs show restore misses after prior saves, mainly `token_count_mismatch` and `checksum_mismatch`, so the live save/restore path is not matching prompt-equivalent duplicate traffic. |
| `namespace="all"` public metric labels | Product bug | Developer | Stage 31 and Stage 32 accepted bounded aggregate namespace metrics with `scope="all"`, not a `namespace` label. `bounded-label-scan.json` found 22 cache metric rows that still expose label name `namespace`, for example rematerialization, validation mismatch, pruning, cold cleanup, and metadata admission rows. This is likely leftover Stage 8/10 metric row emission. |
| Warm-cycle-2 hybrid and warm-cycle-3 rows not run | Not a blocker for bug handoff | Manager/QA after fixes | The 180 minute budget stopped the run, but completed hybrid exact-repeat evidence already satisfies the Stage 32 FAIL rule. Retest can use a shorter focused exact-repeat live run before repeating the full comparison. |

## Primary bug notes

The zero-reuse failure is not explained by namespace cardinality. The completed
hybrid metrics report `llamacpp:cache_namespace_count{mode="hybrid"} = 1`, so
Stage 31's broad namespace fix worked in the live run.

The failure is also not explained by lack of duplicate prompts. The Stage 32
workload has duplicate exact-message bodies. A focused fix should inspect why
saved entries later miss under the same namespace. The preserved server log
shows this sequence repeatedly:

- restore miss before the first save, often `exact_entry_absent`;
- `tx_save` succeeds for a slot;
- later restores miss with `token_count_mismatch` or `checksum_mismatch`;
- idle saves with `task == null` are rejected and do not explain the accepted
  saves that precede later misses.

## Required fix scope

Developer bug-fix loop must address:

1. Live exact-repeat save/restore parity under `/v1/chat/completions`.
   Investigation targets:
   - rendered prompt tokens used by restore vs saved branch tokens;
   - prepared prompt metadata checksum spans and token counts;
   - branch lookup candidate selection after namespace broadening;
   - slot lifecycle and `cache_n` timing propagation after a successful hybrid
     restore;
   - interaction between `--parallel 2`, idle slot saves, and saved task
     metadata.
2. Public cache metric label shape for aggregate namespace-like metrics.
   Replace remaining `namespace="all"` public labels with the accepted
   `scope="all"` form, or remove the label when the row is already
   mode-aggregate.

## Retest scope

Use a short focused run before another full 150-180 minute comparison:

- clean Release CUDA build;
- direct `test-cache-controller` and `ctest -R cache`;
- one live hybrid `/v1/chat/completions` exact-repeat probe with a small
  duplicate workload;
- scrape `/metrics` after the probe;
- assert `cache_hit=true` or `cache_n > 0` for at least one duplicate exact
  request, `llamacpp:cache_hits_total` increases, namespace count remains
  bounded, no public `namespace` label remains on cache metrics, and
  HELP/TYPE remains per-scrape unique.

After the focused probe passes, rerun the Stage 32 comparison with a shorter
acceptance run first: cold legacy, cold hybrid, and warm-cycle-1 hybrid are
enough to prove the fixed exact-repeat behavior. A full 3-warm-cycle comparison
can follow only if Manager still needs the larger performance report.

## Handoff

Next owner: Developer bug-fix loop.

Create or update
`._design_docs/.test_reports/test-report-20260630-01-stage32-01-fixes.md`.
No Manager closure is possible until the product fixes are reviewed and retested.
