# Test report 20260609-02: Stage 12 V2 bench rows

- Date: 2026-06-09 local
- Owner: QA execution managed by Manager
- Scope: Stage 12 V2 separate-draft bench rows, B01..B08 x 2 Jinja variants
- Evidence root: `._design_docs/.test_reports/mtp-jinja-run-20260609-V2`

## Build evidence

- Command: `cmake --build build-cov --config Release --target llama-server`
- Result: PASS
- Binary: `build-cov/bin/Release/llama-server.exe`
- Binary timestamp: 2026-06-09T11:47:12.3053603+03:00

## Harness fixes during execution

The first V2 bench wrapper still carried V1 assumptions. The following
test-harness fixes were made before the affected rows were rerun:

- `run-v2-bench-batch.ps1` now uses V2 row names, Qwen3-8B target model,
  `MtpVariant=2`, and a V2 evidence root.
- `run-v2-bench-batch.ps1` no longer uses `Select-String -Raw`, which is
  not available in Windows PowerShell 5.
- `bench_s12_b02_checkpoint_hit_rate.ps1` resolves the V2 Jinja path after
  target-model defaults are known, passes the Qwen3-8B target model, and
  adds `--spec-type draft-simple` for the Qwen3-8B + Qwen3-0.6B path.
- `bench_s12_b07_mixed_profile_comparison.ps1` and
  `stress_s12_s05_mixed_workload_profiles.ps1` add
  `--spec-type draft-simple` for target-plus-draft profiles.
- `part-21-stage12-mtp-jinja-test-plan.md` now records that V2 requires
  `--spec-type draft-simple`; the prior "no spec-type" rule disabled
  speculative decoding.

Parser checks after the fix reported zero errors for the changed scripts.

## Row verdicts

| Row | Verdict | Evidence |
| --- | --- | --- |
| S12-MTP-B01-V2-Joriginal | PASS | request_count=12, cache hits=11, misses=1, prefix_match_rate=1.0000, failures=0. |
| S12-MTP-B01-V2-Jmarked | PASS | request_count=12, cache hits=11, misses=1, prefix_match_rate=1.0000, failures=0. |
| S12-MTP-B02-V2-Joriginal | BLOCKED-fixture | Rerun used Qwen3-8B target, Qwen3-0.6B draft, Qwen3-8B `chat_template.jinja`, and `draft-simple`; server log shows `common_speculative_impl_draft_simple`. Cache hits=109, misses=1, checkpoint hits=0, restores=0, admissions=0, admission failures=0. The separate-draft fixture does not admit checkpoints at this in-scope ctx-size. |
| S12-MTP-B02-V2-Jmarked | BLOCKED-fixture | Same as Joriginal with `chat_template_new.jinja`: cache hits=82, misses=1, checkpoint hits=0, restores=0, admissions=0, admission failures=0. |
| S12-MTP-B03-V2-Joriginal | PASS | request_count=115, cache hits=114, misses=1, evictions=0, restore and descriptor failures=0. |
| S12-MTP-B03-V2-Jmarked | PASS | request_count=114, cache hits=113, misses=1, evictions=0, restore and descriptor failures=0. |
| S12-MTP-B04-V2-Joriginal | PASS | request_count=18, cache hits=17, misses=1, evictions=0, restore and descriptor failures=0. |
| S12-MTP-B04-V2-Jmarked | PASS | request_count=18, cache hits=17, misses=1, evictions=0, restore and descriptor failures=0. |
| S12-MTP-B05-V2-Joriginal | PASS | request_count=96, cache hits=95, misses=1, evictions=0, restore and descriptor failures=0. |
| S12-MTP-B05-V2-Jmarked | PASS | request_count=93, cache hits=92, misses=1, evictions=0, restore and descriptor failures=0. |
| S12-MTP-B06-V2-Joriginal | PASS | request_count=24, cache hits=23, misses=1, prefix_match_rate=1.0000, failures=0. |
| S12-MTP-B06-V2-Jmarked | PASS | request_count=24, cache hits=23, misses=1, prefix_match_rate=1.0000, failures=0. |
| S12-MTP-B07-V2-Joriginal | PASS | Three profiles reran. Target-plus-draft uses `draft-simple`; request_count=132, cache hits=131, misses=1, restore/descriptor/pairing failures=0. Plain and checkpoint-dependent profiles also have hits=115, misses=1, failures=0. |
| S12-MTP-B07-V2-Jmarked | PASS | Three profiles reran. Target-plus-draft uses `draft-simple`; request_count=132, cache hits=131, misses=1, restore/descriptor/pairing failures=0. Plain and checkpoint-dependent profiles also have hits=115, misses=1, failures=0. |
| S12-MTP-B08-V2-Joriginal | PASS | request_count=256, misses=256, evictions=237, payload evictions=237, restore and descriptor failures=0. Runtime was 428s because the driver completes a full 256-prompt forest pass once started. |
| S12-MTP-B08-V2-Jmarked | PASS | request_count=256, misses=256, evictions=237, payload evictions=237, restore and descriptor failures=0. Runtime was 425s for the same driver-loop reason. |

## Summary

- PASS: 14
- BLOCKED-fixture: 2
- FAIL: 0
- Product bugs: 0

V2 bench execution is complete. B02 is blocked by fixture/profile
capability, not by Jinja and not by the degraded-boundary fallback fix.

Next owner: Manager continues V2 stress and V2 long-run rows, then records
Developer test-results review for the full V2 session.
