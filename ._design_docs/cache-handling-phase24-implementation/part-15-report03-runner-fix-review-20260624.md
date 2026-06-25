# Part 15: report 03 runner fix review 2026-06-24

Status: PASS
Date: 2026-06-24
Owner: Architect
Scope: Review of the runner-only fix for `test-report-20260624-03.md`.

## Inputs reviewed

- `document-index.md`
- `cache-handling-phase24-implementation.md`
- `cache-handling-phase24-implementation/part-14-build-path-and-report03-runner-fix-20260624.md`
- `cache-handling-test-plan/part-29-stage24-chat-s02-s03-comparison.md`
- `cache-handling-test-plan/stage-24-manager-build-path-gate-20260624.md`
- `.test_reports/test-report-20260624-03.md`
- `.test_reports/test-report-20260624-03-fixes.md`
- `cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`
- `._test_output/stage24-chat-s02-s03-20260624-03/S02-chat/native-legacy/server.err.log`
- `._test_output/stage24-fixverify-03/dry-run-plan.json`

## Review result

Verdict: PASS.

Findings: none blocking, none non-blocking.

The root cause is correct. PowerShell variable names are case-insensitive, so a
local `$matches` collection collides with the automatic `$Matches` variable
after `-match` succeeds. Reproducing that shape changes the collection variable
to a hashtable and the next one-argument `Add()` call fails with the same
overload error from the QA report.

The fix is narrow and acceptable. `Get-CudaRuntimeProof` now uses
`$proofMatches`, returns the same `state`, `required`, and `matches` fields, and
does not change request generation, row selection, route selection, metrics,
public API behavior, product code, fixtures, or Stage 23 artifacts.

## Evidence checked

- Parser check: PASS for the runner script.
- Captured QA startup log: `Get-CudaRuntimeProof` returns `PASS`, 3 matches,
  first match on line 3.
- Collision reproduction: local `$matches` becomes `System.Collections.Hashtable`
  after a CUDA proof `-match`, and one-argument `Add()` fails with the report 03
  error.
- Route contract: no legacy `/completion` route literal remains outside the
  required `/v1/chat/completions` route.
- Dry-run proof: `stage24-fixverify-03/dry-run-plan.json` has 2 rows, 4
  variants, all routes `/v1/chat/completions`, required CUDA flags
  `--n-gpu-layers all` and `--fit off`, and `cuda_build_proof.state = PASS`.
- Scratch durable report proof: `test-report-20260624-99.md` was not created.
- Build-path proof: `build-cuda/CMakeCache.txt` contains `GGML_CUDA:BOOL=ON`,
  `GGML_NATIVE:BOOL=OFF`, and `BUILD_SHARED_LIBS:BOOL=OFF`.
- Cleanup proof from report 03 final state: no `llama-server` process remained
  and ports 8900 and 8910 were free.
- Hygiene: reviewed Markdown files are ASCII, LF-only, no BOM, no trailing
  whitespace, and under 300 lines. The fixes report states an older line count
  for itself, but the verified count is 118 lines, still under the cap.

## Handoff

Manager may reopen Stage 24 QA execution from a fresh suffix. The blocked
`test-report-20260624-03.md` remains setup evidence only and cannot close S02 or
S03. The next expected report is `test-report-20260624-04.md` unless Manager
records a different suffix.
