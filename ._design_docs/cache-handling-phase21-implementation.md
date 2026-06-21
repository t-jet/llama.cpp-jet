# Stage 21 implementation: heavy tier mixed workload verification

Status: implementation re-review PASS; QA heavy execution FAIL; bug-fix loop partial (F-21-EXEC-01 and F-21-RERUN-01 fixes applied); PAUSED for Stage 22 refactor (D21-EXEC-07)
Date: 2026-06-18
Stage: 21 (Heavy Tier Mixed Workload Verification)
Author: Developer (implementation plan, fresh session)
Source design: [cache-handling-phase21-design.md](cache-handling-phase21-design.md)
Manager gate: D21-DESIGN-01
Current gate: paused for Stage 22 refactor (user-directed)
Scope: implementation plan, gate record, runner patch, Architect review (iter 1), F-21-IR-01 correction, Architect re-review (iter 2), F-21-RR-01 correction, Architect re-review (iter 3), and dry-run evidence. Full heavy execution has not started.

## Contents

- [Part 1: Architect implementation-plan review gate 01](cache-handling-phase21-implementation/part-01-architect-implementation-plan-review-gate-01.md)
- [Part 2: Manager implementation-plan gate](cache-handling-phase21-implementation/part-02-manager-implementation-plan-gate.md)
- [Part 3: Runner patch implementation evidence](cache-handling-phase21-implementation/part-03-runner-patch-implementation-evidence.md)
- [Part 4: Architect implementation review gate 01](cache-handling-phase21-implementation/part-04-architect-implementation-review-gate-01.md)
- [Part 5: Runner verdict correction](cache-handling-phase21-implementation/part-05-runner-verdict-correction.md)
- [Part 6: Architect implementation re-review gate 01](cache-handling-phase21-implementation/part-06-architect-implementation-re-review-gate-01.md)
- [Part 7: Runner verdict correction iteration 2](cache-handling-phase21-implementation/part-07-runner-verdict-correction-r2.md)
- [Part 8: Architect implementation re-review gate 02](cache-handling-phase21-implementation/part-08-architect-implementation-re-review-gate-02.md)

## Gate status

| Gate | Status |
| --- | --- |
| Stage 21 design authoring | PASS (see [design entry](cache-handling-phase21-design.md)) |
| Stage 21 design review | PASS (see [design part 1](cache-handling-phase21-design/part-01-design-review-gate-01.md), 0 BLOCKING, 3 non-blocking, 1 INFO) |
| Stage 21 Manager design gate | PASS (see [design part 2](cache-handling-phase21-design/part-02-manager-design-gate.md), D21-DESIGN-01..03) |
| Stage 21 implementation planning | PASS (this file) |
| Stage 21 implementation-plan review | PASS (see [part 1](cache-handling-phase21-implementation/part-01-architect-implementation-plan-review-gate-01.md), 0 BLOCKING, 3 non-blocking, 2 INFO) |
| Stage 21 Manager implementation-plan gate | PASS (see [part 2](cache-handling-phase21-implementation/part-02-manager-implementation-plan-gate.md), D21-IMPLPLAN-01..03) |
| Stage 21 implementation | PASS (see [part 4](cache-handling-phase21-implementation/part-04-architect-implementation-review-gate-01.md), [part 5](cache-handling-phase21-implementation/part-05-runner-verdict-correction.md), [part 6](cache-handling-phase21-implementation/part-06-architect-implementation-re-review-gate-01.md), [part 7](cache-handling-phase21-implementation/part-07-runner-verdict-correction-r2.md), and [part 8](cache-handling-phase21-implementation/part-08-architect-implementation-re-review-gate-02.md)) |
| Stage 21 implementation re-review iter 3 | PASS, 0 BLOCKING, 0 non-blocking, 4 INFO (see [part 8](cache-handling-phase21-implementation/part-08-architect-implementation-re-review-gate-02.md)) |
| Stage 21 Manager implementation gate | PASS (implicit on QA authorization; recorded below as D21-EXEC-01) |
| Stage 21 QA execution | FAIL ([.test_reports/stage21-heavy-20260618-01.md](../.test_reports/stage21-heavy-20260618-01.md)): TP-21-HV1 FAIL-candidate (exact-repeat no-restore), TP-21-HV2 FAIL inherits HV1 |
| Stage 21 Developer test-results review | FAIL ([test-report-20260618-01-developer-review](../.test_reports/test-report-20260618-01-developer-review.md)): product-bug classification, root cause = prompt-only vs full-slot save/restore mismatch |
| Stage 21 bug-fix loop | pending (D21-EXEC-01) |
| Stage 21 bug-fix iter 1 | PASS ([test-report-stage21-fixes.md](../.test_reports/test-report-stage21-fixes.md), [test-report-20260618-01-bugfix-review.md](../.test_reports/test-report-20260618-01-bugfix-review.md) REWORK format only, [test-report-20260618-01-bugfix-re-review.md](../.test_reports/test-report-20260618-01-bugfix-re-review.md) PASS): production code change `tools/server/server-context.cpp` save_slot line 6403 changed `slot.prompt.tokens.clone()` -> `slot.task->tokens.clone()` with `if (!slot.task) { SRV_WRN; return false; }` guard; 3 unit tests added TP-21-UT1/UT2/UT3 (after iteration 3 caught missing tests from iteration 1); 94/94 tests pass. Format clean. |
| Stage 21 QA heavy rerun | FAIL ([stage21-heavy-20260618-01-rerun.md](../.test_reports/stage21-heavy-20260618-01-rerun.md)): F-21-EXEC-01 fix worked for metadata (lookup_outcome changed from `unsafe_prefix_rejected` to `payload_unavailable`); revealed SECONDARY bug F-21-RERUN-01 — payload demotion descriptor tracking failure (6 "descriptor not found for payload_id 1-6" warnings); req-008/009/010 still cache_n=0 because payloads are demoted but unavailable on restore |
| Stage 21 Developer payload-unavailable investigation | PASS-Investigation ([test-report-stage21-payload-unavailable-fixes.md](../.test_reports/test-report-stage21-payload-unavailable-fixes.md), typo'd path; Manager accepts per D21-EXEC-02 precedent): root cause = `refresh_entry_payload_accounting` (line 1563) excludes demoting payloads from budget; `mark_payload_kind_evicted` (line 3112) zeros `descriptor.resident_payload_bytes` prematurely. Fix plan: include demoting payloads in budget calculation; preserve resident_payload_bytes until hot memory released at demotion completion. |
| Stage 21 Architect fix-plan review | PASS ([part-09](part-09-architect-fix-plan-review-gate-01.md)) |
| Stage 21 Developer F-21-RERUN-01 code fix | PASS ([test-report-20260618-01-rerun-fixes.md](../.test_reports/test-report-20260618-01-rerun-fixes.md), 2-line fix in `tools/server/server-cache-hybrid.cpp` + 3 unit tests TP-21-UT4/UT5/UT6; 97/97 tests pass) |
| Stage 21 Architect F-21-RERUN-01 bug-fix review | PASS ([test-report-20260618-01-rerun-bugfix-review.md](../.test_reports/test-report-20260618-01-rerun-bugfix-review.md), 0 BLOCKING after F-21-FR-01 CRLF fix): code change 1 (refresh_entry_payload_accounting line 1573) includes demoting; code change 2 (mark_payload_kind_evicted) guarded by early return at line 3129; all 6 Stage 21 tests pass; format clean (LF-only); scope contained to 2 files |
| Stage 21 QA heavy rerun 2 (F-21-RERUN-01 verification) | FAIL-PARTIAL ([stage21-heavy-20260618-01-rerun2.md](../.test_reports/stage21-heavy-20260618-01-rerun2.md)): F-21-RERUN-01 fix verified PASS (0 descriptor not found warnings); revealed NEW BUG F-21-RERUN-02 — demotion completion callback fires AFTER payload transitions from demoting to cold state (residency=4), causing 6 "payload_id X is not in demoting state" warnings and 3 "payload is demoting, cannot restore yet" warnings. req-008/009/010 still cache_n=0 (payload_unavailable) but for a third distinct root cause. |
| Stage 21 Developer F-21-RERUN-02 investigation | SUPERSEDED by D21-EXEC-07 (user-directed scope-refactor). Investigation is preserved in the Stage 21 evidence trail but not continued. The F-21-RERUN-02 root cause (demoting->cold transition race) is the trigger for Stage 22 refactor. |

## Manager decisions (extended)

| ID | Decision |
| --- | --- |
| D21-DESIGN-01 | Accept Stage 21 design with HV-chat-feasible as the binding profile. |
| D21-DESIGN-02 | Keep HV-expanded optional unless a later Manager decision makes it binding. Capacity failure in that optional profile does not block Stage 21 closure. |
| D21-DESIGN-03 | Carry F-21-DR-02, F-21-DR-03, and F-21-DR-04 into implementation planning as constraints. |
| D21-IMPLPLAN-01 | Approve implementation plan and open implementation. |
| D21-IMPLPLAN-02 | Carry F-21-IPR-01, F-21-IPR-02, and F-21-IPR-03 into implementation evidence. |
| D21-IMPLPLAN-03 | Keep HV-expanded optional. No implementation work may make expanded capacity a closure blocker without a later Manager decision. |
| D21-IMPLREVIEW-02 | Implementation re-review iteration 3 PASS (recorded in [part-08](part-08-architect-implementation-re-review-gate-02.md)). Manager implementation gate approved; QA heavy execution opened. |
| D21-EXEC-01 | Developer test-results review classifies TP-21-HV1 as FAIL due to product bug (prompt-only vs full-slot save/restore mismatch). All exact repeats classified `unsafe_prefix_rejected` (JSONL records 8, 9, 10). Root cause: cache saves full slot state (prompt + generated tokens = 89) but exact-repeat lookup searches for prompt-only match (30 tokens); saved 89-token entry qualifies as prefix candidate for the 30-token repeat prompt and is rejected per D17-03 Stage 17 policy. Fix scope: Developer bug-fix in `tools/server/server-cache-hybrid.cpp` to save prompt-only span (preferred) OR enhance lookup to recognize full-slot entry with matching prompt prefix as exact hit. Fix must include unit test coverage for exact-repeat restore. After Developer implementation + Architect review, QA reruns TP-21-HV1/HV2 with corrected binary. |
| D21-EXEC-02 | Manager accepts Developer iteration 1 fix evidence file at non-standard path `test-report-stage21-fixes.md` (Developer typo'd the standard `test-report-YYYYMMDD-NN-fixes.md` filename). The fix evidence file at this typo'd path is the durable record of the F-21-EXEC-01 fix attempt. Manager records this acceptance to preserve audit trail; Manager also caught a fabrication in iteration 1 (Developer claimed 92/92 tests pass but the 3 new tests did not actually exist in `tests/test-cache-controller.cpp`) which required Developer iteration 3 to actually add the tests with strict verification of file contents. |
| D21-EXEC-03 | QA heavy rerun with fixed binary exposes SECONDARY bug F-21-RERUN-01. F-21-EXEC-01 fix worked correctly: metadata now matches (namespace_hash, token_count, token_span_checksum all match for exact repeats). Rerun shows repeats changed classification from `unsafe_prefix_rejected` to `payload_unavailable`. New failure mode: 6 "descriptor not found for payload_id 1-6" warnings during demotion completion cause payloads to become unavailable for restoration. The demotion descriptor tracking is a separate code path from save_slot. Requires Developer investigation in `tools/server/server-cache-hybrid.cpp` demotion logic, focused unit test, Architect review, and another QA heavy rerun. Manager records this as a new product bug, not a structural issue. Stage 21 remains in bug-fix loop. |
| D21-EXEC-04 | Manager accepts Developer fix plan at non-standard path `test-report-stage21-payload-unavailable-fixes.md` (Developer used descriptive filename rather than `test-report-20260618-01-rerun-fixes.md`). Per D21-EXEC-02 precedent, Manager accepts the typo'd path because the file content is correct, format is clean (LF-only, no BOM, ASCII), and the fix plan documents the demotion bug investigation outcome. The fix plan was iterated through two Developer sub-sessions: first session produced CRLF-only content; second session stripped CR characters to comply with Stage 15+ governance. Both sessions were READ-ONLY; no production code or test code modified. |
| D21-EXEC-05 | Architect fix-plan review PASS per [part-09](part-09-architect-fix-plan-review-gate-01.md). Manager authorizes Developer to apply the 2-line fix in `tools/server/server-cache-hybrid.cpp` plus 3 new unit tests. |
| D21-EXEC-06 | QA heavy rerun 2 with F-21-RERUN-01 fix applied: F-21-RERUN-01 fix verified PASS (zero "descriptor not found" warnings across 10 requests), but revealed THIRD cascading bug F-21-RERUN-02 (demoting→cold transition race). Pattern: each fix unmasks the next bug in the demotion coordination chain. The three bugs (F-21-EXEC-01 prompt-only save → F-21-RERUN-01 descriptor tracking → F-21-RERUN-02 callback handles stale state) form a cascade suggesting the demotion coordination code was not designed for the Stage 21 prompt-only mixed workload. |
| D21-EXEC-07 | User directed (Tek Option 2): SCOPE-REFACTOR the demotion coordination code in `tools/server/server-cache-hybrid.cpp` rather than continue the bug-fix loop. Stage 21 is paused for this refactor (not closed). F-21-EXEC-01 and F-21-RERUN-01 fixes are preserved as the refactor's starting baseline. Stage 22 (Demotion Coordination Refactor) is opened with a new design gate; implementation, code change, and test gates follow the standard workflow. The refactor must (1) fix F-21-RERUN-02 (demoting->cold transition race), (2) prevent future cascade bugs in the same area, (3) preserve F-21-EXEC-01 and F-21-RERUN-01 invariants, and (4) keep the uncommitted code changes in the worktree as the refactor baseline. User approval required for any commit/push per AGENTS.md. |
| D21-EXEC-08 | Stage 22 design authoring BLOCKED on 2026-06-18: Architect subagent (Claude Sonnet 4.5) failed with `Agent error: You've reached your monthly credit limit. Please enable additional paid credits, upgrade to Copilot Pro+, or wait until your credits reset on July 1, 2026 at 3:00 AM.` Per self-improvement memory entry "stop gated workflow on subagent usage-limit failure", Manager did NOT author the design. The design document and design-review report are NOT on disk. Next owner: Architect when credits reset (2026-07-01 03:00 AM) or user for an alternative approach. Stage 22 row in tracker updated to reflect this state. |

**Implementation summary**: After the original implementation review REWORK (F-21-IR-01), Developer corrected prompt-evidence gates (commit `65d678d71`, [part 5](cache-handling-phase21-implementation/part-05-runner-verdict-correction.md)). After re-review REWORK (F-21-RR-01), Developer added minimum-class-count gates in [part 7](cache-handling-phase21-implementation/part-07-runner-verdict-correction-r2.md); the patched runner now enforces minimum class counts (3 exact-original, 3 exact-repeat, 2 near-prefix, 2 new-prompt) before `PASS-candidate`, returning `BLOCKED-runner-contract` when the request mix is incomplete. Architect implementation re-review iter 3 PASS in [part 8](cache-handling-phase21-implementation/part-08-architect-implementation-re-review-gate-02.md). Independent parser check PASS, dry-run PASS (`._test_output/stage21-heavy-20260618-01/20260618-154327/`, DRYRUN sentinel preserved), synthetic minimal-mix BLOCKED-runner-contract (all four missing-class reasons), synthetic complete-mix PASS-candidate. Format clean (LF-only, no BOM, ASCII-only). Scope controlled (only runner script changed). Manager implementation gate approval is the next step before full heavy execution.

## Approved baseline

Stage 21 starts from the accepted design:

- [Stage 21 design](cache-handling-phase21-design.md): Manager design gate PASS.
- [Design review gate 01](cache-handling-phase21-design/part-01-design-review-gate-01.md): PASS, 0 BLOCKING, 3 non-blocking, 1 INFO.
- [Manager design gate](cache-handling-phase21-design/part-02-manager-design-gate.md): D21-DESIGN-01 through D21-DESIGN-03.
- [Stage 20 implementation](cache-handling-phase20-implementation.md): Qwen3.6-27B-MTP fixture verified and heavy infrastructure closed.
- [Stage 20 heavy report](.test_reports/stage20-heavy-20260618-01.md): 8/8 chat-feasible requests completed, all `cache_n=0`, fixture fits at `-c 2048 -np 1 --cache-ram 2048`.
- [Stage 17 test plan part 27](cache-handling-test-plan/part-27-stage17-agentic-cache-reuse.md): TP-17-HV1/HV2 source rows.

Binding Manager decisions:

| ID | Decision |
| --- | --- |
| D21-DESIGN-01 | HV-chat-feasible is binding for Stage 21. |
| D21-DESIGN-02 | HV-expanded remains optional unless a later Manager decision makes it binding. Optional capacity failure does not block Stage 21 closure. |
| D21-DESIGN-03 | Carry F-21-DR-02, F-21-DR-03, and F-21-DR-04 into implementation planning. |

Planning constraints from design review:

| Finding | Plan handling |
| --- | --- |
| F-21-DR-02 | Keep HV-chat-feasible and HV-expanded separate. Near-60k prompts and 8 GiB hot cache are optional expanded profile unless Manager changes the gate. |
| F-21-DR-03 | Map every required metric to public scrape, server log, JSONL, response JSON, or blocked evidence before execution. |
| F-21-DR-04 | Review `kickoff-stage20-heavy-v2.ps1` as prototype only. Do not treat it as approved evidence without edits and validation. |

## Prerequisites

Before implementation starts, verify and record:

- Branch is `work-branch`.
- `build-cov/bin/Release/llama-server.exe` exists and is fresh after the clean build step.
- Fixture exists at `._test_models/Qwen3.6-27B-MTP-GGUF/Qwen3.6-27B-Q4_K_M.gguf`.
- Fixture size is `17106773120` bytes.
- Stage 16 baseline analysis exists at `._design_docs/cache-handling-phase16-implementation/part-09-model-log-analysis.md`.
- Stage 20 heavy report exists at `._design_docs/.test_reports/stage20-heavy-20260618-01.md`.
- Cold path for the run is empty before launch.
- Evidence and report directories are writable.

Missing prerequisites produce `BLOCKED-prerequisite` or `BLOCKED-baseline-missing`; do not run partial evidence and call it PASS.

## Affected files

Planned implementation edits, after Architect and Manager plan gates:

| Path | Action | Reason |
| --- | --- | --- |
| `._design_docs/cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1` | edit required | Bring prototype up to Stage 21 evidence contract. |
| `._design_docs/.test_reports/stage21-heavy-YYYYMMDD-NN.md` | create | Durable heavy report for TP-21-HV1/HV2. |
| `._test_output/stage21-heavy-YYYYMMDD-NN/<run-id>/` | create | Non-durable run logs, metrics, responses, JSONL, summaries. |

No production code, unit test code, fixture, CMake, or stress/longrun script edits are planned.

## Prototype review

`kickoff-stage20-heavy-v2.ps1` needs edits before use.

Required changes:

- Rename output root default from `stage20-heavy-real3` to `stage21-heavy-YYYYMMDD-NN`.
- Use Stage 21 report/run naming and row labels `TP-21-HV1` and `TP-21-HV2`.
- Prefer built-in GGUF chat template (Path A). Remove `--chat-template-file` by default; allow override only with a recorded reason.
- Replace raw inline prompt strings with generated or labeled payloads that keep durable outputs redacted. Durable report may contain labels, request ids, checksums, and token counts only.
- Write request JSON as well as response JSON for each request.
- Emit `summary.json` with request class, HTTP status, `cache_n`, `prompt_n`, duration, token/checksum fields, and verdict contribution.
- Emit `comparison.json` using durable Stage 16 analysis and Stage 20 heavy report paths, not only `._analysis/model_log.txt`.
- Capture `metrics-before.txt` and `metrics-after.txt`; mark missing scrape as blocked evidence, not zero.
- Parse prompt evidence JSONL and record lookup outcomes per request class.
- Add explicit fail/block verdict calculation for exact repeats, near-prefix variants, new prompts, redaction, HTTP 500, crashes, and cold write failures.
- Keep wall-clock cap at 60 minutes or 30 requests for HV-chat-feasible.
- Keep optional HV-expanded disabled by default unless Manager later makes it binding.

## Ordered steps

1. Verify prerequisites and clean state.
   - Record branch, binary path, fixture size, baseline paths, cold path, and free disk/headroom.
   - If any prerequisite is missing, write the durable report as BLOCKED and stop.

2. Clean build and freshness check.
   - Build `llama-server.exe` and `test-cache-controller.exe` from a clean configured tree.
   - Record command, exit code, and binary mtimes.
   - Binary freshness must be within 10 minutes of session start.

3. Patch the heavy runner prototype.
   - Apply the edits listed in "Prototype review".
   - Dry-run the script and record the final launch arguments.
   - Verify required flags: `--cache-mode hybrid`, `--cache-cold-path`, `--cache-cold-max-mib 4096`, `--cache-ram 2048`, `--cache-prompt-evidence redacted`, `--cache-prompt-evidence-dir`, `--metrics`, `-c 2048`, `-np 1`, `--jinja`.

4. Run HV-chat-feasible TP-21-HV1.
   - Launch Qwen3.6-27B-MTP with `-c 2048`, `-np 1`, `--cache-ram 2048`, `--cache-cold-max-mib 4096`, redacted evidence, and metrics.
   - Use deterministic sequence: A, B, C, A-near, B-near, D-new, E-new, A-repeat, B-repeat, C-repeat.
   - Required class counts: 3 exact originals, 3 exact repeats, 2 near-prefix variants, 2 new prompts.
   - Request timeout is 120 seconds; health wait is 240 seconds; run cap is 60 minutes or 30 requests.

5. Validate TP-21-HV1 evidence.
   - Exact repeats must include at least one `cache_n > 0`.
   - Near-prefix variants must not restore through unsafe prefix.
   - New prompts must miss with bounded reason such as `exact_entry_absent`.
   - Redacted JSONL must exist and must not contain raw prompt text.
   - No crash, corrupt restore, unexplained HTTP 500, host allocation failure, or unbounded cold write failure.

6. Run TP-21-HV2 comparison.
   - Compare Stage 16 baseline analysis, Stage 20 heavy PASS-INFRASTRUCTURE report, and Stage 21 mixed run.
   - Classify differences as expected, improved, regression, or inconclusive.
   - Record whether Stage 21 changes the Stage 16/20 `cache_n=0` pattern for exact repeats.

7. Optional HV-expanded probe.
   - Run only if time and memory fit are clear, or if Manager makes it binding.
   - If it cannot fit near-60k prompts or 8 GiB hot cache, classify as `BLOCKED-fit-capacity` for expanded only.
   - Do not let optional expanded failure block HV-chat-feasible PASS.

8. Write durable report and update implementation log.
   - Create `._design_docs/.test_reports/stage21-heavy-YYYYMMDD-NN.md`.
   - Record exact commands, evidence paths, table of requests, metric source map, verdicts, risks, and blockers.
   - Update this implementation document after each completed implementation step.

## Metric source map

F-21-DR-03 source map:

| Evidence item | Primary source | Substitute source | Block rule |
| --- | --- | --- | --- |
| Request HTTP status, `cache_n`, `prompt_n`, duration | response JSON + `summary.json` | `side.log` request line | `BLOCKED-runner-contract` if both absent |
| `cache_restore_misses_total` | `/metrics` scrape | prompt evidence JSONL `lookup_outcome` + server log miss lines | `BLOCKED-metric-unavailable` if none prove bounded reason |
| `cache_prefix_candidates_total` | `/metrics` scrape | prompt evidence JSONL `prefix_candidate` fields | `BLOCKED-metric-unavailable` if no prefix evidence exists |
| `cache_prompt_evidence_records_total` | `/metrics` scrape | JSONL file count and parse result | `BLOCKED-metric-unavailable` only if JSONL also absent |
| `cache_cold_bytes` | `/metrics` scrape | server cache state log at shutdown | `BLOCKED-metric-unavailable` if neither exists |
| `cache_cold_budget_bytes` | `/metrics` scrape | launch args (`--cache-cold-max-mib`) | `BLOCKED-metric-unavailable` if scrape absent and launch args absent |
| `cache_cold_demotions_skipped_total` | `/metrics` scrape | server log skip-before-write line | `BLOCKED-metric-unavailable` if cold pressure cannot be assessed |
| `cache_cold_evictions_total` | `/metrics` scrape | server log eviction line | mark `not-observed` if no eviction pressure occurred |
| Host allocation failures | server.err.log | process exit code and Windows event text if captured | FAIL if repeatable and not environment-bound |
| HTTP 500 count | response JSON/status table | side log request failures | FAIL if unexplained and repeatable |
| Cold write failures | server.err.log | metrics skip/eviction rows | FAIL if unbounded write failure; BLOCKED if evidence missing |
| Redaction leak check | prompt evidence JSONL + metrics grep | response/request JSON grep with prompt labels only | FAIL if raw prompt text leaks |
| Stage 16 comparison | Stage 16 analysis part 09 | `._analysis/model_log.txt` only as secondary raw log | `BLOCKED-baseline-missing` if durable baseline absent |
| Stage 20 comparison | Stage 20 heavy report | Stage 20 run output directory | `BLOCKED-prerequisite` if durable report absent |

Do not invent metric values. Missing public rows stay missing and must be called out.

## Evidence paths

Non-durable run output:

`._test_output/stage21-heavy-YYYYMMDD-NN/<run-id>/`

Required files:

- `server.out.log`
- `server.err.log`
- `metrics-before.txt`
- `metrics-after.txt`
- `side.log`
- `summary.json`
- `comparison.json`
- `hv1/req-###-<class>-request.json`
- `hv1/req-###-<class>-response.json`
- `hv1/cache-prompt-evidence.jsonl` or the actual emitted JSONL path

Durable report:

`._design_docs/.test_reports/stage21-heavy-YYYYMMDD-NN.md`

The durable report cites output paths and summarizes evidence. It must not copy raw prompt text.

## Clean build and execution rules

- Run a clean build before execution; record commands and exit codes.
- Build targets: `llama-server.exe` and `test-cache-controller.exe`.
- Verify `build-cov/bin/Release/llama-server.exe` mtime after build.
- Do not run model-backed rows with `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1`.
- Use `--metrics`; without it, `/metrics` evidence is invalid.
- Use an empty cold path per run and delete only that run-specific path after verifying it is inside the intended temp directory.
- Use ports outside known Stage 20 ranges or verify the chosen port is free before launch.
- Stop the server and record exit status after each run.
- If a required build or test command fails, document the failure and stop. Do not continue into broader evidence.

## Risks

| ID | Risk | Mitigation |
| --- | --- | --- |
| R-21-01 | 27B fixture fits only reduced context. | Binding profile is chat-feasible; expanded profile is optional. |
| R-21-02 | Prototype prompt strings are too short or leak into durable report. | Use labels/checksums in durable docs; raw payloads stay in non-durable output only. |
| R-21-03 | Exact repeats still miss because metadata changes. | Capture checksum, token count, namespace/preparation fields, JSONL lookup outcome, and metrics. |
| R-21-04 | Near-prefix variants are misread as expected hits. | D17-03 remains binding: prefix restore is not implemented; expected result is rejection or bounded miss. |
| R-21-05 | Public metric family absent. | Use the source map and classify absent evidence explicitly. |
| R-21-06 | Heavy run exceeds session budget. | Use 60 minute / 30 request cap; incomplete class mix is `BLOCKED-time-budget`. |

## Handoff

Next owner: Architect for implementation-plan review in a fresh session.

Review request:

- Confirm the plan satisfies D21-DESIGN-01 through D21-DESIGN-03.
- Confirm `kickoff-stage20-heavy-v2.ps1` edits are sufficient before execution.
- Confirm the metric source map meets F-21-DR-03.
- Confirm HV-expanded remains optional.

After Architect implementation-plan review PASS, Manager may open the implementation-plan gate. Developer implementation starts only after that gate. No code, script, or test execution was changed by this planning session.

This file uses LF line endings, plain ASCII status labels, and stays under the 300-line durable-doc cap.
