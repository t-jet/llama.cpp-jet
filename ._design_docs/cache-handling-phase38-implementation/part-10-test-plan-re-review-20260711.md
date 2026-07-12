VERDICT: PASS

# Stage 38 test-plan re-review

Date: 2026-07-11
Reviewer: Architect
Scope: fresh re-review after QA correction for F38-TP-01 through F38-TP-03

## Scope and gate status

This is a test-plan re-review only. No production code, tests, staging,
commits, pushes, reverts, or execution runs were performed.

Reviewed artifacts:

- `._design_docs/cache-handling-phase38-implementation/part-09-test-plan-review-20260711.md`
- `._design_docs/cache-handling-phase38-implementation/part-08-qa-test-plan-20260711.md`
- `._design_docs/cache-handling-test-plan/part-42-stage38-prefix-restore-cold-budget.md`
- `._design_docs/cache-handling-test-scripts/stage38-prefix-restore-and-cold-budget.ps1`
- `._design_docs/cache-handling-test-scripts/README.md`
- `._design_docs/cache-handling-test-plan.md`
- `._design_docs/cache-handling-phase38-implementation.md`
- Stage 38 design and implementation gate parts as needed for scope checks.

Gate result: PASS. F38-TP-01, F38-TP-02, and F38-TP-03 are closed. The
test-plan artifacts now meet the Stage 38 test-plan review criteria and can go
to Manager test-plan gate.

## Finding closure

| Finding | Status | Evidence |
| --- | --- | --- |
| F38-TP-01 live suffix evidence missing `timings.cache_n` | CLOSED | The script extracts `j.timings.cache_n`, asserts it equals `usage.prompt_tokens_details.cached_tokens`, and writes both values in the `TP-38-PR-02-live` evidence row. Part 42 and README name the same assertion. |
| F38-TP-02 public `prompt_tokens` proof too weak | CLOSED | The script now calls `/apply-template`, tokenizes the rendered prompt through `/tokenize`, and requires `usage.prompt_tokens == rendered_request_tokens` plus `prompt_tokens > cached_tokens`. Part 42, README, and part 08 all describe this exact evidence strength. |
| F38-TP-03 README metadata stale | CLOSED | `cache-handling-test-scripts/README.md` now has `Last updated: 2026-07-11` and its Stage 38 section matches the corrected script behavior. |

## Criteria check

| Criterion | Result | Notes |
| --- | --- | --- |
| Current Stage 38 scope | PASS | Part 42 remains limited to chat strict-prefix partial restore and D36-FU-01 cold-budget gauge. `/completion` prefix restore stays recompute-only. |
| TP-38 row coverage | PASS | TP-38-PR-01 through TP-38-PR-10 and TP-38-MET-01/02 have named focused or live evidence paths. |
| Live public cache evidence | PASS | The standalone script binds cached tokens, `timings.cache_n`, full public prompt tokens, hybrid hit delta, accepted prefix metric row, and cold-budget gauge. |
| Evidence format | PASS | The script writes plain `PASS`, `FAIL`, and `BLOCKED` rows with raw request, response, metrics, template, and tokenization artifacts under the non-durable run root. |
| Clean-build and stale-binary rule | PASS | Part 42 requires clean Release build. The script refuses `llama-server.exe` older than 10 minutes. |
| README and automation alignment | PASS | README parameters and behavior match the script: suffix turn, `cached_tokens > 0`, `timings.cache_n == cached_tokens`, rendered-token equality, hit delta, accepted prefix metric, and 2048 MiB gauge. |
| ASCII status labels and no unicode icons | PASS | Reviewed Stage 38 rows use `PASS`, `FAIL`, `SKIP`, and `BLOCKED`; no unicode status icons are used in the Stage 38 additions. |
| Stale content removal | PASS | Prior stale README date is corrected. Part 42 no longer claims a weaker prompt-token check than the script performs. |

## Verification notes

- PowerShell parser check on
  `stage38-prefix-restore-and-cold-budget.ps1`: PASS.
- `/apply-template` and `/tokenize` request and response fields match
  `tools/server/README.md` and existing unit tests.
- `llamacpp:cache_prefix_candidates_total` and
  `llamacpp:cache_cold_budget_bytes` names match the Stage 38 design. The
  script patterns match the metric family rows in Prometheus output.
- No live model-backed execution was run in this re-review. That remains QA
  execution work after Manager test-plan gate.

## New findings

No blocking findings.

No non-blocking findings.

## Handoff state

State: ready for Manager test-plan gate.

Next owner: Manager.

Next gate: Manager test-plan gate, then QA execution if Manager approves.
