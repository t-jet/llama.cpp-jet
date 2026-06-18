# Stage 21 runner verdict correction

Status: ready for Architect implementation re-review
Date: 2026-06-18
Stage: 21 (Heavy Tier Mixed Workload Verification)
Author: Developer (implementation correction, fresh session)
Scope: Correct F-21-IR-01 in the Stage 21 heavy runner. Parser and dry-run checks only.

## Inputs

- Parent implementation log: [../cache-handling-phase21-implementation.md](../cache-handling-phase21-implementation.md)
- Architect implementation review: [part-04-architect-implementation-review-gate-01.md](part-04-architect-implementation-review-gate-01.md)
- Runner corrected: [../cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1](../cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1)

## Finding addressed

F-21-IR-01 found that `Get-HV1Verdict` could return `PASS-candidate`
without proving three live evidence requirements:

- redacted prompt-evidence JSONL exists and parses;
- near-prefix rows have bounded miss or rejection evidence;
- new-prompt rows have bounded miss evidence.

## Code change

Changed file:

| Path | Change |
| --- | --- |
| `._design_docs/cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1` | `Read-PromptEvidence` now stores ordered JSONL record details. `Get-HV1Verdict` now separates fail, metric-blocked, and runner-contract-blocked reasons before assigning status. |

New live verdict gates:

- Missing JSONL or zero prompt-evidence records gives `BLOCKED-metric-unavailable`.
- JSONL parse errors give `BLOCKED-runner-contract`.
- Fewer JSONL records than executed requests gives `BLOCKED-runner-contract`.
- Near-prefix rows with `cache_n > 0` or JSONL `lookup_outcome = "hit"` give `FAIL-candidate`.
- Near-prefix rows without a bounded miss outcome give `BLOCKED-metric-unavailable`.
- New-prompt rows with `cache_n > 0` or JSONL `lookup_outcome = "hit"` give `FAIL-candidate`.
- New-prompt rows without a bounded miss outcome give `BLOCKED-metric-unavailable`.
- `PASS-candidate` is now possible only after exact-repeat hit, redaction, HTTP, prompt-evidence, near-prefix, and new-prompt gates are clean.

Bounded outcomes accepted by the runner are the Stage 17 bounded restore-miss
enum strings:

`namespace_mismatch`, `token_count_mismatch`, `checksum_mismatch`,
`exact_entry_absent`, `unsafe_prefix_rejected`, `payload_unavailable`, and
`unsupported_route_or_profile`.

The runner also writes separate `fail_reasons`, `blocked_metric_reasons`, and
`blocked_contract_reasons` arrays into the live verdict. Existing aggregate
fields remain present.

## Checks run

Parser check:

```powershell
$path='._design_docs/cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1'
$tokens=$null; $errors=$null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path), [ref]$tokens, [ref]$errors)
```

Result: PASS, `Parse OK`.

Dry-run command:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ._design_docs/cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1 -CacheColdPath 'd:\source\llama.cpp-jet\._test_output\stage21-dryrun-cold' -DryRun -RequestsPerRow 10 -TimeBudgetMin 1
```

Result: PASS, dry-run only. No server launch and no model-backed requests.

Dry-run output path:

`._test_output/stage21-heavy-20260618-01/20260618-143726/`

Dry-run still reports `DRYRUN` verdict sentinels because live JSONL and metric
evidence do not exist until full heavy execution. The corrected gates affect
only live requests.

## Scope guard

No production code, unit tests, fixtures, CMake files, stress scripts,
longrun scripts, commits, or full heavy execution were changed or run.

## Handoff

F-21-IR-01 is ready for Architect implementation re-review. QA/full heavy
execution remains closed until that re-review passes and Manager opens the
execution gate.
