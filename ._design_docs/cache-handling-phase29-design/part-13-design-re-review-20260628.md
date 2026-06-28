VERDICT: PASS

# Stage 29 design re-review (independent Architect re-review, 2026-06-28)

Reviewer session: 2026-06-28 (fresh; explicitly distinct from the design
author, the prior reviewer, and the correction author)
Role: Architect independent re-review
Subject: corrected Stage 29 design after the rework issued by
`part-12-design-review-20260628.md` (5 BLOCKING + 4 INFO findings)

## Re-reviewer session metadata

- Date: 2026-06-28
- Role: Architect independent re-review
- Session: NEW fresh session. Distinct from:
  - Session A (design author of the original 12 files)
  - Session B (prior independent reviewer who issued the REWORK)
  - Session C (correction author who chose option (a) wrapper script)
- State policy: NO state from prior Architect sessions was loaded. Every
  source doc was read from disk before authoring this report.
- Method: byte-level verification of every file (LF, CR, BOM, non-ASCII,
  trailing whitespace, line count), function-signature read of the Stage 20
  lib, byte-level call-site read of the new wrapper, grep against the Stage
  24 -06 test report for the cited `cache_n nonzero_rate` value, and
  cross-check of every cited finding ID against the corrected part files.

## 1. Verdict

PASS. Every BLOCKING (B-01..B-05) and INFO (N-01..N-04) finding from the
prior review was correctly addressed in the corrected design. The new
wrapper script `lib/compare-legacy-vs-hybrid-workload.ps1` matches the
Stage 20 lib's actual parameter set, dot-sources the lib without copying
or modifying it, applies the 40/30/30 distribution, and emits per-request
JSONL matching part-04. The Phase 0.5 tokenize helper sub-phase is
correctly documented in part-03 with the `BLOCKED-workload-build`
failure classification. The Stage 24 -06 cache_n claim is present in the
test report. All 14 files are LF-only UTF-8, no BOM, no CR, no non-ASCII,
no trailing whitespace, last byte LF, under 300 lines.

## 2. Finding-by-finding verification

Each finding from the prior review (`part-12-design-review-20260628.md`,
section 12) is verified against the corrected design. The verification
column reads CORRECTED when the correction is present and applied
correctly.

| ID | Severity | Original finding | Corrected location | Verification |
| --- | --- | --- | --- | --- |
| B-01 | BLOCKING | Driver invocation uses parameters that do not exist in `New-AgenticChatPrompt` | part-02 L85-89 (wrapper introduced as design-correction option (a)); L91-103 (rationale); L108-118 (correct driver invocation block); part-08 L13-14 (corrected reuse rows); wrapper script `lib/compare-legacy-vs-hybrid-workload.ps1` (NEW, 200 lines) | VERIFIED. Wrapper exists, dot-sources Stage 20 lib, calls `New-AgenticChatPrompt` at L106 and L142 with the actual parameter set. The wrapper's `$OutPath` is the aggregate JSONL, not a single-prompt JSON file. |
| B-02 | BLOCKING | Generator requires live `/tokenize` endpoint but Phase 0 has no server | part-03 L30-44 (Phase 0.5 sub-phase with tokenize helper); L45-50 (rationale citing the review finding B-02) | VERIFIED. Phase 0.5 boots llama-server on port 8900 with `--cache-mode legacy` for `/tokenize`, calls `New-ComparisonWorkload`, shuts down the helper, applies cooldown, then proceeds to Phase 1. Helper is NOT reused for Phase 1 or later. |
| B-03 | BLOCKING | Documented output schema fields did not match what the Stage 20 lib emits | part-02 L120-142 (JSONL per-request fields matching part-04: `request_id`, `cache_class`, `messages`, `max_tokens`, `temperature`, `seed`); wrapper script L154-162 (per-request `[pscustomobject]` with these exact field names) | VERIFIED. Wrapper L154-162 builds per-request lines with the six required fields and writes one JSON object per line via `ConvertTo-Json -Depth 10 -Compress`. The wrapper's aggregate emission path at L166-168 writes with LF-only UTF-8 no BOM. |
| B-04 | BLOCKING | Reuse table claimed parameters that do not exist; "No modification" claim was wrong | part-08 L13 (Stage 20 lib row: "Wrapper script dot-sources it and loops `New-AgenticChatPrompt` (target tokens, size class, prompt class, out path, server URL). Stage 20 lib is NOT modified. Cited per review finding B-04"); L14 (wrapper row: NEW artefact) | VERIFIED. Both rows correctly describe the wrapper-based invocation. The Stage 20 lib's mtime is 2026-06-27 11:11:29 (before the wrapper's mtime 2026-06-28 19:10:59), confirming the lib was not modified by the wrapper author. |
| B-05 | BLOCKING | Risk register did not enumerate an "API mismatch" risk | part-09 L23 (R29-12 row: "Driver invocation does not match the lib API (review findings B-01, B-02, B-03, B-04; B-05 added per rework list in `part-12-design-review-20260628.md`)") | VERIFIED. R29-12 is present with trigger, impact, mitigation, and mitigation-before-approval columns. It explicitly cites all five BLOCKING finding IDs and names option (a) as the chosen mitigation. |
| N-01 | INFO | `tools/server/hybrid-cache.md` still uses pre-Stage-26 underscore names; design cites it for metric list | part-08 L30 (adapt row: "NOTE: this file still uses pre-Stage-26 underscore names (`llamacpp_cache_X`). Driver uses post-Stage-26 colon names (`llamacpp:cache_X`). When hybrid-cache.md is updated to the post-Stage-26 form (a separate doc-maintenance task), the citations become consistent.") | VERIFIED. Doc-consistency gap is explicitly acknowledged and the source-of-truth is named (part-04 metric list, not hybrid-cache.md). |
| N-02 | INFO | D-EXEC-27-08 cite `server-cache-hybrid.cpp:3396` is stale (file is now 5400 lines) | part-10 L58 ("historical line reference: `tools/server/server-cache-hybrid.cpp:3396` at the time of Stage 27 closure; file is now 5400 lines and the legacy `demote_payload` definition sits around line 462). Stage 29 does not modify this code."); part-11 L101-103 (same qualification) | VERIFIED. Both cites are explicitly marked as historical references with the current line count and the legacy definition location named. |
| N-03 | INFO | `cache_n=15` for s03-exact-0-0 should be verified against Stage 24 -06 test report | part-07 L22-33 (evidence basis cites aggregate `cache_n nonzero_rate = 0.1306`); L35-42 (implementation-plan verification step names the per-request log path; "Stage 29 does not pre-commit to the value 15") | VERIFIED. The unverified per-request value is replaced with the aggregate durable signal; the implementation plan is tasked with reading the per-request log if a specific value is needed. |
| N-04 | INFO | Stage 27 closure evidence (687 reqs vs 258 crash threshold) should be echoed in part-01 G4 | part-01 L25-26 ("Stage 27 closure evidence (per review finding N-04): S03 hybrid reached 687 requests on Stage 24 -07 (vs the 258-request crash threshold, 2.65x past the failure point), per `test-report-20260626-07.md` and D-CLOSURE-27-01.") | VERIFIED. The 687 reqs signal is echoed in part-01 G4 with the source test report and closure ID cited. |

## 3. Wrapper script review

The new wrapper `._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1`
was byte-level inspected.

| Requirement | Verification |
| --- | --- |
| File exists | VERIFIED. 200 lines, 7786 bytes, LF=200, CR=0, BOM=False, non-ASCII=0, last byte 0x0A, trailing whitespace 0. |
| Dot-sources Stage 20 lib, does NOT copy or modify | VERIFIED. L17 documents the dot-source pattern in usage header. No Stage 20 function bodies (banks, helpers, tokenize call) appear inside the wrapper. Two call sites only: L106 (anchor pool pass) and L142 (per-request fresh pass). Stage 20 lib mtime 2026-06-27 is before wrapper mtime 2026-06-28. |
| Calls `New-AgenticChatPrompt` with actual parameter set | VERIFIED. L106-113: `-TargetTokens`, `-SizeClass`, `-PromptClass`, `-OutPath`, `-ServerUrl`, `-Seed`, `-TimeoutSec`. L142-149: same parameter set. The Stage 20 lib signature at L82-99 confirms these are the actual parameter names. |
| Aggregates per-request output into a single JSONL | VERIFIED. L100-168 builds `$requestLines` list, emits one per request, writes to a single file via `[System.IO.File]::WriteAllLines($OutPath, $requestLines, $utf8)` with LF-only UTF-8 no BOM. |
| Applies 40/30/30 distribution | VERIFIED. L29-33 (`$script:DefaultDistribution` = `exact=0.4; near_prefix=0.3; new_branch=0.3`). L77-79 enforces sum-to-1.0. L83-86 enforces required keys. L121-124 applies the per-request roll against the cumulative distribution (`$exactCutoff`, `$nearPrefixCutoff`). L20 in usage block shows the parameter override form. |
| JSONL fields match part-04 metric list | VERIFIED. L154-162: `request_id`, `cache_class`, `messages`, `max_tokens`, `temperature`, `seed`. The part-04 required-fields table (per-request metric list) at L17-30 names exactly these six fields. |
| Format compliance | VERIFIED. 200 lines (under 300 cap). LF-only, no CR, no BOM, no non-ASCII, no trailing whitespace, last byte 0x0A. `git diff --no-index --check` against an empty file reports no whitespace errors. |
| Calls to Stage 20 lib functions with actual parameter names (not fabricated) | VERIFIED. `Select-String` against the wrapper for `New-AgenticChatPrompt` returns three matches (L46 in comment, L106 call, L142 call). The two call sites use only the seven parameters actually declared at lib L82-99: `TargetTokens`, `SizeClass`, `PromptClass`, `OutPath`, `ServerUrl`, `Seed`, `TimeoutSec`. None of the fabricated parameter names from the prior review (`OutputJsonl`, `RequestCount`, `CacheClassDistribution`, `MinPrefixTokens`, `MaxPrefixTokens`) appear anywhere in the wrapper. |

## 4. Phase 0.5 tokenize helper review

part-03 sequencing was byte-level read at L24-60.

| Requirement | Verification |
| --- | --- |
| Boots legacy binary briefly | VERIFIED. L32: "boot llama-server on port 8900 with `--cache-mode legacy`". L33 allows `--n-gpu-layers 0` because `/tokenize` does not need GPU load. |
| Runs workload build against live `/tokenize` endpoint | VERIFIED. L35-37 calls `New-ComparisonWorkload` via the new wrapper to emit `workload.jsonl` (200 reqs, 40/30/30 distribution). L38-39 emits a 5-prompt equivalence JSONL via the same wrapper. |
| Shuts down legacy | VERIFIED. L40: "shut down the helper server gracefully". |
| Applies cooldown before Phase 1 | VERIFIED. L41: "apply the standard cooldown (VRAM back-to-baseline, max 120s)". |
| Helper is NOT reused for later phases | VERIFIED. L42-43: "the helper is NOT reused for Phase 1 or later phases; each phase boots its own server per the per-mode cooldown rule". |
| Failure classification `BLOCKED-workload-build` with correct failure-mode description | VERIFIED. L52-56: "if the tokenize helper fails to come up, if New-ComparisonWorkload throws, or if the workload.jsonl is missing required fields (request_id, cache_class, messages, max_tokens, temperature, seed), the driver classifies the run as BLOCKED-workload-build and stops". |
| Rationale cites review finding B-02 | VERIFIED. L45: "Why this sub-phase exists: per review finding B-02, the Stage 20 lib's New-AgenticChatPrompt calls /tokenize on every iteration to drive adaptive chunking". |

## 5. Stage 24 -06 cache_n claim verification

The Stage 29 part-07 evidence basis (L22-26) cites:

> the aggregate `cache_n nonzero_rate` reported in
> `test-report-20260624-06.md` for S03 hybrid is 0.1306 across 280
> evidence records with 64 hits

Byte-level inspection of `._design_docs/.test_reports/test-report-20260624-06.md`
confirmed:

- `cache_n nonzero_rate: 0.1306` at L83 (S03 hybrid leg)
- `prompt_evidence.records: 280, profiles: {"checkpoint_dependent":280}, lookup_outcomes: {"exact_entry_absent":216,"hit":64}` at L87
- `280 OK requests` at L48, L81, L82, L116, L130 (consistent)

All three numeric claims (0.1306, 280, 64) are present in the test report
body. The Stage 29 part-07 L40 also restates the aggregate as "64 hits /
280 OK requests" which matches the report. VERIFIED.

## 6. Document size audit

Every part file is under 300 lines. Byte-level inspection on 2026-06-28:

| File | Lines | LF | CR | BOM | Non-ASCII | Last byte |
| --- | ---: | ---: | ---: | --- | ---: | --- |
| cache-handling-phase29-design.md | 111 | 111 | 0 | NO | 0 | 0x0A |
| part-01-goals-scope-exclusions.md | 122 | 122 | 0 | NO | 0 | 0x0A |
| part-02-workload-capture-mechanism.md | 187 | 187 | 0 | NO | 0 | 0x0A |
| part-03-comparison-driver-design.md | 246 | 246 | 0 | NO | 0 | 0x0A |
| part-04-per-request-metric-list.md | 141 | 141 | 0 | NO | 0 | 0x0A |
| part-05-three-layer-report-and-decision-support.md | 160 | 160 | 0 | NO | 0 | 0x0A |
| part-06-binding-decisions-resolved.md | 160 | 160 | 0 | NO | 0 | 0x0A |
| part-07-open-questions-resolved.md | 146 | 146 | 0 | NO | 0 | 0x0A |
| part-08-reuse-vs-new-artefacts.md | 80 | 80 | 0 | NO | 0 | 0x0A |
| part-09-risk-register.md | 50 | 50 | 0 | NO | 0 | 0x0A |
| part-10-traceability.md | 95 | 95 | 0 | NO | 0 | 0x0A |
| part-11-reconciliation-with-prior-stages.md | 175 | 175 | 0 | NO | 0 | 0x0A |
| part-12-design-review-20260628.md | 263 | 263 | 0 | NO | 0 | 0x0A |
| compare-legacy-vs-hybrid-workload.ps1 | 200 | 200 | 0 | NO | 0 | 0x0A |

All files are under 300 lines. The largest is part-12 at 263 lines
(unchanged). The wrapper at 200 lines is the second-largest new file.

## 7. Format compliance

- LF line endings: every file's LF count equals its line count, CR=0 for
  every file.
- No BOM: every file's first three bytes are NOT `239,187,191`.
- No non-ASCII: zero characters with code >= 128 in any file.
- No trailing whitespace: zero lines match `\s+$` in any file.
- Trailing newline: every file's last byte is 0x0A.
- `git diff --no-index --check` against an empty file: every file reports
  no whitespace errors (CRLF or trailing whitespace).

All format requirements met. VERIFIED.

## 8. New findings

| ID | Severity | Part file | Line or section | Finding | Suggested resolution |
| --- | --- | --- | --- | --- | --- |
| NONE | - | - | - | No new findings. | - |

## 9. Cross-cutting observations (non-blocking, INFO only)

These are observations from the re-reviewer that fall outside the scope
of the prior findings but may be useful to downstream agents. They do NOT
block this PASS.

### C-01 (INFO) Wrapper enforces cumulative distribution via `nextDouble()` only

The wrapper applies the 40/30/30 distribution per request using
`$rng.NextDouble()` (L121-124 in the wrapper). With 200 requests the
expected counts are 80/60/60. Empirical deviation depends on the seed.
The driver should report the actual counts in `summary.json` so any
unexpected skew surfaces in the report. Not a defect, just a suggestion
for the implementation plan.

### C-02 (INFO) Stage 20 lib `TimeoutSec` default is 30s, wrapper passes through

The wrapper accepts `-TokenizeTimeoutSec` (default 60, L65) and passes
it to `-TimeoutSec` on `New-AgenticChatPrompt` (L113, L149). The Stage
20 lib default is 30s (L96). If the driver does not override this, a
tokenize endpoint under load could timeout at 30s and abort the anchor
build. The wrapper default of 60s is reasonable but should be tested
under the Stage 29 leg loads.

### C-03 (INFO) `summary.json` per-cycle cache-class counts not in design

part-02 L139 documents `messages` field but does not mandate that the
driver record the empirical cache_class counts per cycle. Recommend the
implementation plan add a `cache_class_counts` field to `summary.json`
so per-cycle distribution drift surfaces in the report.

## 10. Next owner and next gate

Manager design gate review. Stage 29 design is now PASS-ready for
Manager gate. The Manager gate reviewer should focus on:

- Whether the 80-minute budget documented in part-03 fits the planned
  execution session.
- Whether the optional proxy capture in part-02 should be approved as
  supplementary ground truth or deferred.
- Whether Stage 29 should produce an implementation-plan gate or jump
  straight to QA test-plan authoring after Manager PASS.

After Manager design gate PASS:

- Developer: implementation plan.
- After Developer plan PASS: QA: test plan.
- After QA test plan PASS: Manager: execution gate.
- After execution: Developer: test-results review.
- After Developer review PASS: Manager: closure per D-CLOSURE-29-NN.

## 11. Re-reviewer statement

This re-review was authored in a fresh Architect session on 2026-06-28.
No state from the design author session (A), the prior reviewer session
(B), or the correction author session (C) was loaded or relied on. All
14 source files were read from disk and byte-level verified. The wrapper
script was independently inspected for parameter alignment against the
Stage 20 lib's actual `New-AgenticChatPrompt` signature (lib L82-99).
The Stage 24 -06 cache_n claim was independently confirmed by grep
against the test report body. The Phase 0.5 tokenize helper sub-phase
was independently confirmed by line-by-line read of part-03 L24-60.
The 40/30/30 distribution enforcement was independently confirmed by
read of wrapper L29-33, L77-79, L83-86, L121-124. Format compliance was
independently confirmed by byte-level audit of every file.

VERDICT: PASS.
