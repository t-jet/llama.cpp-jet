# Stage 11 test report 20260604-04 rerun

Source report: [test-report-20260604-04.md](test-report-20260604-04.md)
Trigger: [cache-handling-phase11-implementation/part-08-architect-bug-fix-review-gate-01.md](../cache-handling-phase11-implementation/part-08-architect-bug-fix-review-gate-01.md) (T114/T114a residual)
Date: 2026-06-04
Owner: Stage 11 Developer (rerun session)
Base commit: 8682e209b
Branch: cache-optimization-stage11-merge
Next owner: Stage 11 Manager (closure decision) with fixes session routing
Verifier: Stage 11 Architect (rerun review)

## Scope

This rerun is the follow-up Developer session that the
Architect bug-fix review gate 01 routed to clear the T114 and
T114a residual. The task was a full rebuild of `build-cov/`
and a rerun of the coverage script. The hard rules were: no
full test suite, no k6, no QA execution, no design update, no
implementation plan update, no pre-merge report update, no
fixes report update, no push to `origin`.

## Build summary

The `build-cov/` tree was wiped of all build outputs
(`build-cov/bin`, `build-cov/tools`, `build-cov/tests`,
`build-cov/examples`, `build-cov/pocs`, `build-cov/common`,
`build-cov/ggml`, `build-cov/src`, `build-cov/CMakeFiles`)
and reconfigured with the same generator and flags. The full
rebuild used the umbrella target (default `cmake --build
build-cov --config Release` with no explicit target).

| Metric | Value |
| --- | --- |
| Build log path | `._design_docs/.test_reports/test-report-20260604-04-artifacts/build-cov-full-rebuild.log` |
| Build log lines | 303 |
| vcxproj link lines | 84 |
| Errors | 0 |
| Warnings | 2 |
| Elapsed seconds | 125 |
| Exit code | 0 |
| DLLs in build-cov/bin/Release | 14 |
| PDBs in build-cov/bin/Release | 79 |
| Test exes in build-cov/bin/Release | 42 |

All DLLs in `build-cov/bin/Release/` are timestamped
2026-06-04 17:35-17:38 (this rebuild). The most recent DLL
(llama-server-impl.dll) is timestamped 2026-06-04 17:38:16.
The test exes are timestamped 2026-06-04 17:38-17:39 (this
rebuild). The build is PDB-enabled
(`CMAKE_CXX_FLAGS_RELEASE=/Zi /Ob1 /O2 /EHsc`,
`CMAKE_EXE_LINKER_FLAGS_RELEASE=/DEBUG:FULL`).

## Coverage rerun result

The coverage script was rerun against the rebuilt `build-cov/`:

```powershell
$env:LLAMA_CACHE_TEST_MODEL = 'D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf'
pwsh -NoProfile -File ._design_docs\cache-handling-test-scripts\run_coverage.ps1 -BuildDir build-cov -OutDir ._design_docs\.test_reports\coverage-run
```

| Phase | Result |
| --- | --- |
| Phase 1 (9 focused tests) | 9/9 PASS, .cov files 5086-28666 bytes each |
| Phase 2 (server HTTP probe) | PASS, server-probe.cov 102 bytes |
| Phase 3 (merge) | exit 0 |
| Phase 4 (report) | coverage-report.md written |
| Script exit code | 0 |
| Cobertura XML size | 1096927 bytes (1.05 MB) |

## T114 verdict (Combined result block)

Cited from `._design_docs/.test_reports/coverage-run/coverage-report.md`
`## Combined result` block:

```text
## Combined result

- Combined line rate: 0.8508
- Combined covered: 5359 / 6299
- 80% threshold: PASS
```

**T114 verdict: PASS** (0.8508 >= 0.80, 5359 / 6299 lines).

The 0/0 T114 residual from the bug-fix review gate 01 is
cleared. The combined rate is within 0.0013 of the Stage 10
closure rate of 0.8521.

## T114a verdict (Product-only result block)

Cited from `._design_docs/.test_reports/coverage-run/coverage-report.md`
`## Product-only result` block:

```text
## Product-only result

- Product-only line rate: 0.6974
- Product-only covered: 2077 / 2978
- 70% threshold: FAIL
```

**T114a verdict: FAIL** (0.6974 < 0.70, 2077 / 2978 lines).
The product-only rate is 0.0026 below the 70% floor.

### Per-file product-only breakdown

The 11 product files in the denominator, sorted by rate:

| File | Line rate | Covered | Valid |
| --- | --- | --- | --- |
| server-cache-graph.h | 0.95 | 19 | 20 |
| server-cache-graph.cpp | 0.8719 | 463 | 531 |
| server-cache-store-cold.cpp | 0.8688 | 192 | 221 |
| server-cache-io-worker.cpp | 0.8442 | 130 | 154 |
| server-cache-controller.cpp | 0.8333 | 5 | 6 |
| server-cache-store-cold.h | 0.7407 | 20 | 27 |
| server-cache-policy-lru.cpp | 0.7037 | 19 | 27 |
| server-cache-hybrid.cpp | 0.6197 | 1144 | 1846 |
| server-cache-hybrid.h | 0.5929 | 83 | 140 |
| server-cache-controller.h | 0.4 | 2 | 5 |
| server-cache-legacy.h | 0 | 0 | 1 |
| **Combined (11 files)** | **0.6974** | **2077** | **2978** |

Two product files are well below the 70% floor:
`server-cache-legacy.h` at 0/1 (the only non-test file with
zero coverage) and `server-cache-controller.h` at 0.4.
`server-cache-hybrid.h` at 0.5929 and `server-cache-hybrid.cpp`
at 0.6197 are the largest uncovered surfaces (680 and 57
uncovered lines respectively per the Architect review Finding
B C2 follow-up). `server-cache-policy-lru.cpp` at 0.7037 is
above the floor but below the 80% C1 follow-up target.

## Closure status

| Row | Verdict | Status |
| --- | --- | --- |
| T114 | PASS | closure contract met |
| T114a | FAIL | closure contract not met (0.6974 < 0.70) |

Stage 11 closure status: **FAIL pending T114a**. The
combined T114 row is now PASS; the product-only T114a row
remains FAIL.

## Handoff

The T114a failure is a new closure gap that was masked by the
0/0 residual in the bug-fix review gate 01. The product-only
rate of 0.6974 is 0.0026 below the 70% floor. The two largest
gaps are `server-cache-legacy.h` (0/1) and
`server-cache-controller.h` (0.4). The `server-cache-hybrid.h`
and `server-cache-hybrid.cpp` surfaces are the C2 follow-up
target from the Architect review Finding B.

The rerun does not update
`test-report-20260604-04.md` or `merge-log-20260604-01.md`
because T114a is FAIL. The rerun routes the T114a failure to
[test-report-20260604-04-rerun-fixes.md](test-report-20260604-04-rerun-fixes.md)
for a separate Developer fixes session.

- **This gate:** Stage 11 Developer rerun (full rebuild +
  coverage rerun) PARTIAL (T114 PASS, T114a FAIL).
- **Next gate:** Stage 11 Manager closure decision on the
  T114a failure.
- **Next owner:** Stage 11 Manager, with a separate Stage 11
  Developer fixes session for the T114a product-only gap.
- **Stage 11 closure status:** FAIL pending the T114a
  product-only coverage gap.
- **Documented evidence:** `coverage-report.md`,
  `coverage-merged.xml` (1.05 MB), and the build log at
  `build-cov-full-rebuild.log`.
