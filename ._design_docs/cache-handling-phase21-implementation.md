# Stage 21 implementation: heavy tier mixed workload verification

Status: implementation patch complete; ready for Architect implementation review
Date: 2026-06-18
Stage: 21 (Heavy Tier Mixed Workload Verification)
Author: Developer (implementation plan, fresh session)
Source design: [cache-handling-phase21-design.md](cache-handling-phase21-design.md)
Manager gate: D21-DESIGN-01
Current gate: implementation
Scope: implementation plan, gate record, runner patch, and dry-run evidence. Full heavy execution has not started.

## Contents

- [Part 1: Architect implementation-plan review gate 01](cache-handling-phase21-implementation/part-01-architect-implementation-plan-review-gate-01.md)
- [Part 2: Manager implementation-plan gate](cache-handling-phase21-implementation/part-02-manager-implementation-plan-gate.md)
- [Part 3: Runner patch implementation evidence](cache-handling-phase21-implementation/part-03-runner-patch-implementation-evidence.md)

## Gate status

| Gate | Status |
| --- | --- |
| Stage 21 design authoring | PASS (see [design entry](cache-handling-phase21-design.md)) |
| Stage 21 design review | PASS (see [design part 1](cache-handling-phase21-design/part-01-design-review-gate-01.md), 0 BLOCKING, 3 non-blocking, 1 INFO) |
| Stage 21 Manager design gate | PASS (see [design part 2](cache-handling-phase21-design/part-02-manager-design-gate.md), D21-DESIGN-01..03) |
| Stage 21 implementation planning | PASS (this file) |
| Stage 21 implementation-plan review | PASS (see [part 1](cache-handling-phase21-implementation/part-01-architect-implementation-plan-review-gate-01.md), 0 BLOCKING, 3 non-blocking, 2 INFO) |
| Stage 21 Manager implementation-plan gate | PASS (see [part 2](cache-handling-phase21-implementation/part-02-manager-implementation-plan-gate.md), D21-IMPLPLAN-01..03) |
| Stage 21 implementation | patch complete; pending Architect implementation review |
| Stage 21 QA execution | not started |

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
