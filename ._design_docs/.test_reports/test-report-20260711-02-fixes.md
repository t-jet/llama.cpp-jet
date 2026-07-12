# Stage 38 corrected-retest fix report

Date: 2026-07-12
Owner: Developer
Source report: [test-report-20260711-02.md](test-report-20260711-02.md)
Source review:
[test-report-20260711-02-developer-review.md](test-report-20260711-02-developer-review.md)
Verdict: FIXED, focused retest PASS

## Scope

This fix closes the live `/v1/chat/completions` TP-38-PR-02 product failure
from report -02. The corrected workload already proved turn 1 rendered tokens
were a strict prefix of turn 2. Product still rejected the checkpoint-dependent
candidate as `unsafe_prefix_rejected` / `prefix_restore_deferred`.

Stage 38 constraints remain unchanged:

- `/completion` prefix restore stays out of scope.
- Public `usage.prompt_tokens` remains the full rendered request length.
- Cache-specific fields report the restored prefix length.
- Checkpoint-dependent, target-plus-draft, and MTP paths restore only from
  checkpoint-safe payloads.
- Recompute remains the fallback on any validation uncertainty.

## Root cause

The checkpoint-dependent prefix path selected a checkpoint payload, but the
strict-prefix validator still treated the cache entry's full prompt length as
the restore prefix. In the live run, the saved entry had 35 prompt tokens and a
checkpoint descriptor for 11 tokens. The validator checked the 35-token entry
boundary instead of the 11-token checkpoint span, so the safe checkpoint
candidate was rejected before apply.

A second validation gap appeared after the span fix: checkpoint descriptors can
represent checkpoint-safe spans that are not `MESSAGE_END` boundaries in
prepared prompt metadata. The old validator required a `MESSAGE_END` boundary
for all accepted prefixes. That was valid for exact-blob prefix restore, but
too narrow for checkpoint payload restore. Stage 38 allows checkpoint
descriptors whose span checksum validates against the requested prefix.

## Code changes

`tools/server/server-cache-hybrid.cpp`

- `validate_strict_prefix_candidate()` now uses
  `restored_token_count_for_payload(entry, selected_payload_kind)` as the
  accepted prefix length. Checkpoint payloads validate the checkpoint span, not
  the full entry length.
- Token equality now requires the entry and request to match through the
  restored span. The entry may continue to match beyond the checkpoint span.
- Checkpoint prefix restore validates the checkpoint descriptor span and
  checksum against both the cached entry prefix and requested prefix. Exact
  blob prefix restore keeps the stricter `MESSAGE_END` boundary requirement.
- `debug_validate_strict_prefix_for_tests()` reuses an existing equivalent
  entry instead of adding a duplicate, so checkpoint-bearing test fixtures keep
  their descriptor metadata.

`tests/test-cache-controller.cpp`

- Updated the target-plus-draft checkpoint-safe case to admit a real checkpoint
  descriptor before expecting acceptance.
- Added `test_stage38_checkpoint_prefix_uses_checkpoint_span()`. The test uses
  a longer cache entry with a shorter checkpoint descriptor and a non-message
  checkpoint-safe boundary. It fails under the old full-entry/MESSAGE_END-only
  validator and passes with the checkpoint descriptor span rule.

`._design_docs/cache-handling-test-scripts/stage38-prefix-restore-and-cold-budget.ps1`

- Fixed the accepted-prefix metric check to allow Prometheus label order with
  `mode` before `result` and `reason`.

## Evidence

Build:

```powershell
cmake --build build --config Release --target test-cache-controller
cmake --build build --config Release --target llama-server
```

Result: PASS. `test-cache-controller` still emits the pre-existing MSVC C4477
warnings in unrelated lines. `llama-server` emits the pre-existing UI gzip
warning and builds successfully.

Focused controller test:

```powershell
.\build\bin\Release\test-cache-controller.exe
```

Result: PASS. The new Stage 38 row
`test_stage38_checkpoint_prefix_uses_checkpoint_span` passed.

ctest:

```powershell
ctest --test-dir build -C Release -R cache --output-on-failure
```

Result: PASS. `test-cache-controller` passed in 0.22 seconds.

Live script retest:

```powershell
pwsh -NoProfile -File ._design_docs\cache-handling-test-scripts\stage38-prefix-restore-and-cold-budget.ps1 `
  -ModelPath "D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf" `
  -LlamaServerPath build\bin\Release\llama-server.exe `
  -RunRoot ._test_output\stage38-prefix-restore-20260712-fix4 `
  -ReportPath ._design_docs\.test_reports\test-report-20260711-02-fix-artifacts\stage38-script-report-fix4.md `
  -CacheColdPath "$env:TEMP\stage38-cold-20260712-fix4" `
  -ColdBudgetMiB 2048
```

Result: PASS.

Final live row outcomes:

| Row | Outcome | Evidence |
| --- | --- | --- |
| setup | PASS | Fresh binary, HEAD `eb3bcb01bf0a89a38469718ab0d0bbf5ec5e58a2` |
| TP-38-PR-02-prefix-proof | PASS | `turn1_request_tokens=35`; `assistant_replay_tokens=43`; `turn2_rendered_tokens=63` |
| TP-38-PR-02-live | PASS | `cached_tokens=11`; `timings.cache_n=11`; `prompt_tokens=63`; `rendered_request_tokens=63` |
| TP-38-PR-02-hit | PASS | hybrid hit delta `1` |
| TP-38-PR-02-prefix-metric | PASS | accepted prefix row present |
| TP-38-MET-01-live | PASS | `2147483648` |
| cleanup | PASS | server stopped; port free |

Metrics from fix4 include:

```text
llamacpp:cache_hits_total{mode="hybrid"} 1
llamacpp:cache_prefix_candidates_total{mode="hybrid",result="accepted",reason="accepted_strict_prefix"} 1
llamacpp:cache_checkpoint_restores_total{mode="hybrid",profile="checkpoint_dependent",payload_residency="hot",pair_state="target_only",result="success"} 1
llamacpp:cache_checkpoint_hits_total{mode="hybrid",profile="checkpoint_dependent",payload_residency="hot",pair_state="target_only"} 1
llamacpp:cache_cold_budget_bytes{mode="hybrid"} 2147483648
```

Server log from fix4 includes:

```text
try_restore - successfully restored 11 tokens into slot 3
restore-apply slot=3 restored_tokens=11
```

## Retest scope

Focused QA retest can use the fix4 script shape. Required checks:

- preserve rendered-token strict-prefix proof artifacts;
- require `cached_tokens > 0`;
- require `timings.cache_n == cached_tokens`;
- require full public `usage.prompt_tokens == 63`;
- require positive hybrid hit delta;
- require accepted prefix metric row independent of label order;
- require cold-budget gauge `2147483648`.

No broader Stage 38 rows need rerun unless Manager wants full closure evidence.
