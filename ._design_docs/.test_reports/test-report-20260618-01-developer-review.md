# Stage 21 test-results developer review

Status: FAIL (product bug: prompt-only vs full-slot save/restore mismatch)
Date: 2026-06-18
Stage: 21 (Heavy Tier Mixed Workload Verification)
Author: Developer (test-results review, fresh session)
Source: [stage21-heavy-20260618-01.md](stage21-heavy-20260618-01.md) (QA heavy execution report, FAIL); [cache-handling-phase21-design.md](../cache-handling-phase21-design.md); [cache-handling-phase21-implementation.md](../cache-handling-phase21-implementation.md); [cache-handling-phase21-implementation/part-08-architect-implementation-re-review-gate-02.md](../cache-handling-phase21-implementation/part-08-architect-implementation-re-review-gate-02.md); [stage20-heavy-20260618-01.md](stage20-heavy-20260618-01.md); [cache-handling-phase16-implementation/part-09-model-log-analysis.md](../cache-handling-phase16-implementation/part-09-model-log-analysis.md)
Manager gate: D21-DESIGN-01 (HV-chat-feasible binding), D21-IMPLPLAN-01, D21-IMPLREVIEW-02 pending
Current gate: Manager decision on bug-fix loop vs plan change
Scope: test-results review only; no production code, test code, runner, or implementation doc edits

## Verdict

FAIL. All three exact repeats returned `cache_n=0` and were classified as `unsafe_prefix_rejected` prefix candidates rather than exact matches. Root cause: cache saves full slot state (prompt + generated tokens = 89) but exact-repeat lookup expects exact token-count match (30 prompt tokens). The incoming 30-token repeat prompt finds the 89-token saved entry as a prefix candidate and rejects it per D17-03 Stage 17 policy. This is a product bug in save/restore coordination, not a structural fixture limitation or environment issue.

## Per-row classification

| Row ID | Classification | Evidence citation | Recommended action |
| --- | --- | --- | --- |
| TP-21-HV1 | FAIL | All 3 exact repeats got `cache_n=0` with `lookup_outcome=unsafe_prefix_rejected`. JSONL records 8, 9, 10 show prefix candidate found (89 tokens) and rejected per Stage 17 policy (task 30 tokens). Server logs confirm: `try_restore - found match: task 30 tokens, entry 89 tokens, prefix 30` then `prefix candidate rejected by Stage 17 policy`. Checksums match exactly between originals and repeats. | Developer bug-fix loop: change save to store prompt-only span OR change lookup to recognize full-slot entry with matching prompt prefix as exact match. Architect review required after fix. QA rerun required with corrected binary. |
| TP-21-HV2 | FAIL | Comparison structure is correct. Stage 16, Stage 20, and Stage 21 references exist. However, HV2 inherits HV1 FAIL verdict. Stage 21 did not improve upon Stage 16/20 `cache_n=0` baseline; it reproduced the same pattern for exact repeats. | No separate fix needed; HV2 will PASS when HV1 bug is fixed and exact repeats produce `cache_n > 0`. |
| R-21-F01 | product-bug | Exact repeats do not restore from cache despite identical `request_body_sha256` and `prompt_sha256`. Server logs show 7 entries saved (1829.276 MiB payload, 629 tokens) but exact repeats treated as prefix candidates and rejected. Lookup logic expects exact token-count match; saved entries have 89 tokens (prompt 30 + generated 59) while incoming repeats have 30 prompt tokens. | Fix save/restore coordination: either save prompt-only span (30 tokens) as cache entry, OR enhance lookup to recognize that a saved 89-token entry with a 30-token prompt prefix matching the incoming 30-token prompt is an exact hit, not a prefix candidate requiring rejection. Prefer prompt-only save if it matches the design intent. If full-slot save is required for other reasons, document why and adjust lookup to handle it. |
| R-21-F02 | non-blocking-observation | Server logs show 6 demotion completion warnings: `descriptor not found for payload_id 1, 2, 3, 4, 5, 6`. These occur during re-materialization attempts after slot release. However, metrics show `cache_cold_bytes=0` and cold path directory was empty after run, so cold storage was never actually used. Warnings indicate descriptor tracking is out of sync during re-materialization but do not block this run. | Investigate whether demotion descriptors are properly cleaned up during re-materialization or if this is a benign side effect of hot-only cache operation when cold pressure never materializes. Not a blocker for Stage 21 closure but should be understood before production use under real cold-pressure conditions. |
| R-21-I01 | metric-gap | Metrics report `cache_cold_budget_bytes=0` despite `--cache-cold-max-mib 4096` launch flag. Server.err.log line 11.509.015 confirms server recognized the flag: `cache: cold budget: 4096 MiB`. Metric emission does not reflect configured budget. | Verify metric initialization in hybrid cache code. The configured budget should be emitted even when cold storage is never used. If the metric is only set when cold writes occur, change it to emit configured budget at startup. Not a blocker for Stage 21 closure because cold storage was not required for this test, but metric accuracy matters for future heavy runs with real cold pressure. |
| R-21-I02 | same-as-F01 | Cache holds 7 entries but restore finds 0 exact matches. This is the same root cause as R-21-F01: saved entries have 89 tokens (full slot) while exact repeats search for 30-token (prompt-only) matches. | Same fix as R-21-F01. |
| Run-level | PASS | Environment, prerequisites, fixture, binary, launch flags, health wait, request caps, metrics scrape, and evidence files all correct. No environment issues. Runner, QA execution, and report format all meet contract. | No environment corrections needed. |

## Root cause analysis

The cache saves the full slot state (prompt + generated tokens) when a request completes. For the three exact-original requests (A, B, C), each had 30 prompt tokens and generated 60 tokens, resulting in 89 total tokens (prompt 30 + 1 checkpoint token + 58 completion tokens = 89, or similar). The cache entry stores this 89-token state.

When exact-repeat requests (A-repeat, B-repeat, C-repeat) arrive with the same 30-token prompts, the lookup attempts to find an exact match with 30 tokens. The saved entries have 89 tokens, so exact match fails. The lookup then checks for prefix candidates and finds that the saved 89-token entry has a 30-token prefix matching the incoming prompt. This qualifies as a prefix candidate.

Per D17-03 (Stage 17 policy), prefix restore is not implemented and prefix candidates must be rejected. The server correctly rejects the prefix candidate with reason `unsafe_prefix_rejected` and logs `prefix candidate rejected by Stage 17 policy (entry tokens: 89, task tokens: 30)`.

The design expectation was that exact repeats would find exact cache matches and produce `cache_n > 0`. This requires one of two fixes:

1. **Save prompt-only spans**: When saving a slot to cache, save only the prompt portion (e.g., the 30 tokens that were in the prompt, not the 89 tokens including generated output). This matches the incoming exact-repeat lookup because both are 30-token prompts. This is the simpler fix and likely matches the design intent for "exact repeat of the same prompt".

2. **Enhance exact-match lookup**: Change the lookup logic to recognize that a saved entry with token count N that contains a prefix of length M matching the incoming prompt of length M should be classified as an exact hit if the namespace, preparation_id, and token_span_checksum all match for the first M tokens. This is more complex and risks breaking other invariants, so it is not recommended unless prompt-only save is impossible.

The fix priority is to implement prompt-only save, verify it with unit tests, and rerun the heavy execution with the corrected binary.

## Recommended Manager decision text

D21-EXEC-01: Developer review classifies TP-21-HV1 as FAIL due to product bug (prompt-only vs full-slot save/restore mismatch). All exact repeats were treated as prefix candidates and rejected per D17-03. Root cause: cache saves full slot state (prompt + generated tokens = 89) but exact-repeat lookup searches for prompt-only match (30 tokens). Fix scope: change cache save to store prompt-only span OR change lookup to recognize full-slot entry with matching prompt prefix as exact match. Prefer prompt-only save. Developer will implement fix, add unit test coverage, submit to Architect review, and hand off to QA for rerun. Stage 21 remains open pending bug-fix loop completion.

## Bug-fix loop recommendation

1. Developer implements prompt-only save fix in `tools/server/server-cache-hybrid.cpp` (or wherever slot save logic resides). Identify the slot release path where `save_slot` is called and ensure only the prompt portion (tokens up to the first user message boundary or the preparation span before generation) is saved, not the full slot including generated tokens.

2. Developer adds unit test coverage for exact-repeat cache restore. Test must verify that:
   - A prompt with N tokens is saved to cache.
   - An exact repeat of the same N-token prompt finds the saved entry and restores it.
   - Response `cache_n` equals N (or N-1 if the design allows one boundary token to be excluded).
   - Lookup outcome is `exact_hit` or equivalent, not `unsafe_prefix_rejected`.

3. Developer submits fix and test evidence to Architect for review. Evidence must include:
   - Code change description with file paths and line numbers.
   - Unit test output showing exact-repeat restore working.
   - Local heavy-run dry-run or focused integration test confirming fix.

4. After Architect review PASS, Manager opens QA rerun gate. QA reruns TP-21-HV1 and TP-21-HV2 with corrected binary and new run ID.

5. If QA rerun PASS, Developer reviews rerun results, Manager records closure decision, and Stage 21 closes. If QA rerun FAIL with different evidence, Developer reviews and decides whether another iteration is needed or whether a structural blocker exists.

## Next owner

Manager for D21-EXEC-01 decision and bug-fix loop approval. If approved, Developer implements fix and proceeds to step 1 above.

## Files created or modified

Created:

- `d:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260618-01-developer-review.md` (this file)

No commits, no pushes, no production code edits, no test code edits, no runner edits, no implementation doc edits, no tracker edits, no document-index edits.

This file uses LF line endings and plain ASCII status labels.
