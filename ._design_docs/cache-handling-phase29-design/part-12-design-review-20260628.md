VERDICT: REWORK

# Stage 29 design review (independent Architect review, 2026-06-28)

Reviewer: Architect (independent design review)
Reviewer session: 2026-06-28 (fresh session; explicitly NOT the design author)
Subject: `._design_docs/cache-handling-phase29-design.md` entry + 11 part files
Source brief: `._design_docs/.manager-inputs/manager-input-20260628-stage29-cache-modes-comparison.md`

## Verdict

REWORK. One BLOCKING root-cause finding (B-01) and four related BLOCKING
sub-findings (B-02, B-03, B-04, B-05) all trace to a single defect: the
driver invocation in part-02 documents a Stage 20 generator API that does
not exist. The agentic-prompt-generator.ps1 lib is single-prompt, single-
class, server-dependent; the design assumes it is multi-request, multi-
class, server-independent. The design must reconcile the driver
invocation with the actual generator before Manager design gate PASS.

## Reviewer session metadata

- Date: 2026-06-28
- Role: Architect independent design review
- Session: fresh. No state from the prior Architect design session was
  loaded or relied on. Treated the 12 design files as the only
  authoritative source. Independent byte-level checks were run against
  the Stage 20 lib and the closed binary.

## 1. Architecture and requirements traceability

Stage 1 requirements (`._design_docs/cache-handling-requirements.md`
parts 1-2) define R1..R133. Stage 29 is comparison-only per part-01
non-goal N1, so only observability-driven requirements are in scope.

| Req | In scope for Stage 29? | Design section |
| --- | --- | --- |
| R1-R4 CLI activation | No (no product change) | correctly omitted |
| R5-R14 hybrid model + model awareness | Indirect (observable via metrics) | part-04, part-05 |
| R15-R17 non-destructive hits | Indirect (cache_hit metric) | part-04 |
| R18-R22 reuse-aware eviction | Indirect (evictions counter) | part-04 |
| R23-R26 protected roots | Not exercised by synthetic workload | not addressed (acceptable) |
| R27-R33 prompt boundaries | Indirect (chat-completion path) | part-02 |
| R34-R36 fallback | Indirect (fallback counter) | part-04, part-05 |
| R80-R86 branch graph | Indirect (checkpoint counters) | part-04 |
| R90-R106 cross-cutting | Indirect (Layer 1) | part-05 |
| R107 80% coverage | Out of scope | part-01 N2 (correct) |

The deferred subrequirements R-REQ-DEFERRED-01..03 in part-10 lines 38-44
are explicitly enumerated. No missing requirement in the in-scope set.

## 2. Prerequisite gaps

| # | Prerequisite | Status | Evidence |
| - | --- | --- | --- |
| 1 | Stage 25-27 invariants preserved | CONFIRMED | Closed binary preserves them. |
| 2 | Stage 28 closure 142/142 PASS | CONFIRMED | Tracker row "CLOSED 142/142 PASS". |
| 3 | `build-cuda/bin/Release/llama-server.exe` | CONFIRMED | Exists, 168655360 bytes, mtime 2026-06-27 10:55:11. |
| 4 | `._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf` | CONFIRMED | Exists. |
| 5 | `lib/agentic-prompt-generator.ps1` (Stage 20 lib) | EXISTS, API MISMATCH | 308 LF, no BOM, no CR. But the lib does NOT match the part-02 driver invocation. See B-01. |
| 6 | Ports 8900..8911 free | Not verifiable | Process check at preflight (part-03 step) is the binding gate. |
| 7-8 | Cold-path and output volumes 30 GiB | Not verifiable | Documented prerequisite only. |
| 9 | nvidia-smi callable | Not verifiable | Documented prerequisite only. |

## 3. Internal contradictions

One internal contradiction between part-02 (driver invocation lines 78-87)
and part-02 itself ("No new generator script is needed" line 65): the
documented driver call uses parameter names that do not exist in the
lib. This is recorded as B-01 below. No other contradictions found
between entry doc and parts or between parts.

## 4. Risks review (part-09)

All 11 risks in part-09 have trigger, impact, mitigation, and mitigation-
before-approval columns. The risk register is complete and follows the
single-column "Mitigation" style of Stage 25 part-07. No missing risks
identified EXCEPT the API-mismatch risk (B-05).

## 5. Metric namespace reconciliation

Spot-checked every metric reference across the 11 part files. All metric
references use the post-Stage-26 colon form `llamacpp:cache_X`. The
`llamacpp_cache_X` underscore form appears only at:

- part-04 line 11 (definition of pre-Stage-26 form)
- part-04 line 17 (driver's grep detector pattern)
- part-09 line 19 R29-08 (risk about regression)
- part-08 line 29 (note that hybrid-cache.md still uses underscore)
- part-11 line 73 (rejection statement)

All five are valid: definitions, detectors, and rejections. No namespace
drift. The proposed counters `llamacpp:cache_exact_blob_restores_total`
(part-04 line 48) and `llamacpp:cache_checkpoint_admissions_total` (line
50) are post-Stage-26 colon form.

## 6. Prior-stage invariant preservation

| Invariant | Cited at | Preserved by |
| --- | --- | --- |
| I-25-01 atomicity | part-10 line 49, part-11 line 60 | part-03 driver sequencing (no async), part-07 D29-OQ-02 |
| I-25-02 isolation | part-10 line 50, part-11 line 60 | part-04 (single-snapshot reads) |
| I-25-03 durability-within-transaction | part-10 line 51, part-11 line 60 | part-04 (before/after deltas) |
| D-EXEC-26-01 SEH handler | part-10 line 55, part-11 line 81 | closed binary |
| D-EXEC-26-02 argv function-scope | part-10 line 56 | closed binary (not directly observable) |
| D-EXEC-26-02 per-id accounting | part-10 line 57, part-11 line 78 | part-04 drift ratio <= 1.10 |
| D-EXEC-27-08 tx_demote_payload at server-cache-hybrid.cpp:3396 | part-10 line 58, part-11 lines 91, 101 | closed binary. Line number is STALE (file is now 5400 lines); see N-02. |
| R28-BUG-02 cold-store reconcile | part-10 line 59, part-11 lines 31, 79, 112, 123 | part-04 drift ratio target |
| F-22-DR-01 demotion coordination | part-10 line 54, part-11 lines 138-142 | demotions/promotions counters |

All seven required invariants are preserved and cited.

## 7. Open question resolutions

D29-OQ-01 cache_n_tokens parity (part-07 lines 14-37): technically
defensible. Both modes emit `timings.cache_n`; the fallback to Prometheus
deltas is a reasonable safety net. The specific number claim
("cache_n=15 for s03-exact-0-0 in the Stage 24 -06 final report") should
be verified by the implementation plan against the actual Stage 24 -06
test report.

D29-OQ-02 cold-path write thread blocking (part-07 lines 40-66):
technically accurate. The tx_* architecture (Stage 25) made all cold-
path operations synchronous; cold-load latency is correctly attributed
to the first cold-hit. Stage 28 R28-BUG-04 worker body deletion (part-11
lines 124-128) corroborates.

D29-OQ-03 workload classes where legacy wins (part-07 lines 69-91):
technically defensible. Per-cache-class column strategy correctly avoids
aggregating the new_branch overhead.

All three resolutions are defensible.

## 8. Driver design review (part-03)

(a) VRAM cooldown gate: per part-03 lines 95-110, the gate is "30s sleep
    + nvidia-smi VRAM back-to-baseline check, max 120s wait". Polls
    nvidia-smi every 5s after the sleep. If VRAM not at baseline within
    120s, classify as BLOCKED-vram-release. REAL gate, not hopeful sleep.
    CONFIRMED binding.

(b) Cold-start cycle isolation: per part-03 lines 73-85, Phase 2 records
    cold-start latency for the first 5 requests separately. Cycle 1 of
    Phase 3 is warm. Cold-start and warm-cycle latencies NOT averaged.
    CONFIRMED correctly isolated.

(c) Output equivalence fail-fast: per part-03 lines 64-72 and part-01 B4,
    the pre-check runs BEFORE the main workload (~5 min for 5 prompts x 2
    modes). On failure, main workload does NOT start. CONFIRMED binding.

(d) Comparison binary path: `build-cuda\bin\Release\llama-server.exe`
    per part-03 line 145. EXISTS (verified). CONFIRMED.

Driver sequencing contradiction: part-03 runs the generator in Phase 0
preflight (lines 47-50) but the generator requires a live `/tokenize`
endpoint. No server is running at Phase 0. Recorded as B-02.

## 9. Reuse vs new artefacts (part-08)

The reuse table is accurate EXCEPT for the agentic-prompt-generator.ps1
entry (B-04). Other reuse candidates verified:

- `lib/Read-BaselineJson.ps1`, `lib/Write-BenchEvidence.ps1`: cited as
  YES/adapt; reasonable.
- `stage24-chat-s02-s03-comparison.ps1`: EXISTS at
  `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`;
  param shape verified, uses post-Stage-26 metric names. Reference-only
  pattern appropriate.

## 10. Document size audit

Every part file is under 300 lines. Verified by byte-level inspection:

| File | Lines | LF | CR | BOM | Last byte |
| --- | --- | --- | --- | --- | --- |
| cache-handling-phase29-design.md | 111 | 111 | 0 | NO | 0x0A |
| part-01-goals-scope-exclusions.md | 119 | 119 | 0 | NO | 0x0A |
| part-02-workload-capture-mechanism.md | 143 | 143 | 0 | NO | 0x0A |
| part-03-comparison-driver-design.md | 218 | 218 | 0 | NO | 0x0A |
| part-04-per-request-metric-list.md | 141 | 141 | 0 | NO | 0x0A |
| part-05-three-layer-report-and-decision-support.md | 160 | 160 | 0 | NO | 0x0A |
| part-06-binding-decisions-resolved.md | 160 | 160 | 0 | NO | 0x0A |
| part-07-open-questions-resolved.md | 131 | 131 | 0 | NO | 0x0A |
| part-08-reuse-vs-new-artefacts.md | 79 | 79 | 0 | NO | 0x0A |
| part-09-risk-register.md | 49 | 49 | 0 | NO | 0x0A |
| part-10-traceability.md | 95 | 95 | 0 | NO | 0x0A |
| part-11-reconciliation-with-prior-stages.md | 171 | 171 | 0 | NO | 0x0A |

## 11. Format compliance

`git diff --check` against the design tree returned no whitespace errors.
Every file is LF-only UTF-8 (no BOM, no CR, no trailing whitespace),
last byte 0x0A. CONFIRMED. Tree is currently untracked by git.

## 12. Findings table

| ID | Severity | Part file | Line or section | Finding | Suggested resolution |
| --- | --- | --- | --- | --- | --- |
| B-01 | BLOCKING | part-02 | lines 78-87 (driver invocation), line 65 ("No new generator script is needed") | Documented driver call uses parameters (`-OutputJsonl`, `-RequestCount`, `-CacheClassDistribution`, `-MaxTokens`, `-MinPrefixTokens`, `-MaxPrefixTokens`) that do not exist in agentic-prompt-generator.ps1. The lib exposes `New-AgenticChatPrompt` with mandatory `-TargetTokens`, `-SizeClass`, `-PromptClass`, `-OutPath`, `-ServerUrl`. It generates ONE prompt per call into ONE JSON file, not a JSONL of 200 requests. | Pick one: (a) drop the "No new generator script is needed" claim and add a wrapper script that calls `New-AgenticChatPrompt` in a loop with a JSONL aggregator; or (b) rewrite the driver invocation to call `New-AgenticChatPrompt` per request with the actual parameter set. |
| B-02 | BLOCKING | part-02 vs part-03 | part-02 lines 78-87 vs part-03 Phase 0 sequencing | The generator requires a live `/tokenize` endpoint to drive adaptive chunking (lib lines 124-148). Phase 0 has no running server. Generator will fail. | Either add a "boot tokenize helper" sub-phase that boots legacy mode briefly for tokenize only, or pre-compute prompt sizes offline and drop the live tokenize dependency. |
| B-03 | BLOCKING | part-02 | lines 88-100 (output schema) | Documented output schema has per-request `request_id`, `cache_class`, `messages`, `max_tokens`, `temperature`, `seed`. The actual generator emits `version`, `size_class`, `prompt_class`, `target_tokens`, `actual_tokens`, `token_measurement`, `messages`, `checksum`, `seed`, `variant`. No `request_id`, no multi-request JSONL, no `max_tokens`. | The workload builder (per B-01 resolution) must emit per-request fields matching part-04's metric list. The 40/30/30 distribution must be applied across the 200-request batch. |
| B-04 | BLOCKING | part-08 | lines 11-13 (reuse table row) | Reuse table claims "Driver calls it with `-OutputJsonl`, `-RequestCount`, `-CacheClassDistribution`, `-Seed`. No modification." None of those parameters exist. | Update the reuse row to reflect either the wrapper (option a of B-01) or the rewritten invocation (option b). |
| B-05 | BLOCKING | part-09 | not present | Risk register does not enumerate an "API mismatch" risk. | Add R29-12 with trigger, impact, mitigation, mitigation-before-approval. |
| N-01 | INFO | part-08 | line 29 | `tools/server/hybrid-cache.md` still uses pre-Stage-26 underscore names per part-08's own admission. Design cites it for metric-list. | Acknowledge as known doc-consistency gap. Stage 29 source-of-truth is part-04 metric list, not hybrid-cache.md. |
| N-02 | INFO | part-10 | line 58, part-11 lines 91, 101 | D-EXEC-27-08 cite `server-cache-hybrid.cpp:3396` is stale; file is now 5400 lines. | Treat line number as historical reference only. Stage 29 does not modify this code. |
| N-03 | INFO | part-07 | lines 22-26 | `cache_n=15` claim for s03-exact-0-0 should be verified against the actual Stage 24 -06 test report. | Add verification step to implementation plan: read `._design_docs/.test_reports/test-report-20260624-06.md` and confirm `cache_n` value. |
| N-04 | INFO | part-01 | line 23 (G4) | Stage 27 closure evidence (687 reqs vs 258 crash threshold) is cited in part-11 lines 27-29 but not echoed in part-01 G4. | Add a single line to part-01 G4 echoing the 687-req verification so part-01 stands alone. |

## 13. Concrete rework list

For each BLOCKING finding, the precise action the design author must take:

**B-01**: Either (a) add a new wrapper script (e.g.,
`compare-legacy-vs-hybrid-workload.ps1`) under
`._design_docs/cache-handling-test-scripts/lib/` that calls
`New-AgenticChatPrompt` in a loop to produce 200 requests with the
documented 40/30/30 exact/near_prefix/new_branch distribution, aggregating
per-request JSONL output; OR (b) rewrite part-02 lines 78-87 to call
`New-AgenticChatPrompt` directly per request with the actual parameter
set. Update part-08 reuse table accordingly. Remove or qualify the "No
new generator script is needed" claim in part-02 line 65.

**B-02**: Add a "Phase 0.5: boot tokenize helper" step to part-03 driver
sequencing that boots the legacy binary briefly with `--cache-mode legacy`
for the sole purpose of providing the `/tokenize` endpoint to the
generator, then shuts down and proceeds to Phase 1. OR drop the
tokenize-endpoint dependency by pre-computing prompt sizes offline.
Whichever is chosen, the part-03 sequencing diagram must reflect it.

**B-03**: After B-01 resolution, the workload builder must emit per-request
fields matching part-04's metric list (`request_id`, `cache_class`,
`messages`, `max_tokens`, `temperature`, `seed`). The 40/30/30 distribution
must be applied across the 200-request batch, not per-prompt-class
iteration. Update part-02 lines 88-100 to reflect the actual JSONL output
shape.

**B-04**: Update part-08 lines 11-13 to reflect either the wrapper (option
a) or the rewritten invocation (option b). Do not claim "No modification"
to the Stage 20 lib if a wrapper is added.

**B-05**: Add R29-12 to part-09 with the same row format. Trigger:
implementation plan discovers documented driver invocation does not match
the lib API. Impact: blocking defect. Mitigation: rework per B-01/B-02/
B-03. Mitigation-before-approval: corrected invocation verified against
the actual lib by the implementation plan.

## 14. Next owner and next gate

This review returns REWORK. Next owner: Architect (design author) for
correction per the rework list above. After corrections, this independent
Architect review must be re-run (per user directive: "Don't consider
design as done. It should be re-run by architect according to your
inputs, reviewed etc.") on the corrected design before the design can be
passed to Manager design gate review.

## 15. Reviewer statement

This review was authored in a fresh Architect session on 2026-06-28. No
state from the prior Architect design session was loaded or relied on.
The 12 design files (entry + 11 parts) were treated as the only
authoritative source. The independent byte-level verification of
`._design_docs/cache-handling-test-scripts/lib/agentic-prompt-generator.ps1`
(308 LF, no BOM, no CR, function `New-AgenticChatPrompt` parameter set
read at lines 82-99) is the basis for B-01 through B-05.
