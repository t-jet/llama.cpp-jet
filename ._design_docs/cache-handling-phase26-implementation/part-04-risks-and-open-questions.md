# Part 4: Risks and open questions

Status: planning
Date: 2026-06-26
Stage: 26 (Metrics Alignment + Stage 24/25 Carry-Over Resolution)
Author: Developer

## Risks

### R-1: SEH handler is Windows-only

- `#ifdef _WIN32` guard is mandatory.
- `tools/server/CMakeLists.txt` adds `server-crash-handler.cpp` only
  when `WIN32` is true.
- Linux / macOS builds are unaffected; no-op install function.
- Mitigation: Stage 26 is Windows-primary per the silent-crash
  evidence base; non-Windows platforms have no observed symptom.

### R-2: Hard metrics rename is breaking

- 67 metric names change: `llamacpp_X` -> `llamacpp:X` (37) and
  `cache_X` -> `llamacpp:cache_X` (30).
- Prometheus scrapers and dashboards keyed on the old names break
  on first deploy.
- Mitigation: OQ-26-01 hard-rename decision; breaking-change note
  in implementation log; fixture scripts updated in lockstep
  (Steps 5-6).

### R-3: Public API change (--crash-dump-dir)

- New CLI flag is operator-facing diagnostic.
- Existing flag parsing in `llama-server.cpp` (or `main.cpp`)
  extended.
- Mitigation: OQ-26-02 empty default (disabled); no default behavior
  change; explicit opt-in required.

### R-4: Stage 24 rerun may still reproduce D-EXEC-24-03

- SEH handler provides a dump but does not fix the crash.
- If the rerun crashes:
  - Step 11 captures .dmp via SEH (D-EXEC-24-03-a closure).
  - Crash attribution moves forward (D-EXEC-24-03-b).
  - Test report verdict: BLOCKED-structural-not-infra (same as
    Stage 24 -06).
- If the rerun passes:
  - D-EXEC-24-03-b status moves to RESOLVED.
  - Stage 25 follow-up (e) closes as not implicated.
- Mitigation: SEH handler installed first (Step 1 before Step 11).

### R-5: Cold-store accounting fix may regress file-count metric

- The new `cold_payload_files_count_` field tracks file count.
- `n_cold_payload_count` (existing at `server-cache-hybrid.h:776`)
  tracks descriptor count.
- These are different: a descriptor in `demoting` state may not yet
  have a file. File count == cold-residency descriptor count after
  demote completion.
- Mitigation: TP-26-UT5 verifies file count == readdir count after
  the fix; if divergence persists, add a counter-consistency note.

### R-6: `result.bytes_written` may not be exposed

- The current `io_completion_result` exposes `target_bytes` and
  `draft_bytes` vectors (size known via `.size()`).
- `target_size_bytes + draft_size_bytes` already matches what the
  controller uses at line 707 (`descriptor.target_size_bytes +
  descriptor.draft_size_bytes`).
- If the design wants the EXACT disk bytes (including header overhead
  and alignment), `bytes_written` needs to be added to
  `io_completion_result`. This is in scope of Step 2 but the user
  prompt does not require exact-disk accounting; metric-vs-file-size
  is the comparison metric. Decision: use `target_size_bytes +
  draft_size_bytes` (descriptor-reported) for now; document exact-
  bytes as a future improvement.

### R-7: Restore-init directory walk may be slow

- One-time O(N) scan at controller init for cold-store restore.
- For 115 files this is fast (single readdir + size).
- Mitigation: only runs at controller init, not per metric scrape.
  Test TP-26-UT3 covers cleanup decrement; restore-init scan is
  covered implicitly by the existing restore tests (132 + 5 = 137).

### R-8: Stage 24 rerun is long-running

- Leg duration 10 minutes x 2 variants x 2 rows = 40 minutes minimum.
- Plus CUDA warmup and model load overhead = up to 90 minutes total.
- Mitigation: pre-flight dry-run (already part of the runner);
  background execution with progress polling; abort on first crash.

### R-9: Label rename `mode` -> `scope` is breaking

- Operators querying `cache_prompt_evidence_records_total{mode="..."}`
  break.
- Mitigation: rename only on this one metric; other metrics keep
  `mode` label.

### R-10: Runner metric_delta_comparison has hard-coded names

- Lines 1033..1035 in `stage24-chat-s02-s03-comparison.ps1` use
  `cache_restore_misses_total`, `cache_prompt_evidence_records_total`,
  `cache_checkpoint_admissions_total` directly.
- Mitigation: Step 5 update these to `llamacpp:` form. The MetricNames
  array is the canonical lookup; this block reads via
  `$HybridSummary.metric_deltas.<name>.delta` after Step 5.

## Dependencies

| Dependency | Status | Owner |
| --- | --- | --- |
| Design PASS D26-DESIGN-01 | PASS 2026-06-25 | Manager |
| Manager design gate D26-DESIGN-MGR | pending | Manager |
| build-cuda binary baseline | present (build-cuda/bin/Release/llama-server.exe) | environment |
| Qwen3.5-4B MTP fixture | present (._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf) | environment |
| 132/132 unit tests pass on baseline | PASS (last verified Stage 25 closure) | test-cache-controller |

## Open implementation questions for Architect review

| IQ | Question | Default if no answer |
| --- | --- | --- |
| IQ-26-01 | Should the SEH filter also capture the Windows `GetLastError` value and any outstanding `errno`-style error from the calling thread's TLS? | Capture `GetLastError` only; leave TLS scan for a future stage |
| IQ-26-02 | Should `cold_payload_bytes_by_id_` persist across server restarts, or be rebuilt from the cold-store directory walk on every controller init? | Rebuild from directory walk on every init (simpler, avoids stale state) |
| IQ-26-03 | Should the rename of `mode` -> `scope` also add a comment in the code explaining the rename, or rely on the implementation log? | Code comment + implementation log |
| IQ-26-04 | Should the Stage 24 rerun use `--cache-ram 512` (matches Stage 24 -06) or a different value to expose more cold-store activity? | Match Stage 24 -06 exactly (512) to keep evidence comparable |
| IQ-26-05 | Should the metric rename also update the comment at the top of `tools/server/server-context.cpp` line 4336..4338 that explains the prefix convention? | Yes; align comment with new colon-prefix convention |

## Handoff

Part-04 is reviewable. Next: part-05 Manager review slot (NOT
authored by this session; Manager owns).
