# Stage 21 implementation re-review gate 01

Status: REWORK
Date: 2026-06-18
Stage: 21 (Heavy Tier Mixed Workload Verification)
Reviewer: Architect (implementation re-review, fresh session)
Scope: Re-review of F-21-IR-01 correction after commit `65d678d71`. No full heavy execution was run.
Subject: [../cache-handling-phase21-implementation.md](../cache-handling-phase21-implementation.md)

## Verdict

REWORK. The correction now blocks missing prompt-evidence JSONL, missing
bounded near-prefix evidence, and missing bounded new-prompt evidence for rows
that execute. It still can return `PASS-candidate` when the live request set
contains no near-prefix or new-prompt rows, so `PASS-candidate` is still
possible without the required Stage 21 evidence classes.

Finding counts:

| Severity | Count |
| --- | ---: |
| BLOCKING | 1 |
| non-blocking | 1 |
| INFO | 2 |

## Inputs reviewed

- [../document-index.md](../document-index.md)
- [../cache-handling-phase21-design.md](../cache-handling-phase21-design.md)
- [../cache-handling-phase21-design/part-01-design-review-gate-01.md](../cache-handling-phase21-design/part-01-design-review-gate-01.md)
- [../cache-handling-phase21-implementation.md](../cache-handling-phase21-implementation.md)
- [part-04-architect-implementation-review-gate-01.md](part-04-architect-implementation-review-gate-01.md)
- [part-05-runner-verdict-correction.md](part-05-runner-verdict-correction.md)
- [../cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1](../cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1)
- Commit `65d678d71` (`cache: fix stage 21 runner verdict gates`)
- Dry-run output: `._test_output/stage21-heavy-20260618-01/20260618-144329/`

## Gate checklist

| Area | Verdict | Notes |
| --- | --- | --- |
| F-21-IR-01 prompt evidence | PASS | Missing JSONL or zero records now returns `BLOCKED-metric-unavailable`; parse errors and record-count mismatch return `BLOCKED-runner-contract`. |
| F-21-IR-01 near-prefix evidence | PARTIAL | Executed near-prefix rows without bounded miss/rejection evidence now block, and near-prefix hits fail. Missing near-prefix rows are not blocked. |
| F-21-IR-01 new-prompt evidence | PARTIAL | Executed new-prompt rows without bounded miss evidence now block, and new-prompt hits fail. Missing new-prompt rows are not blocked. |
| Live verdict status | REWORK | `PASS-candidate` can still occur with an incomplete request mix that has exact-repeat hit evidence and prompt evidence but no near-prefix or new-prompt rows. |
| Dry-run contract | PASS | Dry-run still returns `DRYRUN`, writes only dry-run summaries and comparison data, and does not start `llama-server`. |
| Full execution claim | PASS | No full heavy execution was requested or observed during this re-review. |
| Scope control | PASS | Commit `65d678d71` changed the runner, Stage 21 implementation docs, document index summary, and Developer memory; no production code was changed. |

## Findings

| ID | Severity | Finding | Required action |
| --- | --- | --- | --- |
| F-21-RR-01 | BLOCKING | `Get-HV1Verdict` checks bounded miss evidence only inside loops over existing `near-prefix` and `new-prompt` rows (`kickoff-stage20-heavy-v2.ps1` lines 258-302). It does not require minimum class counts before the final `PASS-candidate` branch (`lines 309-320`). A live-like synthetic call with one exact repeat hit, prompt evidence records, and no near-prefix or new-prompt rows returned `PASS-candidate`. Stage 21 PASS requires all prompt classes to execute and requires bounded near-prefix and new-prompt evidence before PASS. | Add live verdict gates for required class counts before `PASS-candidate`: at least 3 exact originals, 3 exact repeats, 2 near-prefix variants, and 2 new prompts for the binding HV-chat-feasible sequence, or equivalent checks tied to the executed workload contract. Missing required classes should produce `BLOCKED-time-budget` or `BLOCKED-runner-contract`, not `PASS-candidate`. Re-run parser and dry-run evidence after the patch. |
| F-21-RR-02 | non-blocking | The correction evidence says `PASS-candidate` requires near-prefix and new-prompt gates to be clean, but the script only proves cleanliness for rows that exist. This is a documentation and code mismatch tied to F-21-RR-01. | Update part 05 or add a follow-up correction note after the code fix so the evidence text matches the executable gate. |
| F-21-RR-03 | INFO | Parser check passed with `Parse OK`. Synthetic checks returned `BLOCKED-metric-unavailable` for missing JSONL, near-prefix missing bounded evidence, and new-prompt missing bounded evidence. | No action for these paths. |
| F-21-RR-04 | INFO | Re-review dry-run output `20260618-144329` has `dry_run: true`, TP-21-HV1 verdict `DRYRUN`, TP-21-HV2 Stage 21 exact-repeat value `DRYRUN`, and only summary/comparison files. No server logs, metrics scrapes, request JSON, or response JSON were created. | No action. |

## Required corrections

Before full heavy execution opens:

- Make `Get-HV1Verdict` reject incomplete live class mixes before
  `PASS-candidate`.
- Preserve the existing corrected gates for prompt-evidence JSONL,
  near-prefix bounded evidence, new-prompt bounded evidence, redaction leaks,
  HTTP failures, and exact-repeat hits.
- Re-run the PowerShell parser check.
- Re-run `-DryRun` and record the new dry-run path.
- Record correction evidence and return for Architect re-review.

No production code, unit tests, fixtures, CMake files, stress scripts,
longrun scripts, commits, or full heavy execution are requested by this
review.

## Handoff

Handoff state: rework required.

Next owner: Developer for the remaining F-21-IR-01 correction. QA/full heavy
execution remains closed until Architect re-review passes and Manager opens
execution.

This file uses LF line endings, plain ASCII status labels, and stays under
the 300-line durable-doc cap.
