# Stage 21 design: heavy tier mixed workload verification

Status: Manager design gate PASS; implementation planning open
Date: 2026-06-18
Stage: 21 (Heavy Tier Mixed Workload Verification)
Author: Architect (design, fresh session)
Source: [Stage 17 test plan part 27](cache-handling-test-plan/part-27-stage17-agentic-cache-reuse.md) TP-17-HV1/HV2; [Stage 20 implementation](cache-handling-phase20-implementation.md); [Stage 20 heavy report](.test_reports/stage20-heavy-20260618-01.md)
Scope: Stage 21 design only. No code, script, or test execution changes.
Current gate: implementation planning

## Contents

- [Part 1: design review gate 01](cache-handling-phase21-design/part-01-design-review-gate-01.md)
- [Part 2: Manager design gate](cache-handling-phase21-design/part-02-manager-design-gate.md)

## Gate status

| Gate | Status |
| --- | --- |
| Stage 21 design authoring | PASS (this file) |
| Stage 21 design review | PASS (see [part 1](cache-handling-phase21-design/part-01-design-review-gate-01.md), 0 BLOCKING, 3 non-blocking, 1 INFO) |
| Stage 21 Manager design gate | PASS (see [part 2](cache-handling-phase21-design/part-02-manager-design-gate.md), D21-DESIGN-01) |
| Stage 21 implementation planning | not started |
| Stage 21 implementation | not started |
| Stage 21 QA execution | not started |

## Scope

Stage 21 converts the Stage 20 heavy-tier infrastructure pass into full
mixed workload coverage for TP-17-HV1 and TP-17-HV2.

In scope:

- Qwen3.6-27B-MTP heavy run on the Stage 20 verified fixture.
- A mixed prompt stream with exact repeats, near-prefix variants, and new
  prompts in one run.
- Restore, miss, prefix-rejection, cold-budget, prompt-evidence, and
  stability evidence from live `llama-server`.
- Comparison to the Stage 16 model-log baseline and Stage 20 heavy report.
- A durable heavy report under `._design_docs/.test_reports/`.

Out of scope:

- Production code changes.
- Script changes during design authoring.
- Prefix restore implementation. Prefix candidates remain rejected as
  `unsafe_prefix_rejected` per D17-03.
- New CLI flags, metrics, public endpoints, or model fixtures.
- Full Stage 17 unit, integration, synthetic, or stress-longrun reruns.

## Prerequisites

Required before Stage 21 implementation planning starts:

- Stage 17 is closed and TP-17-HV1/HV2 are the only rows reopened here.
- Stage 20 is closed with Qwen3.6-27B-MTP fixture verification complete.
- Fixture path exists:
  `._test_models/Qwen3.6-27B-MTP-GGUF/Qwen3.6-27B-Q4_K_M.gguf`.
- Fixture size remains `17106773120` bytes at execution time.
- `build-cov/bin/Release/llama-server.exe` exists and is fresh enough for
  the test session report.
- Baseline analysis exists at
  `._design_docs/cache-handling-phase16-implementation/part-09-model-log-analysis.md`.
- Stage 20 heavy report exists at
  `._design_docs/.test_reports/stage20-heavy-20260618-01.md`.
- The heavy runner prototype may be used as input:
  `._design_docs/cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1`.
  The implementation plan must review it before use because Stage 20 did
  not approve it as final evidence.

If any prerequisite is missing, the stage stays `BLOCKED-prerequisite` and
does not claim TP-17-HV1/HV2 coverage.

## Fixture constraints

The primary fixture is Qwen3.6-27B-MTP, not a 4B substitute.

Minimum launch constraints inherited from Stage 20:

- Windows host on `work-branch`.
- `-np 1`.
- `-c 2048` for the chat-feasible profile unless the implementation plan
  proves a larger context fits.
- `--cache-ram 2048` minimum working configuration from Stage 20; larger
  values may be used only when the evidence records memory headroom.
- `--cache-mode hybrid`.
- `--cache-cold-path <empty test directory>`.
- `--cache-cold-max-mib 4096` default for the bounded cold path.
- `--cache-prompt-evidence redacted`.
- `--cache-prompt-evidence-dir <row evidence directory>`.
- `--metrics`.
- Built-in GGUF chat template is preferred because Stage 20 Path A worked.
  If `--chat-template-file` is used instead, the report must state why.

The Stage 17 heavy target mentions near-60k prompts and an 8 GiB hot cache.
Stage 20 proved the current host with 27B at `-c 2048`, `-np 1`,
`--cache-ram 2048`. Stage 21 may still PASS if it covers the mixed workload
at the proven host limits and records the context/cache limits clearly. A
near-60k or 8 GiB run is an expanded profile. If the Manager requires that
expanded profile and the host cannot fit it, the row is
`BLOCKED-fit-capacity`, not FAIL.

## Workload design

The implementation plan must define one deterministic request sequence with
at least these prompt classes:

| Class | Minimum count | Expected cache behavior |
| --- | ---: | --- |
| exact original | 3 | first occurrence misses and saves |
| exact repeat | 3 | later identical prompts produce `cache_n > 0` when exact restore is available |
| near-prefix variant | 2 | must not restore through unsafe prefix; record bounded miss and prefix rejection evidence |
| new prompt | 2 | misses with bounded reason such as `exact_entry_absent` |

The sequence must preserve deterministic ordering. Example shape:

```text
A, B, C, A-near, B-near, D-new, E-new, A-repeat, B-repeat, C-repeat
```

Prompt payload constraints:

- Use `/v1/chat/completions` with chat `messages`, not `/completion`.
- Use stable `temperature=0` and fixed seed where supported.
- Keep prompts short enough for the selected `-c` value in the
  chat-feasible profile.
- If an expanded profile is attempted, generate long prompts using the
  Stage 20 agentic generator and record actual token counts from `/tokenize`
  or response timings.
- Do not include raw prompt text in durable reports when redacted mode is
  selected. Use labels, request ids, checksums, and token counts.

## Execution caps

Stage 21 has two profiles:

| Profile | Cap | Required for design PASS? | Purpose |
| --- | ---: | --- | --- |
| HV-chat-feasible | 60 minutes or 30 requests, whichever comes first | Yes | Full mixed workload on proven 27B host limits |
| HV-expanded | 4 hours or 60 requests, whichever comes first | No, unless Manager makes it binding | Near-60k or larger-cache attempt |

Per-request timeout is 120 seconds for chat-feasible prompts. The expanded
profile may raise per-request timeout to 900 seconds if the report records
expected token count and prompt throughput. Startup health wait cap is
240 seconds.

A cap exit is `PASS-cap-complete` only when all required prompt classes have
executed and evidence is complete. If the cap expires before the required
class mix finishes, use `BLOCKED-time-budget`.

## Metrics and evidence

Each execution creates one run directory under:

`._test_output/stage21-heavy-YYYYMMDD-NN/<run-id>/`

Required files:

- `server.out.log`
- `server.err.log`
- `metrics-before.txt`
- `metrics-after.txt`
- per-request response JSON files
- prompt evidence JSONL from redacted mode
- `summary.json` with request class, HTTP status, `cache_n`, `prompt_n`,
  duration, and verdict contribution
- `comparison.json` for Stage 16 and Stage 20 comparison

Durable report:

`._design_docs/.test_reports/stage21-heavy-YYYYMMDD-NN.md`

Required evidence fields:

- fixture path, size, launch flags, port, cold path, cache RAM, cold budget,
  context size, `np`, template mode
- request table with class, HTTP status, `cache_n`, `prompt_n`, duration
- exact-repeat hit count and total restored tokens
- near-prefix bounded miss reason and prefix-candidate result
- new-prompt miss reason
- `cache_restore_misses_total` lines from metrics
- `cache_prefix_candidates_total` lines when exposed
- `cache_prompt_evidence_records_total` lines when exposed
- `cache_cold_bytes`, `cache_cold_budget_bytes`,
  `cache_cold_demotions_skipped_total`, and `cache_cold_evictions_total`
  lines when exposed
- host allocation failures, HTTP 500 count, cold write failure count
- comparison to Stage 16 baseline and Stage 20 PASS-INFRASTRUCTURE run

If a required metric family is not exposed publicly, the report must state
`BLOCKED-metric-unavailable` for that evidence item and use server logs or
JSONL as substitute evidence. Do not invent metric values.

## Pass, fail, and block criteria

TP-21-HV1 PASS requires:

- Qwen3.6-27B-MTP fixture launches and serves the mixed workload.
- All required prompt classes execute within the HV-chat-feasible cap.
- Exact repeats include at least one response with `cache_n > 0`.
- Near-prefix variants do not restore through unsafe prefix.
- New prompts miss with bounded reasons.
- Redacted prompt evidence is written and contains no raw prompt text.
- No crash, no corrupt restore, and no unexplained HTTP 500.
- Cold budget behavior is bounded: no unhandled cold write failure.

TP-21-HV2 PASS requires:

- HV1 evidence exists.
- Comparison table covers Stage 16 baseline, Stage 20 heavy report, and
  Stage 21 mixed run.
- Differences are classified as expected, improved, regression, or
  inconclusive.
- No new product bug is introduced by the mixed workload.

FAIL criteria:

- Server crash, corrupt restore, or repeatable HTTP 500 not explained by
  environment.
- Exact repeats all return `cache_n=0` while evidence shows identical
  namespace, token count, and checksum.
- Near-prefix request restores as if exact without safety evidence.
- Raw prompt text leaks into redacted evidence or public metrics.
- Cold demotion fails through filesystem write error without bounded skip,
  eviction, or documented block.

BLOCKED criteria:

- `BLOCKED-prerequisite`: missing fixture, binary, baseline, or Stage 20
  heavy report.
- `BLOCKED-fit-capacity`: selected context/cache profile cannot fit current
  host memory.
- `BLOCKED-time-budget`: cap expires before required class mix finishes.
- `BLOCKED-metric-unavailable`: required public metric family absent and no
  acceptable substitute evidence exists.
- `BLOCKED-runner-contract`: runner does not emit required summary, metrics,
  or evidence files.
- `BLOCKED-baseline-missing`: Stage 16 baseline cannot be read for HV2.

## Risks

| ID | Risk | Mitigation |
| --- | --- | --- |
| R-21-01 | 27B fixture only fits reduced context, not near-60k. | Treat chat-feasible profile as required; expanded profile is optional unless Manager makes it binding. |
| R-21-02 | Stage 20 heavy-v2 prototype uses short prompts that may not exercise agentic rendering enough. | Implementation plan must review and may replace prompts with generated chat prompts while preserving class mix. |
| R-21-03 | Exact repeats still miss because request metadata changes between calls. | Evidence must include checksum, token count, namespace hash or preparation id, and bounded miss reason. |
| R-21-04 | Near-prefix rows are mistaken for expected hits. | D17-03 remains binding: prefix restore is not implemented; expected result is rejection or bounded miss. |
| R-21-05 | Metrics absent from public scrape. | Report metric as blocked and cite JSONL/log substitute only when it proves the same contract. |
| R-21-06 | Heavy run exceeds interactive session length. | Use request and wall-clock caps; classify incomplete class mix as `BLOCKED-time-budget`. |

## Handoff

Next owner: Architect for design review in a fresh session.

After design review PASS, Manager records the design gate. Developer may then
write the Stage 21 implementation plan. The implementation plan may reuse
`kickoff-stage20-heavy-v2.ps1`, but only after checking it against this
contract and recording any required script edits. QA execution follows only
after Manager opens the execution gate.

Stage 21 is ready for design review when this file is indexed and remains
under the 300-line document cap. The tracker row remains pending until
Manager advances the gate.

This file uses LF line endings, plain ASCII status labels, and stays under
the 300-line durable-doc cap.
