# Stage 23 S07 pressure-workload fix review

Verdict: PASS
Date: 2026-06-22
Owner: Architect
Review target: [stage23-remaining-s07-20260622-03-fixes.md](stage23-remaining-s07-20260622-03-fixes.md)

## Scope

Reviewed the S07 pressure-workload fix only. I did not run the 30 minute S07
row. QA owns the focused S07 rerun after Manager accepts this review.

Reviewed files:

- `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s07_protected_root_pressure.ps1`
- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s06_cold_queue_pressure.ps1`
- `._design_docs/.test_reports/stage23-remaining-s07-20260622-03.md`
- `._design_docs/.test_reports/stage23-remaining-s07-20260622-03-fixes.md`
- `._design_docs/.test_reports/stage23-remaining-s07-20260622-01-fixes.md`
- `._design_docs/.test_reports/stage23-remaining-s07-20260622-01-bugfix-review.md`
- `._design_docs/.test_reports/stage23-remaining-s06-20260621-02-fixes.md`
- `._design_docs/cache-handling-phase23-implementation.md`
- `._design_docs/document-index.md`
- `._design_docs/cache-handling-stage-tracker.md`
- `._design_docs/.test_reports/.gitignore`

## Findings

No blocking findings.

The root cause is correctly classified as a runner/workload evidence gap. The
prior S07 runner-contract fix worked: S07 ran with the intended 8 MiB hot
budget and no later wrapper `--cache-ram 512` override. The remaining blocker
was workload size. Qwen3.5 MTP saves were about 50 MiB, so every save was
rejected before hot admission:

```text
payload bytes: 53150792
budget bytes: 8388608
```

With no admitted payloads, protected-root decisions, protected-root demotions,
payload evictions, and payload demotions stayed 0. That was not a product
failure.

The fix scope is narrow and matches the accepted S06 pattern. S07 now receives
`-HotBudgetMiB 8`, uses the existing Qwen3-0.6B pressure fixture when present,
records the primary Qwen3.5 model in side logs and evidence notes, and sends a
deterministic unique non-protected pressure prompt on each loop. The wrapper
side log records `S07 pressure_workload`, fixture state, `mtp_variant=2`, and
`primary_model=<Qwen3.5 primary>`.

The required Stage 23 flags are preserved for S07: `--cache-mode hybrid`,
`--cache-cold-max-mib 512`, `--n-gpu-layers all`, `--fit off`,
`--cache-cold-path`, `--cache-prompt-evidence redacted`, and
`--cache-prompt-evidence-dir`. The S07 wrapper flag list still omits wrapper
`--cache-ram 512`, leaving the child script's 8 MiB local budget effective.

S06 behavior is unchanged. S06 still uses its Qwen3-0.6B pressure fixture,
keeps `effective_cache_ram_mib=16`, and omits wrapper `--cache-ram 512`.
Default rows are unchanged: S04 still receives wrapper `--cache-ram 512`.

No product code, public CLI flag, public metric, test code, or fixture file was
changed in the reviewed diff. The `.test_reports/.gitignore` whitelist for
`stage23-*.md` is acceptable because Stage 23 durable Markdown reports are
review artifacts under `.test_reports/`. It does not unignore row output,
prompt evidence, logs, cold files, or other non-durable artifacts.

## Acceptance decision

This fix is review PASS. QA may rerun focused S07 after Manager acceptance.

The one-minute smoke is sufficient for this fix review: it admitted entries
under the 8 MiB hot budget and crossed the pressure boundary:

```text
llamacpp_cache_entries{mode="hybrid"} 51
llamacpp_cache_payload_demotions_total{mode="hybrid"} 129
llamacpp_cache_payload_evictions_total{mode="hybrid"} 1
llamacpp_cache_payload_cold_evictions_total{mode="hybrid"} 19
oversize rejects: 0
```

Public protected-root counters staying 0 is not a rework finding for this
pressure-workload fix. Existing test-script guidance says H35/H36 require
trusted protected entries and that public requests with degraded rendered-text
metadata are not enough. Therefore S07 acceptance should not require live public
protected-root counters from degraded prompt strings.

QA acceptance for the focused rerun should require both:

- live S07 payload pressure under the 8 MiB budget, shown by admitted entries
  plus non-zero payload demotions or payload evictions
- focused trusted protected-root evidence from the same clean-build gate, such
  as `test-cache-controller.exe` protected-root controller tests or the Stage 4
  H35/H36 focused controller wrapper

If the focused protected-root controller evidence is absent or fails, S07 should
be `BLOCKED-evidence-missing` or `FAIL` according to the focused evidence, not
PASS from public degraded prompt counters.

## Evidence checked

Parser checks passed:

```text
PARSER_OK ._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1
PARSER_OK ._design_docs/cache-handling-test-scripts/stress/stress_s12_s07_protected_root_pressure.ps1
PARSER_OK ._design_docs/cache-handling-test-scripts/stress/stress_s12_s06_cold_queue_pressure.ps1
```

Scoped whitespace check passed:

```text
git diff --check -- ._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1 ._design_docs/cache-handling-test-scripts/stress/stress_s12_s07_protected_root_pressure.ps1 ._design_docs/cache-handling-phase23-implementation.md ._design_docs/document-index.md ._design_docs/cache-handling-stage-tracker.md ._design_docs/.test_reports/.gitignore
```

Wrapper dry-runs passed without launching a server:

```text
S07: DryRun OK; no wrapper --cache-ram 512; effective_cache_ram_mib=8; pressure model available; primary Qwen3.5 recorded
S06: DryRun OK; no wrapper --cache-ram 512; effective_cache_ram_mib=16; pressure workload unchanged
S04: DryRun OK; wrapper --cache-ram 512 present
```

Line and byte checks:

```text
cache-handling-phase23-implementation.md: 295 lines, LF, ASCII, no BOM
document-index.md: 137 lines, LF, ASCII, no BOM
cache-handling-stage-tracker.md: 65 lines, LF, ASCII, no BOM
S07 fixes report: 173 lines, LF, ASCII, no BOM
S07 rerun report: 147 lines, LF, ASCII, no BOM
```

Git scope checked. Task-local script changes are limited to the wrapper and S07
stress script. Persistent doc changes are limited to Stage 23 state tracking.
Existing dirty self-improvement memory files and prior Stage 23 reports are
outside this review.

## Handoff

Next owner: Manager. Manager may authorize QA to rerun focused S07 only with a
fresh durable report suffix, fresh output root, and fresh cold root.

QA should keep S08 and L01..L03 stopped until Manager accepts the S07 rerun
result. The S07 rerun report should cite live payload pressure evidence and the
focused trusted protected-root evidence used for acceptance.
