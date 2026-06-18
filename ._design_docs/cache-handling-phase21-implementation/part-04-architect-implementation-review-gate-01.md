# Stage 21 implementation review gate 01

Status: REWORK
Date: 2026-06-18
Stage: 21 (Heavy Tier Mixed Workload Verification)
Reviewer: Architect (independent implementation review, fresh session)
Scope: Runner patch and dry-run evidence only. No full heavy execution was run.
Subject: [../cache-handling-phase21-implementation.md](../cache-handling-phase21-implementation.md)

## Verdict

REWORK. The runner patch is close, and the dry-run evidence proves the launch
contract shape, but the live verdict path can return `PASS-candidate` without
proving required bounded-miss and prompt-evidence evidence for TP-21-HV1.

Finding counts:

| Severity | Count |
| --- | ---: |
| BLOCKING | 1 |
| non-blocking | 2 |
| INFO | 2 |

## Inputs reviewed

- [../document-index.md](../document-index.md)
- [../cache-handling-stage-tracker.md](../cache-handling-stage-tracker.md)
- [../cache-handling-phase21-design.md](../cache-handling-phase21-design.md)
- [../cache-handling-phase21-design/part-01-design-review-gate-01.md](../cache-handling-phase21-design/part-01-design-review-gate-01.md)
- [../cache-handling-phase21-design/part-02-manager-design-gate.md](../cache-handling-phase21-design/part-02-manager-design-gate.md)
- [../cache-handling-phase21-implementation.md](../cache-handling-phase21-implementation.md)
- [part-01-architect-implementation-plan-review-gate-01.md](part-01-architect-implementation-plan-review-gate-01.md)
- [part-02-manager-implementation-plan-gate.md](part-02-manager-implementation-plan-gate.md)
- [part-03-runner-patch-implementation-evidence.md](part-03-runner-patch-implementation-evidence.md)
- [../cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1](../cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1)
- Dry-run output: `._test_output/stage21-heavy-20260618-01/20260618-142537/`

## Gate checklist

| Area | Verdict | Notes |
| --- | --- | --- |
| D21-IMPLPLAN-01 scope | PASS | Runner patch and dry-run evidence were produced after Manager opened implementation. |
| D21-IMPLPLAN-02 carry-forward | PARTIAL | F-21-IPR-01, F-21-IPR-02, and F-21-IPR-03 are addressed, but the live verdict still misses required evidence gates. |
| D21-IMPLPLAN-03 optional expanded profile | PASS | HV-expanded remains out of the default flow and is not made a closure blocker. |
| Script correctness | REWORK | Parser passes, but `Get-HV1Verdict` does not enforce all Stage 21 pass/block criteria. |
| Dry-run contract | PASS | Dry run emits Stage 21 naming, TP-21 labels, binding flags, 120 second request timeout, built-in template default, and comparison JSON. |
| Evidence format | REWORK | Dry-run format is usable, but live `summary.json` could report `PASS-candidate` without bounded miss or prompt evidence. |
| Redaction boundary | PASS with limitation | Durable docs contain labels and hashes only. Non-durable request JSON may contain raw prompts; prompt-evidence JSONL leak scan exists. |
| Full execution claim | PASS | Part 3 states dry-run only and no server launch. Artifacts contain no server logs, metrics files, requests, or responses. |
| Production/test/CMake scope | PASS | No production code, unit test code, fixture, CMake, stress, or longrun changes were present in the reviewed patch scope. |
| Docs sync | PASS | Implementation entry now links this review part and records the REWORK gate state. |

## Findings

| ID | Severity | Finding | Required action |
| --- | --- | --- | --- |
| F-21-IR-01 | BLOCKING | `Get-HV1Verdict` only fails on HTTP failure, unsafe near-prefix hit, redaction leak, or zero exact-repeat hits. It records `new_prompt_count`, `near_prefix_hits`, and `prompt_evidence` but does not require prompt-evidence JSONL, bounded miss reasons for new prompts, or bounded miss/rejection evidence for near-prefix variants before returning `PASS-candidate` (`kickoff-stage20-heavy-v2.ps1` lines 228-262). This violates the approved Stage 21 design: TP-21-HV1 PASS requires near-prefix variants to avoid unsafe prefix restore, new prompts to miss with bounded reasons, and redacted prompt evidence to be written. | Update live verdict logic so missing prompt evidence, missing bounded miss/rejection evidence for near-prefix rows, and missing bounded miss evidence for new-prompt rows produce `BLOCKED-metric-unavailable`, `BLOCKED-runner-contract`, or `FAIL-candidate` as appropriate. Re-run parser and dry-run evidence after the patch. |
| F-21-IR-02 | non-blocking | Dry-run evidence proves launch arguments and workload hashes, but it cannot prove the response, metrics, request/response file, JSONL, or live verdict paths. That is acceptable for this gate, but the review must not be used as heavy execution approval. | Keep QA/full heavy execution closed until F-21-IR-01 is fixed and re-reviewed. |
| F-21-IR-03 | non-blocking | The script writes request JSON in non-durable output during live execution, which can contain raw prompt text by design. Durable evidence must continue to cite labels, request ids, checksums, and token counts only. | In the future durable heavy report, do not copy request bodies or raw prompt strings from `._test_output/`. |
| F-21-IR-04 | INFO | Parser check passed: `Parse OK`. The reviewed dry-run command did not launch `llama-server` or issue model-backed requests. | No action. |
| F-21-IR-05 | INFO | Format checks on the implementation entry, part 3, and runner showed LF line endings, no BOM, and plain ASCII. `git diff --check` was clean before this review file was added. | No action. |

## Required corrections

Before full heavy execution opens:

- Fix `Get-HV1Verdict` and any supporting JSONL/metrics parsing so TP-21-HV1 cannot pass without the required bounded-miss and prompt-evidence evidence.
- Re-run the PowerShell parser check.
- Re-run `-DryRun` and record the new output path.
- Update the implementation evidence with the correction and re-review handoff.

No production code, test code, fixture, CMake, stress script, longrun script,
or full heavy execution is requested by this review.

## Decisions

- Stage 20 PASS-INFRASTRUCTURE remains prerequisite/comparison evidence only.
- HV-chat-feasible remains the binding profile.
- HV-expanded remains optional under D21-IMPLPLAN-03.
- Missing public metrics must stay missing or blocked evidence, not invented zero values.

## Handoff

Handoff state: rework required.

Next owner: Developer for runner verdict correction in a fresh session. After
the correction evidence is recorded, return to Architect for implementation
re-review before Manager opens full heavy execution.

This file uses LF line endings, plain ASCII status labels, and stays under
the 300-line durable-doc cap.
