# Cache handling test plan - Part 15: Stage 11 n_outputs_max cap fix

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

- Date: 2026-06-06
- Owner: QA
- Source of action: Stage 11 follow-up implementation
  [part-22-stage11-mtp-cap-fix-implementation.md](../cache-handling-phase11-implementation/part-22-stage11-mtp-cap-fix-implementation.md)
  and implementation review
  [part-23-stage11-mtp-cap-fix-implementation-review.md](../cache-handling-phase11-implementation/part-23-stage11-mtp-cap-fix-implementation-review.md)
  (PASS).

## 1. Scope

Fix the `n_outputs_max` cap violation that triggered the
`GGML_ASSERT` crash at `src/llama-context.cpp:2152` on the first MTP
draft-context request against HEAD `02db7a768`. The fix touches
`tools/server/server-context.cpp` at `:1175` (draft MTP cap-bump),
`:1308` (MTP cparams cap-bump), and `:3750` (chunked-decode bound),
adding a bounded `SRV_DBG` line at `:3771`. The crash was reproduced
on Qwen3.6-27B-Q4_K_M (MTP draft, q8_0 KV, `c=140000`, port 52411)
with the prompt "What is your problem?".

The architecture invariant
[part-07](../cache-handling-architecture/part-07-speculative-decode-batch-cap-invariant.md)
requires `n_tokens` per `llama_decode` call to be at or below
`cparams.n_outputs_max`. The cap-bump at `:1175` and `:1308` raises
the cap to `min(n_batch, n_parallel * (1 + n_max))`. The chunked
bound at `:3750` enforces the cap per chunk in the speculative
decode loop.

## 2. Clean build requirement

Stage 11 follow-up execution starts from a clean build of
`llama-server` against the implementation commit. Capture the
build log and binary timestamp. The pre-existing `LNK4098` warning
is allowed. The `server-context.cpp` recompile and
`llama-server.exe` relink are the build evidence.

```powershell
Remove-Item -Recurse -Force build-cuda -ErrorAction SilentlyContinue
cmake -B build-cuda -S . -DCMAKE_BUILD_TYPE=Release -G "Visual Studio 17 2022" -A x64 -DGGML_CUDA=ON -DGGML_NATIVE=OFF -DBUILD_SHARED_LIBS=OFF
cmake --build build-cuda --config Release -j --target llama-server

$Binary = Get-Item build-cuda\bin\Release\llama-server.exe
$BuildAge = (Get-Date) - $Binary.LastWriteTime
if ($BuildAge.TotalMinutes -gt 10) {
    throw "llama-server.exe is stale. Run the clean build again."
}
```

Build evidence citation: `build/build-capfix.log` exit code 0 and
the `## Build evidence` block of `part-22`.

## 3. Reproduction test (T-MTP-FIX-01)

Manual integration test. Operator-runnable, not a CI row. The
crash on HEAD `02db7a768` was captured in the investigation log
[part-19](../cache-handling-phase11-implementation/part-19-stage11-mtp-crash-investigation.md)
at server log lines 20000-20394.

| Item | Value |
| --- | --- |
| Server command | port 52411, `-c 140000`, draft-mtp, q8_0 KV cache, full flags as in investigation log |
| Model | `c:\Users\think\.lmstudio\models\unsloth\Qwen3.6-27B-MTP-GGUF\Qwen3.6-27B-Q4_K_M.gguf` |
| Prompt | "What is your problem?" |

Pass criteria:

- Server starts and reaches a model-ready state.
- The prompt is processed and the model produces a response
  containing text content (not just a role delta).
- No `GGML_ASSERT` failure in the server log.
- Server remains alive for at least 60 seconds after the first
  token.

Evidence: full server log, prompt request, response body, and
`/metrics` snapshot. The pre-fix log lines 20000-20394 document
the crash; the post-fix log must show a successful decode. Save
the log to
`._design_docs/.test_reports/test-report-YYYYMMDD-NN-artifacts/mtp-fix-repro/server.log`.

## 4. Focused C++ test (T-NOUT-MAX-01)

Focused unit or integration test that drives the chunked decode
loop in `server-context.cpp` with a batch whose `n_tokens`
exceeds the cap. Use a mock context or a small synthetic model
to avoid the MTP fixture requirement.

Pass criteria:

- Construct a `llama_batch` with `n_tokens > cparams.n_outputs_max`.
- Invoke the chunked decode loop path (the code at
  `server-context.cpp:3747-3774`).
- Assert that for every chunk, the `n_tokens` passed to
  `llama_decode` is at or below `cparams.n_outputs_max`.
- Assert the `n_tokens` per chunk is at or below `n_batch`.

Evidence: focused test name, source file, and assertion lines.
Map the assertion to the `std::min({n_batch, batch.n_tokens - i,
(int32_t) params_base.n_outputs_max})` initializer-list at
`:3755`.

## 5. Focused C++ test (T-NOUT-MAX-02)

Focused startup assertion test that reads
`cparams_mtp.n_outputs_max` after server-context init and
compares it to the expected formula.

Pass criteria:

- Initialize server context with `n_parallel=1`, `n_max=3`,
  `n_batch=2048`, `--spec-type draft-mtp`.
- Read `cparams_mtp.n_outputs_max` and assert it equals
  `min(n_batch, n_parallel * (1 + n_max))`.
- For the test parameters above, the expected value is
  `min(2048, 1 * (1 + 3)) = 4`.
- Repeat the read for `params_dft.n_outputs_max` (the draft
  MTP cap at `:1175`) and assert the same value.

Evidence: focused test name, source file, assertion lines, and
the captured `cparams_mtp.n_outputs_max` and
`params_dft.n_outputs_max` values.

## 6. Hybrid-mode regression

Re-run the existing hybrid mode test rows H53, H54, and H57
defined in
[part-03-integration-test-matrix.md](part-03-integration-test-matrix.md)
at lines 137, 138, and 141. The implementation review verified
that none of these rows pin `cparams_mtp.n_outputs_max ==
n_parallel`, so the rows are unchanged.

Pass criteria:

- H53 (target-derived MTP save and restore) passes.
- H54 (separate-model MTP save and restore) passes, or is
  marked `BLOCKED` with startup evidence if the local model
  cannot create the runtime.
- H57 (normal draft versus MTP namespace isolation) passes.

Evidence: focused test name, source file, and assertion lines
for each row. Map the focused tests to the H53/H54/H57 row IDs
in the verdict section.

## 7. Coverage

Confirm the implementation does not break the T114 combined
rate of 80% on the 19-file hybrid-mode denominator and the
T114a product-only rate of 70% on the 11 product files. The
implementation adds three lines to `server-context.cpp` (which
is in both denominators), so the new lines must be covered.

Pass criteria:

- T114 row reports PASS (combined rate at or above 0.80).
- T114a row reports PASS (product-only rate at or above 0.70).
- The new `SRV_DBG` line at `:3771` and the cap-bump
  assignments at `:1175` and `:1308` are credited in the
  per-file coverage table for `server-context.cpp`.
- No regression in the `server-context.cpp` per-file rate
  relative to the pre-fix coverage run.

Evidence: `## Combined result` and `## Product-only result`
blocks in `coverage-report.md`, per the T114/T114a citation
rules in
[part-13-t114-product-only-coverage.md](part-13-t114-product-only-coverage.md)
and
[part-14-t114a-tooling-limitation.md](part-14-t114a-tooling-limitation.md).
T114a is still subject to the `/Ob2` inlining tooling
limitation recorded in part-14.

## 8. Stage 4-9 regression

Confirm no regression in the existing Stage 4-9 test rows. The
implementation only touches `server-context.cpp` in the
speculative batch building path, which only the MTP path
exercises. Non-MTP and non-hybrid paths should be unaffected.

Pass criteria:

- R20/R21/Q110 (Stage 4-5 regression rows) pass.
- R22/Q111 (Stage 6 regression rows) pass.
- R23/Q112 (Stage 7-8 regression rows) pass.
- Q110-Q112 (Stage 9 regression rows) pass.
- T118-T121 (Stage 4-9 regression rows from part-12) pass.

Evidence: focused test names, source files, and assertion
lines for each regression row, mapped to the row IDs in
[part-10](part-10-stage8-metadata-only-rematerialization.md),
[part-11](part-11-stage9-checkpoint-integration.md), and
[part-12](part-12-stage10-observability-security-hardening.md).

## 9. Observability check

Confirm the new `SRV_DBG` line at
`tools/server/server-context.cpp:3771` emits on every chunked
decode and is bounded.

Pass criteria:

- The line emits the format
  `srv  update_slots: speculative chunked decode, chunk=%d n_tokens=%d cap=%d\n`
  on every iteration of the chunked decode loop.
- The line does not contain prompt text, model path, marker
  material, file path, namespace test strings, checksum
  values, payload bytes, or serialized cache content.
- The three format arguments are integer values (`chunk`,
  `n_tokens`, `cap`).

Evidence: server log capture with `SRV_DBG` verbosity enabled,
or focused test that invokes the chunked decode loop and
captures the emitted line. Cite the format string and the three
integer arguments.

## 10. Out of scope

- k6 load tests.
- Stress tests beyond the existing part-06 stress rows.
- Benchmark rows.
- Coverage denominator changes.
- Re-running the T114 and T114a coverage rows is in scope (see
  section 7); adding new covered code is not.
- Editing the test plan entry doc, parts 1-14, or any prior
  test-plan review file.

## 11. Evidence format

Each test row must cite:

- File path of the source or log under test.
- Row ID (T-MTP-FIX-01, T-NOUT-MAX-01, T-NOUT-MAX-02, or the
  referenced H/T/Q/R row for regression).
- Pass criterion (copied from this part).
- Evidence location: focused test name and source line, or
  artifact path under
  `._design_docs/.test_reports/test-report-YYYYMMDD-NN-artifacts/`.

Do not report run-specific results in this plan. Store execution
evidence only in a fresh
`._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` file
after QA execution opens.
