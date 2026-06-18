Status: REWORK
Date: 2026-06-18
Stage: 18 (Stage 17 Closure Trivial Follow-ups)
Gate: Bug-fix loop iteration 1 review
Reviewer: Architect (fresh session)
Source verdict: Developer reports PASS (91/91 focused, bounded-error repros for F-18-EXEC-01 and F-18-EXEC-02, safe paths regression-free).

## Inputs reviewed

| Input | Path | Verified |
| --- | --- | --- |
| Parent test report (FAIL) | _design_docs/.test_reports/test-report-20260618-01.md | yes (87 lines, LF-only, CR=False) |
| Bug-fix report (PASS) | _design_docs/.test_reports/test-report-20260618-01-fixes.md | yes (184 lines, **CR=True**, BOM=False, Unicode=False) |
| Server source (touched) | tools/server/server-context.cpp | yes (322531 bytes, LF-only, CR=False) |
| Test source (touched) | tests/test-cache-controller.cpp | yes (147591 bytes, LF-only, CR=False) |
| Bug-fix artifacts | _test_output/test-report-20260618-01-fixes-artifacts/ | 31 files; repro logs present |
| Git diff | git diff HEAD -- tools/server/server-context.cpp | SRV_ERR/throw mapping verified |
| Pre-fix source | git show HEAD:tools/server/server-context.cpp | SRV_ERR strings match |

## Verification checklist

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | Validation block at lines 1242-1291 BEFORE common_init_from_params at line ~1292 | PASS | Read file lines 1200-1300: block comment at 1242, last return false at 1288, common_init_from_params at 1292 |
| 2 | return false pattern used (load_model returns bool) | PASS | 8 return false calls at lines 1252, 1259, 1264, 1268, 1272, 1278, 1284, 1288 |
| 3 | All validation checks preserved with byte-identical SRV_ERR strings | PASS | git diff HEAD shows SRV_ERR strings unchanged; only throw std::runtime_error -> return false |
| 4 | Safe path regressions absent (hybrid+cold-path, hybrid+raw+log-prompts-dir, MTP) | PASS | it2-hybrid-coldpath.ps1 (HTTP 200, cold store log), it3-raw-safe.ps1 (HTTP 200), parent IT6 (cache_n=11 on second request) |
| 5 | 91/91 focused tests PASS (89+2 new) | PASS-MINOR | test-cache-controller-direct.log shows "Total: 89 tests (87 prior + 2 Stage 18 bugfix 2026-06-18)", 89 PASSED, 0 FAILED. Developer description "91" is a typo; actual count is 89 with 2 new tests included |
| 6 | F-18-EXEC-01 repro: clean bounded error, not 0xC0000409 | PASS | f18exec01-server.out.log: bounded error "--cache-cold-max-mib requires --cache-mode hybrid", exit 1 |
| 7 | F-18-EXEC-02 repro: clean bounded error, not 0xC0000409 | PASS | f18exec02-server.out.log: bounded error "--cache-prompt-evidence requires --cache-mode hybrid", exit 1. f18exec02b-server.out.log (hybrid+raw) shows exact text "raw prompt evidence requires --log-prompts-dir" |
| 8 | Bug-fix report: under 300 lines, LF-only, no unicode | **BLOCKING-FAIL** | 184 lines OK; Unicode False OK; **CR=True (CRLF line endings)**, contradicts Developer's own claim "This file uses LF line endings". Parent report is LF-only (CR=False) so this is fixable |

## Findings

| # | Severity | Title | Evidence | Action |
| --- | --- | --- | --- | --- |
| B-18-ARCH-01 | BLOCKING | Bug-fix report has CRLF line endings despite claiming LF | `[System.IO.File]::ReadAllBytes` on test-report-20260618-01-fixes.md returns CR=True; sibling test-report-20260618-01.md is CR=False | Developer in same/next fresh session: convert test-report-20260618-01-fixes.md to LF-only UTF-8 (no BOM). Verify with byte check. Re-run git diff --check |
| NB-18-ARCH-01 | non-blocking | Check count description: Developer says "7 if/SRV_ERR checks" but actual count is 8 | git diff HEAD shows 8 SRV_ERR/return false pairs (cold-max-mib < -1; invalid evidence mode; prompt-evidence requires hybrid; prompt-evidence requires evidence-dir; raw requires log-prompts-dir; cold-max-mib requires hybrid; cold-path requires hybrid; cold-max-mib requires cold-path). Pre-fix HEAD also has 8 SRV_ERRs. All preserved byte-identically | None for code; optional fix: update Developer description to "8" for accuracy |
| NB-18-ARCH-02 | non-blocking | Test count description: Developer says "91 PASSED (89 prior + 2 new)" but binary summary enumerates "Total: 89 tests (87 prior + 2 Stage 18 bugfix)" | test-cache-controller-direct.log final block; summary count string updated to include 2 new tests | None for code; optional fix: update Developer description to "89 PASSED (87 prior + 2 new)" |
| I-18-ARCH-01 | INFO | throw to return-false rationale is sound | Uncaught std::runtime_error on Windows triggers __fastfail -> 0xC0000409 (same code as warmup crash); return-false pattern matches existing lines 1299, 1334, 1353 in same function | None |
| I-18-ARCH-02 | INFO | Comment at line 1242 is good | Cites Stage 18 F-18-EXEC-01/F-18-EXEC-02 and Stage 17 F-17-EXEC-01 with date; explains why block runs before warmup | None |
| I-18-ARCH-03 | INFO | FT3 invariant intact | Select-String "cache-cold-path requires --cache-mode hybrid" returns 1 match at line 1283 (SRV_ERR); duplicate at 1554-1557 from Stage 18 Item 1 remains removed | None |

## Counts

BLOCKING: 1
non-blocking: 2
INFO: 3

## Verdict

REWORK. The Stage 18 F-18-EXEC-01 and F-18-EXEC-02 fix is functionally correct: validation block moved to lines 1242-1291 before common_init_from_params at line 1292; throw replaced with return false; all SRV_ERR strings byte-identical to pre-fix; both repro commands produce bounded-error exit code 1 instead of STATUS_STACK_BUFFER_OVERRUN; safe paths (hybrid+cold-path, hybrid+raw+log-prompts-dir, MTP regression) unaffected; 2 new focused tests pass; source files are LF-only. However, the bug-fix report at test-report-20260618-01-fixes.md is saved with CRLF line endings (CR=True) while its own text claims "This file uses LF line endings", directly violating user-listed checklist item 8 ("LF-only"). The sibling parent report test-report-20260618-01.md is LF-only, confirming LF is achievable. Per Architect memory improvement `CRLF and trailing whitespace on Windows tool-inserted content`, this must be fixed before sign-off.

## Handoff

Next owner: **Developer in a new fresh session** to address B-18-ARCH-01. Action:

1. Convert _design_docs/.test_reports/test-report-20260618-01-fixes.md to LF-only UTF-8 (no BOM): read raw bytes, strip 0x0D, write via `[System.IO.File]::WriteAllBytes`.
2. Verify with: `[System.IO.File]::ReadAllBytes(... )` returns CR=False; `[System.IO.File]::ReadAllBytes(... )` length matches UTF-8 byte count; `git diff --check HEAD -- _design_docs/.test_reports/test-report-20260618-01-fixes.md` exits 0 with no output.
3. Optionally correct NB-18-ARCH-01 ("8" not "7") and NB-18-ARCH-02 ("89 not 91") in the same file for description accuracy.
4. After fix, re-run the verification checklist and resubmit for Architect re-review.

After Architect re-review PASS, next gate is Manager closure of Stage 18 bug-fix loop iteration 1, then QA re-execution of parent test plan rows IT1 and IT3 in a fresh session.

## Notes

- This review report is read-only: no source code, design, implementation, architecture, or test plan docs modified.
- File written with LF line endings, no BOM, ASCII-only per the same constraint the Developer violated.
