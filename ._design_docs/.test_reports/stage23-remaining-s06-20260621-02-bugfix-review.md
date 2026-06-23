# Stage 23 S06 pressure-workload bugfix review

Verdict: PASS
Date: 2026-06-22
Owner: Architect
Scope: Review of S06 runner workload fix from
`stage23-remaining-s06-20260621-02-fixes.md`. No product code, public server
flags, public metrics, test binaries, commits, pushes, or full S06 live row
were changed or run by this review.

## Reviewed files

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-phase23-design.md`
- `._design_docs/cache-handling-phase23-implementation.md`
- `._design_docs/.test_reports/stage23-remaining-s06-20260621-02.md`
- `._design_docs/.test_reports/stage23-remaining-s06-20260621-02-fixes.md`
- `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s06_cold_queue_pressure.ps1`
- `._test_output/stage23-s06-pressure-fix-dryrun/batch-summary.log.side`
- `._test_output/stage23-s06-pressure-fix-smoke4m/evidence-summary.md`
- `._test_output/stage23-s06-pressure-fix-smoke4m/metrics-after.txt`
- `._test_output/stage23-s06-pressure-fix-smoke4m/resource-samples.csv`
- `._test_output/stage23-s06-pressure-fix-smoke4m/prompt-evidence/cache-prompt-evidence.jsonl`

## Findings

| ID | Severity | Finding | Status |
| --- | --- | --- | --- |
| F-23-S06-02-RC | Info | Root cause is confirmed. With an effective 16 MiB hot payload budget, rerun 02 rejected about 50.595 MiB Qwen3.5 MTP payloads before hot admission. With no admitted hot payload, S06 could not demote, evict, or skip cold demotions. | Closed |
| F-23-S06-02-FIX | Info | Fix is acceptable for the S06 pressure objective. The wrapper keeps S06 at 16 MiB hot budget, cold max 512 MiB, CUDA all, fit off, redacted prompt evidence, cold path, and evidence dir. Only S06 gets the existing Qwen3-0.6B pressure fixture; other rows still use the normal Stage 23 wrapper model path. | Closed |
| F-23-S06-02-EVID | Info | Smoke evidence shows actual cold pressure: 214 demotions, 72 cold evictions, 142 cold files, and 534372000 cold bytes under the 536870912 byte budget. Write-error counter stayed 0. | Closed |
| F-23-S06-02-HYGIENE | Info | Parser checks passed for both edited PowerShell scripts. Scoped diff whitespace check passed. Review artifact and edited docs are LF-only, ASCII, no BOM, and under the durable-doc caps where applicable. | Closed |

## Evidence checked

- Rerun 02 report shows the corrected 16 MiB hot limit but 0 demotions, 0
  skipped demotions, 0 cold evictions, and 0 cold files.
- Fix report shows the rejected Qwen3.5 payload size (`53052428`) against the
  16 MiB budget (`16777216`), which explains the lack of hot admission.
- Wrapper dry-run side log records S06 flags without wrapper `--cache-ram 512`,
  plus `effective_cache_ram_mib=16`, pressure fixture availability, and
  deterministic unique prompts.
- Direct smoke evidence records primary model notes for Qwen3.5 and pressure
  model use of `Qwen3-0.6B-Q8_0.gguf`.
- Prompt evidence JSONL has 215 redacted records and no raw S06 prompt text.
- Smoke logs did not contain HTTP 500, fatal, exception, corrupt, write
  failure, or payload-too-large rejection lines.
- Cold path on disk had 142 files totaling 534381088 bytes.

## Risk notes

- This is a runner workload fixture substitution, not primary Stage 23 model
  evidence. The next report must state that S06 uses Qwen3-0.6B only to create
  cold pressure under the 16 MiB hot budget, while the Stage 23 primary model
  remains Qwen3.5 MTP in the report notes.
- The smoke run is not a substitute for the focused 30 minute S06 row. It only
  proves the fixed workload can create pressure.
- S07..S08 and L01..L03 remain stopped until Manager accepts the S06 outcome or
  explicitly changes the stage order.

## Checks run

```text
PowerShell parser: kickoff-stage20-stress-longrun.ps1 PASS
PowerShell parser: stress_s12_s06_cold_queue_pressure.ps1 PASS
git diff --check (scoped tracked docs/scripts): PASS
Byte hygiene: LF-only, ASCII, no BOM for reviewed docs/scripts
Smoke evidence inspection: PASS
Full S06 live row: not run
```

## Handoff

Next owner: QA, after Manager accepts this review.

QA should run focused S06 only with a fresh durable report suffix, fresh output
root, and fresh cold root. S07..S08 and L01..L03 remain stopped.
