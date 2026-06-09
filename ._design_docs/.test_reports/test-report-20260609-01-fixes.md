# Fix report for test-report-20260609-01

- Date: 2026-06-09 local
- Owner: Developer fix under Manager coordination
- Scope: S12-MTP-B02-V1 Joriginal and Jmarked checkpoint blocker

## Root cause

B02 used raw `/completion` prompts while passing `--chat-template-file`.
That path does not render the chat template, so `chat_template_new.jinja`
could not emit cache-boundary markers. The marked Jinja file was not the
cause.

The server also rejected valid degraded fallback. Public chat rendering
creates non-native boundary metadata. When a live checkpoint span did not
match one inferred message span, checkpoint admission created a checksum
fallback descriptor, but validation still rejected it because any
metadata-bearing request was treated as boundary-required.

## Fix

- `bench_s12_b02_checkpoint_hit_rate.ps1` now uses
  `/v1/chat/completions` for B02. The marked variant sends
  `chat_template_kwargs.emit_cache_boundaries=true`; the original variant
  leaves the marker flag unset.
- `server-cache-hybrid.cpp` now accepts checksum fallback descriptors when
  metadata is non-native or degraded and no exact checkpoint boundary span
  exists. Native boundary mismatches still reject the checkpoint.
- `test-cache-controller.cpp` adds coverage for degraded and inferred
  metadata fallback while keeping native span mismatch rejection.

## Evidence

- Build: `cmake --build build --config Release --target llama-server test-cache-controller`
- Focused test: `build\bin\Release\test-cache-controller.exe`
  - Result: PASS, 87 tests.
- Final B02 evidence root:
  `._design_docs/.test_reports/mtp-jinja-b02-final-20260609`

Final B02 counters:

| Row | Requests | Cache hits | Checkpoint hits | Checkpoint restores | Checkpoint admissions | Admission failures |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| S12-MTP-B02-V1-Joriginal | 55 | 54 | 54 | 54 | 1 | 0 |
| S12-MTP-B02-V1-Jmarked | 26 | 25 | 25 | 25 | 1 | 0 |

Both rows used `Qwen3.5-4B-Q4_K_M.gguf`, `draft-mtp`, and the expected
V1 Jinja file. Server logs show `common_speculative_impl_draft_mtp` and
no checkpoint admission skip in the final evidence.

## Result

S12-MTP-B02-V1-Joriginal and S12-MTP-B02-V1-Jmarked are no longer blocked.
The V1 aggregate is now 36 PASS, 2 BLOCKED-infra, 0 BLOCKED-test-framework,
0 FAIL, 0 NO-EVIDENCE.
