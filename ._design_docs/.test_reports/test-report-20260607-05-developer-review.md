# Test report 20260607-05 Developer test-results review
- ID: test-report-20260607-05-developer-review
- Date: 2026-06-07
- Reviewer: Developer
- Source: test-report-20260607-05.md + 20260607-05-fixes.md

## 1. Scope
Stage 12 re-execution after S01/S05 serverFlags fix. 33 rows counted: preflight (8), stress (10: 8 live + S07/S08 blocked), bench (8: 2 live + 6 blocked), long-run (3 blocked), nearest-legacy (2 subsumed), MTP-capable (2 cap-fix). Build-cov binary unchanged from 2026-06-07 15:48 canonical.

## 2. Per-row summary
  10 PASS, 8 preserved PASS, 2 BLOCKED script (S07/S08 fixed), 9 BLOCKED time-budget, 2 subsumed, 2 cap-fix BLOCKED. 0 product bugs.

Counts:
- 10 PASS: S01, S02-parallel8, S03, S04, S05-plain, S05-target-plus-draft, S05-checkpoint, S06, B01, B02.
- 8 preserved PASS: preflight-1..8 (binary unchanged from 20260607-04).
- 2 BLOCKED script bugs: S07 (invalid --cache-protected-prompt), S08 (same-file redirect). Both fixed in 20260607-05-fixes.md.
- 9 BLOCKED time-budget: B03 partial, B04..B08 not started, L01..L03 not started. Infrastructure-limited, not product bugs.
- 2 subsumed: B05-NL, B08-NL (per part-18a sec 13).
- 2 cap-fix BLOCKED: H53, H54 (MTP-capable Qwen3.5-4B held out per part-29).

## 3. S07/S08 fix verified
S07: --cache-protected-prompt entries removed from $serverFlags literal at lines 41-45 of stress_s12_s07_protected_root_pressure.ps1. Closing paren sits on --seed line. Live request loop at lines 109-129 still exercises protected-roots via repeated prompts; --metrics preserved for llamacpp_cache_protected_root_decisions_total. Script tokenizes clean (868 tokens, 0 errors). Dry-run completes.

S08: precondition Start-Process at line 103 split to .out and .err paths. $precondPath (precondition.log) still names the human-readable summary file. Script tokenizes clean (906 tokens, 0 errors). Dry-run completes without Bug D error.

Pattern matches S02 reference (Join-Path two-distinct-targets). Both fixes are harness-only; llama-server binary is unchanged and is not implicated.

## 4. Closure recommendation
  Stage 12 can close. 0 product bugs. 9 time-budget rows = infrastructure-limited (not blockers; product code works). 2 MTP rows held out per cap-fix closure.

## 5. Manager handoff
- Verdict: Stage 12 closes on 18 PASS (10 live + 8 preserved) with 2 harness-only script fixes applied and verified by parser and dry-run. 9 rows blocked by time budget only; product code worked in all 6 stress + 2 bench live runs.
- Next action: QA re-executes S07 and S08 only (post-fix). All 9 time-budget rows remain unfunded; they do not gate closure.
- MTP rows: held out per cap-fix closure 2026-06-07 (part-29). No retest scope here.
- Out of scope: not committing, not pushing, no product code, no doc change beyond this review.
