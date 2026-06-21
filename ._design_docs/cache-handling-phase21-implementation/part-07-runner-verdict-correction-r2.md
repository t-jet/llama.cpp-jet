# Stage 21 runner verdict correction iteration 2

Status: ready for Architect implementation re-review (iter 3)
Date: 2026-06-18
Stage: 21 (Heavy Tier Mixed Workload Verification)
Author: Developer (implementation correction, fresh session)
Scope: Correct F-21-RR-01 minimum-class-count gates. Parser and dry-run checks only.

## Inputs

- Parent implementation log: [../cache-handling-phase21-implementation.md](../cache-handling-phase21-implementation.md)
- Architect implementation re-review gate 01: [part-06-architect-implementation-re-review-gate-01.md](part-06-architect-implementation-re-review-gate-01.md)
- Prior correction record: [part-05-runner-verdict-correction.md](part-05-runner-verdict-correction.md)
- Design contract: [../cache-handling-phase21-design.md](../cache-handling-phase21-design.md)
- Design review gate 01: [../cache-handling-phase21-design/part-01-design-review-gate-01.md](../cache-handling-phase21-design/part-01-design-review-gate-01.md)
- Manager design gate: [../cache-handling-phase21-design/part-02-manager-design-gate.md](../cache-handling-phase21-design/part-02-manager-design-gate.md)
- Runner corrected: [../cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1](../cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1)

## Finding addressed

F-21-RR-01 (BLOCKING) found that `Get-HV1Verdict` checked bounded miss evidence only inside loops over existing `near-prefix` and `new-prompt` rows, but did not require minimum class counts before the final `PASS-candidate` branch. A synthetic call with one exact-repeat hit, prompt evidence records, and no near-prefix or new-prompt rows returned `PASS-candidate`. Stage 21 PASS requires all prompt classes to execute and requires bounded near-prefix and new-prompt evidence before PASS.

Required minimum class counts from design contract (Workload design table):

| Class | Minimum count |
| --- | ---: |
| exact-original | 3 |
| exact-repeat | 3 |
| near-prefix | 2 |
| new-prompt | 2 |

## Code change

Changed file:

| Path | Lines changed | Change |
| --- | --- | --- |
| `._design_docs/cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1` | 303-317 | Added minimum-class-count gates before `PASS-candidate` branch |

New live verdict gates added after existing prompt-evidence checks and before cold eviction check:

```powershell
$originals = @($Requests | Where-Object { $_.request_class -eq 'exact-original' })
if ($originals.Count -lt 3) {
    $blockedContractReasons += "required-class-exact-original-missing-expected-3-actual-$($originals.Count)"
}
if ($exactRepeats.Count -lt 3) {
    $blockedContractReasons += "required-class-exact-repeat-missing-expected-3-actual-$($exactRepeats.Count)"
}
if ($near.Count -lt 2) {
    $blockedContractReasons += "required-class-near-prefix-missing-expected-2-actual-$($near.Count)"
}
if ($newPrompts.Count -lt 2) {
    $blockedContractReasons += "required-class-new-prompt-missing-expected-2-actual-$($newPrompts.Count)"
}
```

Gate placement: AFTER the existing fail-reason checks (HTTP failures, near-prefix hits, redaction leaks, exact-repeat no-hit) and prompt-evidence checks (missing JSONL, parse errors, record-count mismatch, per-row near-prefix and new-prompt bounded evidence), but BEFORE the final `PASS-candidate` branch. These gates fire early even when evidence is missing, as required by F-21-RR-01.

Preserved existing corrected gates from commit `65d678d71`:

- Missing/zero prompt-evidence JSONL → BLOCKED-metric-unavailable
- JSONL parse error → BLOCKED-runner-contract
- Record count < request count → BLOCKED-runner-contract
- Near-prefix with cache_n > 0 or lookup_outcome=hit → FAIL-candidate
- Near-prefix without bounded miss outcome → BLOCKED-metric-unavailable
- New-prompt with cache_n > 0 or lookup_outcome=hit → FAIL-candidate
- New-prompt without bounded miss outcome → BLOCKED-metric-unavailable
- DRYRUN sentinel remains as is

When `-RequestsPerRow` cuts the hardcoded workload short, the runner now returns `BLOCKED-runner-contract` because the runner failed to deliver the required class mix. This is the correct failure mode.

## Checks run

### Parser check

Command:

```powershell
$path='._design_docs/cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1'
$tokens=$null; $errors=$null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path), [ref]$tokens, [ref]$errors)
```

Result: **PASS**

Literal output:

```text
Error count: 0
Parse OK
```

### Dry-run

Command:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ._design_docs/cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1 -CacheColdPath 'd:\source\llama.cpp-jet\._test_output\stage21-dryrun-r2-cold' -DryRun -RequestsPerRow 10 -TimeBudgetMin 1
```

Result: **PASS**, dry-run only. No server launch and no model-backed requests.

Dry-run output path:

`._test_output/stage21-heavy-20260618-01/20260618-153622/`

Dry-run still reports `dry_run: true` and `DRYRUN` verdict sentinels because live JSONL and metric evidence do not exist until full heavy execution. The corrected gates affect only live requests.

### Synthetic minimal-mix test

Test command:

```powershell
# Define Test-BoundedMissOutcome and Get-HV1Verdict from the patched runner
# Invoke with synthetic inputs: 1 exact-original + 1 exact-repeat, clean prompt evidence, ZERO near-prefix, ZERO new-prompt
$reqs = @(
    @{ request_id='req-001'; request_class='exact-original'; cache_n=0; http_status=200 },
    @{ request_id='req-008'; request_class='exact-repeat'; cache_n=11; http_status=200 }
)
$metrics = @{ status='OK'; path='none' }
$evidence = @{
    status='OK'; records=2;
    record_details=@(
        @{ index=1; lookup_outcome='exact_entry_absent'; parse_error=$false },
        @{ index=2; lookup_outcome='hit'; parse_error=$false }
    );
    lookup_outcomes=@{}; redaction_leak=$false; prefix_candidate_records=0
}
$verdict = Get-HV1Verdict -Requests $reqs -MetricsBefore $metrics -MetricsAfter $metrics -PromptEvidence $evidence
$verdict | ConvertTo-Json -Depth 6
```

Result: **PASS**

Status: `BLOCKED-runner-contract`

Blocked contract reasons:

```text
required-class-exact-original-missing-expected-3-actual-1
required-class-exact-repeat-missing-expected-3-actual-1
required-class-near-prefix-missing-expected-2-actual-0
required-class-new-prompt-missing-expected-2-actual-0
```

Literal JSON output:

```json
{
  "metrics_before": "OK",
  "fail_reasons": [],
  "near_prefix_hits": 0,
  "blocked_contract_reasons": [
    "required-class-exact-original-missing-expected-3-actual-1",
    "required-class-exact-repeat-missing-expected-3-actual-1",
    "required-class-near-prefix-missing-expected-2-actual-0",
    "required-class-new-prompt-missing-expected-2-actual-0"
  ],
  "new_prompt_count": 0,
  "bounded_new_prompt_evidence": 0,
  "blocked_metric_reasons": [],
  "bounded_near_prefix_evidence": 0,
  "exact_repeat_hits": 1,
  "status": "BLOCKED-runner-contract",
  "cold_eviction_pressure": "not-observed",
  "metrics_after": "OK",
  "prompt_evidence": "OK",
  "reasons": [
    "required-class-exact-original-missing-expected-3-actual-1",
    "required-class-exact-repeat-missing-expected-3-actual-1",
    "required-class-near-prefix-missing-expected-2-actual-0",
    "required-class-new-prompt-missing-expected-2-actual-0"
  ]
}
```

This confirms the new gates fire when the request mix is incomplete and return `BLOCKED-runner-contract` as required. The runner's hardcoded workload in `Get-Stage21Workload` already provides exactly 3+2+2+3 entries, so these gates will only fire when `-RequestsPerRow` cuts the workload short, which is the correct failure mode.

## Scope guard

No production code, unit tests, fixtures, CMake files, stress scripts, longrun scripts, commits, or full heavy execution were changed or run.

## Handoff

F-21-RR-01 is ready for Architect implementation re-review iteration 3. QA/full heavy execution remains closed until that re-review passes and Manager opens the execution gate.
