# Stage 21 runner patch implementation evidence

Status: ready for Architect implementation review
Date: 2026-06-18
Stage: 21 (Heavy Tier Mixed Workload Verification)
Author: Developer (implementation)
Scope: Patch the Stage 20 heavy runner prototype for the approved Stage 21 runner contract. Dry-run and parser checks only.

## Inputs

- Parent implementation log: [../cache-handling-phase21-implementation.md](../cache-handling-phase21-implementation.md)
- Implementation-plan review: [part-01-architect-implementation-plan-review-gate-01.md](part-01-architect-implementation-plan-review-gate-01.md)
- Manager implementation-plan gate: [part-02-manager-implementation-plan-gate.md](part-02-manager-implementation-plan-gate.md)
- Runner patched: [../cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1](../cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1)

## Scope result

Changed files:

| Path | Change |
| --- | --- |
| `._design_docs/cache-handling-test-scripts/kickoff-stage20-heavy-v2.ps1` | Converted prototype to the Stage 21 TP-21-HV1/TP-21-HV2 contract. |
| `._design_docs/cache-handling-phase21-implementation.md` | Updated status, contents, and gate row for the implementation patch. |
| `._design_docs/cache-handling-phase21-implementation/part-03-runner-patch-implementation-evidence.md` | Added this evidence record. |

No production code, unit tests, fixtures, CMake files, stress scripts, longrun scripts, commits, or full Qwen3.6 heavy execution were changed or run.

## Runner contract changes

The runner now:

- Uses Stage 21 naming: default output root `._test_output/stage21-heavy-YYYYMMDD-01/<run-id>/`.
- Uses row labels `TP-21-HV1` and `TP-21-HV2`.
- Keeps HV-expanded out of the default flow.
- Uses built-in GGUF chat template by default. `--chat-template-file` is emitted only when `-ChatTemplateFile` is set, and a reason is required.
- Keeps the binding profile defaults: `-c 2048`, `-np 1`, `--cache-ram 2048`, `--cache-cold-max-mib 4096`, hybrid mode, redacted prompt evidence, and `--metrics`.
- Sets chat request timeout to 120 seconds, satisfying F-21-IPR-01.
- Generates the deterministic Stage 21 class mix: 3 exact originals, 2 near-prefix variants, 2 new prompts, and 3 exact repeats.
- Writes request and response JSON files during live execution.
- Writes `summary.json` for TP-21-HV1 with request class, HTTP status, `cache_n`, `prompt_n`, duration, checksums, and verdict contribution fields.
- Writes `comparison.json` for TP-21-HV2 using the durable Stage 16 analysis path and Stage 20 heavy report path.
- Parses prompt-evidence JSONL when present and records lookup outcomes, prefix-candidate records, parse errors, and redaction leaks.
- Scrapes `metrics-before.txt` and `metrics-after.txt`; failed scrapes return `BLOCKED-metric-unavailable`, not zero.
- Calculates candidate verdict fields for exact repeats, near-prefix hits, request errors, redaction leaks, and cold eviction pressure.

## Carry-forward findings

| Finding | Result |
| --- | --- |
| F-21-IPR-01 | Request timeout changed from the prototype's 90 seconds to `RequestTimeoutSec=120` by default and in the dry-run evidence. |
| F-21-IPR-02 | The changed-file list above includes this implementation log part and the parent implementation log update. |
| F-21-IPR-03 | The runner reports no cold eviction pressure as `not-observed` in TP-21-HV1 dry-run verdicts and uses `observed-metric-row` only when a `cache_cold_evictions_total` row exists after live execution. |

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

Result: PASS, dry-run only. No server launch and no model-backed request execution.

Dry-run output path:

`._test_output/stage21-heavy-20260618-01/20260618-142537/`

Key dry-run checks:

| Check | Result |
| --- | --- |
| `--cache-mode hybrid` | true |
| `--cache-cold-path` | true |
| `--cache-cold-max-mib 4096` | true |
| `--cache-ram 2048` | true |
| `--cache-prompt-evidence redacted` | true |
| `--cache-prompt-evidence-dir` | true |
| `--metrics` | true |
| `-c 2048` | true |
| `-np 1` | true |
| `--jinja` | true |
| built-in template default, no `--chat-template-file` | true |
| request timeout | 120 |

TP-21-HV2 dry-run comparison wrote `comparison.json`; Stage 16 and Stage 20 durable inputs both resolved as `OK`. Stage 21 exact-repeat hit count is `DRYRUN` and classified `inconclusive`, because full heavy execution did not run.

## Handoff

Implementation patch is ready for Architect implementation review.

Recommended review focus:

- Confirm the runner patch satisfies D21-IMPLPLAN-01 through D21-IMPLPLAN-03.
- Confirm dry-run evidence is enough for implementation review before full heavy execution opens.
- Confirm the live-execution path's request/response, metrics, JSONL, summary, comparison, and verdict fields meet the Stage 21 runner contract.

QA execution remains closed. Full Qwen3.6 heavy execution should wait for the next gate.
