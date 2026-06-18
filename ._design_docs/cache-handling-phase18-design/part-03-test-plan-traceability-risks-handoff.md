# Part 3: Test plan rows, traceability, risks, and handoff

Status: authored; pending Architect design review
Date: 2026-06-18
Stage: 18 (Stage 17 Closure Trivial Follow-ups)
Source: [entry doc](../cache-handling-phase18-design.md),
[Part 1: Item 1](part-01-item1-duplicate-cold-path-hybrid-check.md),
[Part 2: Item 2](part-02-item2-cxx-flags-release-debug-info.md)

## Test plan rows proposed

This design proposes the following new rows for the test plan. Rows are
proposals only; the test-plan author picks them up in a follow-up.

### Item 1 rows

| ID | Type | Description | Expected | Evidence path |
| --- | --- | --- | --- | --- |
| TP-18-FT1 | focused | Build `test-cache-controller.exe` after deletion; run binary directly | 87/87 PASS (74 existing + 13 Stage 17) | build-cov/bin/Release/test-cache-controller-direct.log |
| TP-18-FT2 | focused | Run `git diff --check HEAD -- tools/server/server-context.cpp` | Clean (no CRLF, no trailing whitespace) | git output empty |
| TP-18-FT3 | focused | Run `Select-String` on `tools/server/server-context.cpp` for `--cache-cold-path requires --cache-mode hybrid` | Exactly 1 match (line 1419-1420 in the moved block; the post-slot-init duplicate is removed) | grep output |
| TP-18-IT1 | integration | Start llama-server with `--cache-cold-path <path> --cache-mode legacy` | Server exits cleanly with `cache: --cache-cold-path requires --cache-mode hybrid` error and `--cache-cold-path requires --cache-mode hybrid` runtime_error, exit code non-zero, no STATUS_STACK_BUFFER_OVERRUN | build-cov/bin/Release/llama-server.exe logs |
| TP-18-IT2 | integration | Start llama-server with `--cache-cold-path <path> --cache-mode hybrid --cache-ram 1024` | Server starts normally; logs show cold store path, cold budget; reaches init() and serves /health | llama-server startup log |
| TP-18-IT3 | integration | Re-run Stage 17 IT5 row with same flags | Clean bounded-error exit (raw prompt evidence requires --log-prompts-dir) rather than STATUS_STACK_BUFFER_OVERRUN | per Stage 17 IT5 evidence path |

### Item 2 rows

| ID | Type | Description | Expected | Evidence path |
| --- | --- | --- | --- | --- |
| TP-18-FT4 | focused | `Select-String` on `build-cov/CMakeCache.txt` for `CMAKE_CXX_FLAGS_RELEASE` | Value contains `/Zi` and `/DEBUG:FULL` | grep output |
| TP-18-FT5 | focused | `Select-String` on `build-cov/CMakeCache.txt` for `CMAKE_C_FLAGS_RELEASE` | Value contains `/Zi` and `/DEBUG:FULL` (C flags should match) | grep output |
| TP-18-FT6 | focused | Rebuild `test-cache-controller.exe` with new flags; run binary | 87/87 PASS (74 + 13) | build-cov/bin/Release/test-cache-controller-direct.log |
| TP-18-FT7 | focused | Rebuild `llama-server.exe` with new flags; start, hit /health | Server starts, /health returns 200 OK | llama-server startup log, /health response |
| TP-18-IT4 | integration | Re-run OpenCppCoverage against `test-cache-controller.exe` with `--export_type binary` | `.cov` file is produced, larger than header-only baseline (>100 KB per binary), contains line-count data | coverage-manual-log-*.log, .cov file size |
| TP-18-IT5 | integration | Run `coverage-manual-20260607-02.ps1` (or equivalent) end-to-end | Coverage script completes; .cov files have line data; coverage report generation produces non-trivial line counts | coverage report output |
| TP-18-IT6 | integration | Run `build-cov/bin/Release/llama-server.exe` with MTP fixture; serve a chat completion | Server starts, chat completion succeeds, no regression vs pre-flag-change baseline | llama-server log, completion response |

### Row count

12 rows proposed: 7 focused (TP-18-FT1..FT7) + 6 integration
(TP-18-IT1..IT6).

## Traceability

| Item | Source decision | Source evidence | Artifact | Verdict |
| --- | --- | --- | --- | --- |
| 1 | D17-EXEC-03 | [part-06](../cache-handling-phase17-implementation/part-06-architect-bugfix-review-gate-01.md) finding N17-BUGFIX-01; [Stage 17 closure decisions](../cache-handling-phase17-implementation.md) row D17-EXEC-03 | server-context.cpp lines 1554-1557 (SRV_ERR 1555, throw 1556, closing brace 1557) | design complete; deletion scope identified |
| 2 | D17-CLOSURE-02 / F-16-TR-03 | [Stage 17 closure decisions](../cache-handling-phase17-implementation.md) row D17-CLOSURE-02; [test-report-20260617-01](../../.test_reports/test-report-20260617-01.md) "Coverage" section; build-cov/CMakeCache.txt line 80 | build-cov/CMakeCache.txt line 80 `CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG` | design complete; Option 1 recommended |

## Risks and open questions

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Comment at line 1552 (`// Phase 6: Validate cold path configuration`) becomes misleading after Item 1 deletion | Non-blocking; only affects code readability | Developer removes or rewrites the comment during implementation. Not a design blocker. |
| Reconfiguring build-cov loses other cached variables | Non-blocking; only affects cmake invocation order | Developer captures the existing cmake configure flags before reconfigure, then reapplies them with `-DCMAKE_CXX_FLAGS_RELEASE` added |
| `/Zi` PDB size could exceed CI artifact limits | Low; coverage builds already produce large PDBs | Verify artifact budget with the Manager if the project has one. Not blocking for Stage 18 design. |
| Coverage script (`coverage-manual-20260607-02.ps1`) assumes build-cov path | None; the script reads `$BuildDir/bin/$Config/*.exe` | Script path is unchanged. |
| Other agents downstream may not know the new cmake invocation | Low; only Developer and QA reference build-cov | Implementation evidence records the full cmake command. |
| `git diff HEAD` for the changes is empty for build-cov because CMakeCache.txt is gitignored or only cmake-regenerated | Documentation issue, not a code issue | Implementation evidence documents the cmake command rather than the file diff |

Open questions requiring Manager input before implementation:

- None. Both items are fully specified.

## Handoff

Next owner: Architect for design review in a fresh session.

After Architect design review PASS, the design advances to Manager for the
design gate. After Manager design gate PASS, the design advances to
Developer for implementation planning and implementation.

The Stage 17 implementation log, tracker, document-index, and any other
durable doc are NOT modified by this design. This file uses LF line
endings, plain ASCII status labels, and stays under the 300-line durable
doc cap.
