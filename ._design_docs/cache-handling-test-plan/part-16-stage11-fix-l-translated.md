# Cache handling test plan - Part 16: Stage 11 fix L translated re-apply

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

- Date: 2026-06-06
- Owner: QA
- Source of action: Stage 11 follow-up implementation
  [part-25-stage11-fix-l-translated-implementation.md](../cache-handling-phase11-implementation/part-25-stage11-fix-l-translated-implementation.md)
  and implementation review
  [part-26-stage11-fix-l-implementation-review.md](../cache-handling-phase11-implementation/part-26-stage11-fix-l-implementation-review.md)
  (PASS, 0/0/3 ADVISORY).

## 1. Scope

Verify the translated re-apply of fix L from `fix_mtp_server_instability` tip
`a4303153` to HEAD `02db7a768` in `ggml_backend_meta_buffer_reset` at
`ggml/src/ggml-backend-meta.cpp:1467-1494`. The translated body must:

- Clear `split_state_cache` and the three `simple_tensors` maps
  (`stc_static`, `stc_compute[0]`, `stc_compute[1]`).
- Reset every child context across the three `stc_*` containers via three
  `for (ggml_context_ptr & ctx : ...) { ggml_reset(ctx.get()); }` loops.
- Preserve the existing buffer reset loop over `bufs`.

The fix is ggml-internal, public-HTTP-irrelevant, and silent (no new log
lines). Adjacent part-15 covers the separate `n_outputs_max` cap fix in
`server-context.cpp`; fix L is a different file and a different function.

## 2. Clean build requirement

Run an incremental rebuild of `llama-server` against the implementation
commit. The fix touches `ggml/src/ggml-backend-meta.cpp`, which forces
`ggml` and the server link step to recompile and relink. Capture the
build log and binary timestamp. The pre-existing `LNK4098` warning is
allowed.

```powershell
cmake --build build-cuda --config Release -j --target llama-server
$Binary = Get-Item build-cuda\bin\Release\llama-server.exe
$BuildAge = (Get-Date) - $Binary.LastWriteTime
if ($BuildAge.TotalMinutes -gt 10) {
    throw "llama-server.exe is stale. Run the build again."
}
```

Build evidence citation: `## Build evidence` block of `part-25` and the
build log at
`._design_docs/.test_reports/build-cuda-fix-l-translated-20260606-01.log`
(exit 0).

## 3. Focused C++ test (T-FIX-L-01)

Focused unit test that drives `ggml_backend_meta_buffer_reset` with a
populated `ggml_backend_meta_buffer_context`. No model fixture required.

Setup:

- Allocate a `ggml_backend_meta_buffer_context` with N entries in
  `split_state_cache`, M entries in each of the three
  `simple_tensors` maps, N+M non-null `ggml_context_ptr` entries
  spread across the three `stc_*` containers, and K entries in `bufs`.
- Provide a `ggml_backend_buffer_t` whose `->context` points at this
  struct. Wrap or mock `ggml_reset` and `ggml_backend_buffer_reset` to
  count calls (a counting shim is acceptable).

Pass criteria:

- (a) `buf_ctx->split_state_cache.empty()` is true after the call.
- (b) All three `simple_tensors` maps are empty after the call.
- (c) `ggml_reset` was called once per non-null `ctx.get()` across
  the three `stc_*` containers (total call count equals
  `stc_static.ctxs` non-null count plus
  `stc_compute[0].ctxs` non-null count plus
  `stc_compute[1].ctxs` non-null count).
- (d) `ggml_backend_buffer_reset` was called once per `bufs[i]`
  (total call count equals `buf_ctx->bufs.size()`).

Evidence: focused test name, source file, and assertion lines.

## 4. Equivalence to fix-mtp (T-FIX-L-02)

Focused test that compares the post-reset state of the translated fix
against the reference behavior from `fix_mtp_server_instability`
(a4303153): clear all caches, reset all contexts, reset all buffers.

Pass criteria:

- Populate the same `ggml_backend_meta_buffer_context` shape as
  T-FIX-L-01.
- Call `ggml_backend_meta_buffer_reset` once.
- Assert the post-reset state matches the reference: every cache map
  is empty, every context was reset, every buffer was reset.
- A second back-to-back call must also leave the state in the same
  reference shape (idempotency: clearing an empty map and resetting
  a reset context must not throw and must not change the final state).

Evidence: focused test name, source file, and assertion lines.

## 5. Stage 4-9 regression

The fix touches only `ggml/src/ggml-backend-meta.cpp` and affects only
the meta-backend reset path. Non-meta-backend paths and the public
server contract are unaffected. Run `test-cache-controller.exe` and
confirm the prior 85/85 focused regression rows still pass.

Pass criteria:

- `test-cache-controller.exe` exits 0.
- All 85 focused regression rows (H53, H54, H57, R20-R23, Q110-Q112,
  T118-T121, and the rest from parts 10-12) still report `PASS`.
- No new failure or skip appears in the report.

Evidence: per-session test report at
`._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` showing the
full 85/85 PASS count.

## 6. Coverage

The implementation adds 19 lines to `ggml/src/ggml-backend-meta.cpp`.
`ggml` is NOT in the T114 19-file hybrid-mode denominator nor the
T114a 11-file product-only denominator (both denominators are
hybrid-mode product files). Therefore the fix has no coverage-rate
impact on T114 or T114a.

Pass criteria:

- T114 row reports PASS at the existing 80% combined rate on the
  19-file hybrid-mode denominator.
- T114a row reports PASS at the existing 70% product-only rate on
  the 11 product files.
- No new file enters either denominator.
- `ggml/src/ggml-backend-meta.cpp` is not added to the T114 or T114a
  denominator lists.

Evidence: `## Combined result` and `## Product-only result` blocks in
the per-session `coverage-report.md`.

## 7. Observability

The fix is silent. No `GGML_LOG`, no `GGML_ASSERT`, no new
`SRV_DBG`, and no metrics counters were added.

Pass criteria:

- `git diff ggml/src/ggml-backend-meta.cpp` shows zero added log,
  assert, or metric lines.
- Server log verbosity profile is unchanged before and after the fix
  on a representative model-backed run.
- The `## Diff evidence` block of `part-25` (19 insertions, 0
  deletions) is unchanged.

Evidence: `git diff -U0 ggml/src/ggml-backend-meta.cpp | Select-String
'GGML_LOG|GGML_ASSERT|SRV_DBG'` returns no matches.

## 8. Out of scope

- k6 load tests against the public HTTP surface.
- Stress tests beyond the existing part-06 stress rows.
- Benchmark rows.
- New `GGML_LOG` or `SRV_DBG` lines.
- Coverage denominator changes (the 19-file and 11-file lists are
  frozen for this stage).
- Re-running the public MTP crash repro from part-15
  (T-MTP-FIX-01) is unrelated to fix L.
- Editing the test plan entry doc, parts 1-15, or any prior
  test-plan review file.
- Re-running the cap-fix T114/T114a rerun; the fix is silent on the
  coverage denominators, so the prior numbers stand.

## 9. Evidence format

Each test row must cite:

- File path of the source, focused test, or log under test.
- Row ID (`T-FIX-L-01`, `T-FIX-L-02`, or the referenced H/T/Q/R row
  for regression).
- Pass criterion copied from this part.
- Evidence location: focused test name and source line, or artifact
  path under
  `._design_docs/.test_reports/test-report-YYYYMMDD-NN-artifacts/`.

Do not report run-specific results in this plan. Store execution
evidence only in a fresh
`._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` file after QA
execution opens.

## 10. Out-of-scope correctness

Confirm the fix does not regress any existing test row in parts 1-15
or any Stage 4-10 hybrid-mode row.

Pass criteria:

- All rows in parts 1-15 (including the part-15 cap-fix rows
  T-MTP-FIX-01, T-NOUT-MAX-01, T-NOUT-MAX-02) are not weakened or
  reclassified by this plan.
- The implementation review's three ADVISORY findings (F-1 op
  order, F-2 line-number drift, F-3 three-stc reset) are
  documented but not blocking; the plan does not need to verify
  those semantics beyond the T-FIX-L-01 / T-FIX-L-02 assertions.
- No row is hidden behind a generic `SKIP` or `BLOCKED` verdict
  solely because of the fix.
- `git diff --check` against the new test plan file returns exit 0.

Evidence: cross-reference table in the per-session test report
listing each part-1-15 row and its unchanged verdict.
