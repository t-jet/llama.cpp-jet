# Stage 21 implementation-plan review gate 01

Status: PASS
Date: 2026-06-18
Stage: 21 (Heavy Tier Mixed Workload Verification)
Reviewer: Architect (independent implementation-plan review, fresh session)
Scope: Implementation-plan review only. No code, script, test execution, or commit.
Subject: [../cache-handling-phase21-implementation.md](../cache-handling-phase21-implementation.md)

## Verdict

PASS. Stage 21 implementation plan is ready for Manager implementation-plan gate.

Finding counts:

| Severity | Count |
| --- | ---: |
| BLOCKING | 0 |
| non-blocking | 3 |
| INFO | 2 |

## Inputs reviewed

- [../document-index.md](../document-index.md)
- [../cache-handling-stage-tracker.md](../cache-handling-stage-tracker.md)
- [../cache-handling-phase21-design.md](../cache-handling-phase21-design.md)
- [../cache-handling-phase21-design/part-01-design-review-gate-01.md](../cache-handling-phase21-design/part-01-design-review-gate-01.md)
- [../cache-handling-phase21-design/part-02-manager-design-gate.md](../cache-handling-phase21-design/part-02-manager-design-gate.md)
- [../cache-handling-phase21-implementation.md](../cache-handling-phase21-implementation.md)
- [../.test_reports/stage20-heavy-20260618-01.md](../.test_reports/stage20-heavy-20260618-01.md)
- [../cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1](../cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1)
- [../cache-handling-test-plan/part-27-stage17-agentic-cache-reuse.md](../cache-handling-test-plan/part-27-stage17-agentic-cache-reuse.md)
- Current metric emission locations in `tools/server/server-context.cpp` and `tools/server/server-cache-hybrid.cpp`.

## Gate checklist

| Area | Verdict | Notes |
| --- | --- | --- |
| Approved design baseline | PASS | Plan cites design PASS, review PASS, Manager gate PASS, Stage 20 closure, Stage 20 heavy report, and Stage 17 TP-17-HV1/HV2 source rows. |
| D21-DESIGN-01 | PASS | HV-chat-feasible is binding and uses `-c 2048`, `-np 1`, `--cache-ram 2048`, 60 minutes or 30 requests. |
| D21-DESIGN-02 | PASS | HV-expanded is optional unless a later Manager decision changes the gate; optional capacity failure does not block closure. |
| D21-DESIGN-03 | PASS | F-21-DR-02, F-21-DR-03, and F-21-DR-04 are carried into planning constraints. |
| Ordered steps | PASS | Steps verify prerequisites, clean build, runner patch, HV1 execution, HV1 validation, HV2 comparison, optional expanded probe, durable report, and implementation-log update. |
| Affected files | PASS | Planned edits are scoped to the heavy runner, durable Stage 21 report, non-durable run output, and implementation-log updates. No production code, test code, fixture, CMake, or stress/longrun edits are planned. |
| Prototype edit plan | PASS | Plan treats `kickoff-stage20-heavy-v2.ps1` as a prototype and lists required edits for naming, template mode, redaction, request/response capture, summaries, comparisons, metrics, JSONL parsing, verdict logic, and caps. |
| Metric source map | PASS | Each required evidence item maps to public scrape, response JSON, JSONL, server log, launch args, or blocked status. Current code exposes the listed public metric families. |
| Evidence paths | PASS | Non-durable `._test_output/stage21-heavy-YYYYMMDD-NN/<run-id>/` and durable `._design_docs/.test_reports/stage21-heavy-YYYYMMDD-NN.md` paths match design. |
| Clean-build rules | PASS | Plan requires clean build of `llama-server.exe` and `test-cache-controller.exe`, records commands/exit codes/mtimes, forbids model-backed rows with preload skip, and stops on required command failure. |
| Risks | PASS | Risks match design risks and add practical mitigations for prototype prompts, metric absence, exact-repeat misses, and session caps. |
| Handoff | PASS | Next owner is Architect for this review, then Manager implementation-plan gate before Developer script edits or execution. |

## Findings

| ID | Severity | Finding | Required action |
| --- | --- | --- | --- |
| F-21-IPR-01 | non-blocking | Prototype script currently uses `Invoke-WebRequest ... -TimeoutSec 90` for chat requests, while Stage 21 design and plan execution require 120 seconds. The ordered steps say 120 seconds, but the prototype edit checklist does not name this exact edit. | During runner patching, change the per-request timeout to 120 seconds for HV-chat-feasible and record it in the dry-run launch/evidence summary. |
| F-21-IPR-02 | non-blocking | Affected-files table lists the runner, durable report, and non-durable output, while ordered step 8 also updates this implementation document after completed implementation steps. The scope is still correct, but the table should stay audit-complete when implementation starts. | When execution updates this implementation log, include the touched implementation part or entry file in the implementation evidence change list. |
| F-21-IPR-03 | non-blocking | `cache_cold_evictions_total` may remain zero or only have placeholder rows if the chat-feasible run does not create cold eviction pressure. The plan says `not-observed` is acceptable when no eviction pressure occurred, which matches the reduced profile, but the durable report must avoid treating that as a cold-eviction PASS signal. | In the Stage 21 report, classify no-eviction evidence as `not-observed` or `inconclusive` for eviction pressure, while still checking cold bytes, budget, skipped demotions, write failures, and server errors. |
| F-21-IPR-04 | INFO | The metric families in the plan are present in current code: restore misses, prompt evidence records, prefix candidates, cold bytes, cold budget bytes, cold demotion skips, and cold evictions. | No action. Keep the plan rule that absent public scrape rows are missing evidence, not zero values. |
| F-21-IPR-05 | INFO | The plan correctly treats Stage 20 heavy-v2 as a prototype. Current script still has Stage 20 naming, raw inline prompts, default `--chat-template-file`, Stage 16 raw log comparison, response-only JSON capture, no full request-class summary, and no Stage 21 verdict calculation. | No action before Manager gate. These are already covered by the required Stage 21 runner edits. |

## Decisions

- No blocking findings were found.
- Stage 21 implementation remains a script/report execution stage. This review approves no production code, unit test code, fixture, CMake, or stress/longrun script changes.
- HV-chat-feasible is enough for the binding Stage 21 plan under D21-DESIGN-01. HV-expanded remains optional under D21-DESIGN-02.
- Stage 20 PASS-INFRASTRUCTURE evidence is a prerequisite and comparison baseline only. It is not accepted as Stage 21 mixed workload coverage.
- Public metric gaps must be reported as missing or blocked evidence. The report must not substitute invented zeros.

## Required corrections

No blocking corrections.

Carry the three non-blocking findings into the implementation evidence checklist. They do not require plan rework before Manager implementation-plan gate.

## Handoff

Handoff state: ready for Manager implementation-plan gate.

Next owner: Manager. If Manager records implementation-plan gate PASS, Developer may patch `kickoff-stage20-heavy-v2.ps1`, run the clean build, execute HV-chat-feasible, and write the Stage 21 durable report. If Manager changes the binding profile, fixture, cap, or metric requirements, return this plan for re-review before execution.

This file uses LF line endings, plain ASCII status labels, and stays under the 300-line durable-doc cap.
