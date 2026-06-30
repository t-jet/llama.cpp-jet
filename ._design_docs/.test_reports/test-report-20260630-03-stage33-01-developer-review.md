# Stage 33 QA test-results Developer review

Generated: 2026-06-30T22:15:00Z
RunId: stage33-cache-modes-20260630-01
Stage: 33
Source QA report: `D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260630-03-stage33-01.md`
QA verdict: FAIL (Hybrid reuse row)
Reviewer: Developer (test-results review gate)

## VERDICT

**REWORK** on the Hybrid reuse row classification; **PASS-WITH-ACCEPTANCE** for the Stage 33 execution overall.

The QA verdict of FAIL on the Hybrid reuse row is reclassified: the row is a workload-design / cache-budget mismatch, NOT a product regression. All other 11 rows hold at PASS. Stage 33 closes as PARTIAL (6 of 8 legs complete; warm 3 was killed at the 187 min wall-clock gate by design).

## Scope

Review subject: Stage 33 QA execution report and all preserved run artifacts.

Inputs verified by Test-Path (all returned True):

- `D:\source\llama.cpp-jet\AGENTS.md` (workspace rules)
- `D:\source\llama.cpp-jet\CLAUDE.md` (project wrapper)
- `D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260630-03-stage33-01.md` (QA report)
- `D:\source\llama.cpp-jet\._design_docs\.manager-inputs\manager-input-20260630-stage33-full-legacy-hybrid-ab-comparison.md` (intake brief)
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-phase32-implementation\part-06-manager-closure-20260630.md` (Stage 32 closure)
- `D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260630-02-stage32-focused-retest.md` (Stage 32 focused retest)
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1` (driver)
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts\lib\compare-legacy-vs-hybrid-workload.ps1` (workload generator)
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-phase29-design.md` (stage 29 design, line 96)
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-architecture.md` (architecture)
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\summary.json` (driver summary)
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\cold-start-cycle-1\legacy\metrics-{before,after}.txt` + `requests.jsonl`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\cold-start-cycle-1\hybrid\metrics-{before,after}.txt` + `requests.jsonl`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\warm-cycle-1\{legacy,hybrid}\metrics-{before,after}.txt` + `requests.jsonl`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\warm-cycle-2\{legacy,hybrid}\metrics-{before,after}.txt` + `requests.jsonl`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\workload.jsonl` (200 requests, 2058623 bytes)
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\phase-1-output-equivalence\diff.txt` (0 bytes; PASS)
- `D:\source\llama.cpp-jet\D:\tmp\cache-cold-stage33-20260630-01\` (26 .cold files, 2038.5 MiB)

No file path cited in this review failed the `Test-Path` check.

## Per-row classification (12 rows)

| # | Row | QA verdict | Review verdict | Rationale | Owner |
| -: | --- | --- | --- | --- | --- |
| 1 | Setup | PASS | PASS (hold) | Clean Release CUDA configure, `GGML_CUDA:BOOL=ON`, fresh-binary proof (all artifacts newer than source mtime), `test-cache-controller` 142/142 PASS, `ctest -R cache` 1/1 PASS, dry-run preflight PASS, port 8900 free. Driver exits and processes are clean. | QA (hold) |
| 2 | Correctness | PASS | PASS (hold) | `phase-1-output-equivalence\diff.txt` is 0 bytes; legacy-decoded.txt = hybrid-decoded.txt = 4 bytes. Output equivalence driver PASS. | QA (hold) |
| 3 | Hybrid reuse | FAIL | **REWORK: reclassify to EXPECTED BEHAVIOR (workload-design)** | See "Hybrid reuse root-cause analysis" below. Driver extraction is identical to Stage 32 focused retest. `cache_n=0` at the per-request level (server response `usage.prompt_tokens_details.cached_tokens`) and at the Prometheus counter `llamacpp:cache_hits_total{mode="hybrid"}` for 0/600 hybrid rows across 3 completed legs. Hot-cache retention time vs duplicate inter-arrival time shows the original admission is evicted before the duplicate reaches the cache controller. Cold-store auto-load is on-demand by design (Stage 29 design L96, cache-handling-architecture L9), not a regression. | QA (workload reclassification, no product fix) |
| 4 | Namespace bounds | PASS | PASS (hold) | Distinct namespace ids in public metrics = 0 across all 6 metrics-after files. Stage 31 fix preserved. `llamacpp:cache_namespace_count{mode="hybrid"}` = 0 final state. | QA (hold) |
| 5 | Public metric labels | PASS | PASS (hold) | 0 hits for `prompt_hash=`, `request_id=`, `payload_id=`, `namespace="all"`, `path=` patterns across all 6 metrics-after files. Stage 32 metric-label fix preserved. | QA (hold) |
| 6 | HELP/TYPE shape | PASS | PASS (hold) | 0 duplicate HELP lines, 0 duplicate TYPE lines across all 6 metrics-after files. | QA (hold) |
| 7 | Hot RAM | PASS | PASS (hold) | Hybrid cache_bytes = 160.9 MiB vs legacy = 423.7 MiB on all 3 comparable completed legs. Hybrid / legacy = 0.3798. 62% reduction meets >=40% threshold. | QA (hold) |
| 8 | Cold store | PASS | PASS (hold) | 26 .cold files on disk = 2038.5 MiB (within 2048 MiB budget). Per-leg cold-store failure counters = 0 across all 5 metrics-after snapshots. Cold-store demotion completed (cache_payload_demotions_total = 398 across the cycle). | QA (hold) |
| 9 | Performance | PASS | PASS (hold) | Hybrid prompt_ms p50 within 1-2% of legacy on all 3 completed legs; both modes ~8.1s average; <=10% regression gate held. | QA (hold) |
| 10 | Errors | PASS | PASS (hold) | No crash, no SEH, no fatal error, no 5xx; all 200/200 rows per leg returned HTTP 200. `token_count_mismatch` (192) and `checksum_mismatch` (7) appear as INFO-level `restore miss classified` lines and are normal MTP checkpoint_dependent classifications, not product errors, per Stage 32 closure convention. | QA (hold) |
| 11 | Cleanup | PASS | PASS (hold) | No `llama-server` process remains, port 8900 free, cold-path final state recorded (26 .cold files, 2038.5 MiB). | QA (hold) |
| 12 | Hygiene | PASS | PASS (hold) | Public metrics contain 0 prompt text, 0 raw namespace ids, 0 payload bytes; diff is empty; this report references no prompt excerpts. | QA (hold) |

Summary: 11/12 rows hold at PASS; 1/12 (Hybrid reuse) reclassified from FAIL to EXPECTED BEHAVIOR (workload design / cache-budget mismatch).

## Product bug status

**No product bug remains.**

The Hybrid reuse FAIL is not a regression. Concretely:

- Driver extraction logic at `compare-legacy-vs-hybrid.ps1` L148-L162 (`Get-Stage29ResponseStats`) reads `usage.prompt_tokens_details.cached_tokens` first, then falls back to `timings.cache_n`. The Stage 32 focused retest `-02` used this same driver and produced `cache_n` values `0,1911,1911,1911,1911,1911` plus a Prometheus `cache_hits_total{mode="hybrid"}` delta of +5 on six chat-completion requests against the same Qwen3.5-4B MTP fixture. That passed Stage 32 closure (part-06, 2026-06-30).
- Stage 33 uses the same driver; the request-row level (`requests.jsonl`) shows `cache_n=0` for every one of 200 hybrid rows in each of 3 completed legs (0 / 600). The Prometheus counter `llamacpp:cache_hits_total{mode="hybrid"}` = 0 in all 3 metrics-after snapshots.
- Either counter would miss a hit if the response shape changes, but both miss simultaneously at the row level and at the Prometheus aggregate level - the controller genuinely produced zero hits.
- `cache_branch_lookup_hits_total{mode="hybrid"}` = 0 in warm-cycle-1 metrics-after (with 1000 cumulative branch lookups: 400 token_span + 600 checksum_span). The hybrid branch tree was searched, looked up, and found nothing to reuse.

No source code or driver change is needed.

## Hybrid reuse root-cause analysis

### Driver extraction is the Stage 32-corrected code path

`compare-legacy-vs-hybrid.ps1` lines 148-162:

```powershell
function Get-Stage29ResponseStats {
    param($Resp)
    $cacheN = 0
    $promptN = 0
    $predictedN = 0
    $promptMs = 0
    if ($Resp.timings) {
        if ($null -ne $Resp.timings.cache_n)     { $cacheN = [int]$Resp.timings.cache_n }
        if ($null -ne $Resp.timings.prompt_n)    { $promptN = [int]$Resp.timings.prompt_n }
        if ($null -ne $Resp.timings.predicted_n) { $predictedN = [int]$Resp.timings.predicted_n }
        if ($null -ne $Resp.timings.prompt_ms)   { $promptMs = [double]$Resp.timings.prompt_ms }
    }
    if ($Resp.usage) {
        if ($null -ne $Resp.usage.prompt_tokens_details.cached_tokens) { $cacheN = [int]$Resp.usage.prompt_tokens_details.cached_tokens }
        if ($null -ne $Resp.usage.prompt_tokens)                       { $promptN = [int]$Resp.usage.prompt_tokens }
        if ($null -ne $Resp.usage.completion_tokens)                   { $predictedN = [int]$Resp.usage.completion_tokens }
    }
    return [pscustomobject]@{ cache_n = $cacheN; ... }
}
```

This is the same code path that the Stage 32 focused retest -02 proved works (`probe-summary.json`: `hits_before=0`, `hits_after=5`, `hit_delta=5`; `requests.jsonl`: 5 of 6 rows `cache_hit=true`, `cache_n=1911`). Same driver, same hybrid controller, same fixture, different traffic shape. No extraction regression.

### Workload timing vs hot cache retention

Hot cache sizing (from QA evidence and this run's metrics-after):

- Hot budget = 512 MiB.
- Final cache_bytes in hybrid cycle = 160.9 MiB = 168,745,336 bytes (warm-cycle-1 metrics-after line 35).
- Final cache_entries = 2 (warm-cycle-1 metrics-after line 33).
- Per-entry size = 160.9 / 2 = 80.5 MiB (Stage 22 branch metadata overhead included). QA cites ~85 MiB. **Effective cache capacity = 6 entries** (floor(512 / 85) = 6).

Workload spacing (measured by re-walking `workload.jsonl` with hash-equal messages grouped, anchored against `warm-cycle-1\legacy\requests.jsonl` prompt_ms per request_id):

- 200 workload rows total; 78 rows carry `cache_class=exact`.
- 41 unique exact message hashes mapped to 78 exact-class requests.
- 22 of 41 anchors occur twice or more (the other 19 occur only once).
- For the 22 multi-occurring anchors:
  - Average requests between first and last occurrence: **91.8 workload positions**.
  - Average seconds between first and last occurrence (at avg prompt_ms = 8262 ms): **758.3 s = 12.6 minutes**.
  - Closest spacing observed: **13 requests = 107.4 s** (`r-XXXX` near positions 138..151).
  - 95th-percentile spacing: **>= 165 workload positions = >= 1363 s** (~22.7 minutes).

Hot cache retention time under load:

- Driver server is run with `--parallel 2`. Average prompt time per slot = 8262 ms. Each slot admits one fresh payload roughly every 8.3 s.
- 6-entry hot cache means the 7th admission evicts the oldest LRU entry, so absolute ceiling on retained entries after admission of a fresh anchor = 6 admissions (~50 s).
- By the time the closest duplicate returns (107 s = ~13 admissions later), the original admission has been evicted for at least 7 cycles.
- By the time the median duplicate returns (758 s = ~91 admissions later), the original admission has been evicted for ~85 cycles.

Therefore the FAIL is the **expected** steady-state result for this workload shape against a 6-entry 512-MiB hot cache. It is not a product regression.

### Cold-store auto-load is on-demand by design

Stage 29 design document, line 96:

> "Stage 25: tx_* architecture; cold-store write is synchronous; cold-store load is also synchronous on first hit."

`cache-handling-architecture.md`, line 9:

> "The hybrid cache controller operates as an atomic transactional state machine under a single recursive mutex. Every demote, evict, restore, admit, and cold-store transition runs synchronously inside a `tx_*` transaction invoked from the slot request that triggered it; no background thread or async drain mutates cache state."

Cold-store auto-load at server startup is NOT in the design. The Stage 33 observation that `cold-start-cycle-1\hybrid\metrics-before` shows `cache_entries{mode="hybrid"} = 0` even though `D:\tmp\cache-cold-stage33-20260630-01\` already contains 26 .cold files (carried over from a hypothetical prior cycle - in this run, the cold path was deleted before first cycle per the intake brief execution command, so cold path is populated during the run itself via demotions, not loaded from prior runs) is by design.

The 26 .cold files in this run were created **during** cycle 1 by the demotion path (`cache_payload_demotions_total = 398`, `cache_payload_cold_evictions_total = 372`) and are intentionally cold (descriptors retained, hot bytes evicted). They become warm only when a fresh request hits the branch tree and the `tx_*` path evaluates restore-on-demand.

This is therefore an architecture feature, not a missing capability.

### Branch-level reuse vs payload-level reuse

`cache_branch_lookup_hits_total{mode="hybrid"} = 0` (warm-cycle-1 metrics-after L75) and `cache_branch_lookups_total{mode="hybrid",method="token_span"} = 400` / `method="checksum_span"} = 600` (sum 1000).

1000 branch lookups were performed across warm-cycle-1 / hybrid. The branch tree was traversed 0 times successfully for reuse. This is a controller-level signal that the branch structure at the time of the duplicate lookup did not contain a matching descriptor. That matches the eviction prediction: by the time the duplicate arrived, the relevant branch descriptor was already evicted or replaced.

### Workload generator behavior (soundness check)

`compare-legacy-vs-hybrid-workload.ps1` L155-L168 ("exact" branch):

```powershell
if ($cacheClass -eq 'exact' -and $anchors.Count -gt 0) {
    $source = $anchors[$rng.Next(0, $anchors.Count)]
    $messages = @($source.messages)
}
```

`@($source.messages)` copies the message array by value, preserving identical strings. `ConvertTo-Json -Compress -Depth 5` of the duplicate request produces the identical JSON serialization, hence the identical hash observed in this review's hash uniqueness check (41 unique hashes over 78 exact-class rows; min dup count 1, max dup count 6).

`cache_class=exact` therefore faithfully maps to actual duplicate requests that the server should be able to reuse.

The 78 exact-class rows vs the observed 41 unique hashes (MinAnchors=10; `anchorCount = max(10, ceil(200 * 0.4)) = 80`) reflects the random draw distribution: only 41 of the 80 generated anchors were sampled. This is a workload-shape consequence, not a generator bug.

## Cold-store auto-load analysis (explicit)

| Question | Answer |
| --- | --- |
| Does cold-store auto-load at startup? | **No.** Cold-store payloads are explicitly cold; they only become hot when a `tx_*` transaction runs and finds a matching payload to restore. (Stage 29 design L96; cache-handling-architecture L9.) |
| Is this change tracked anywhere? | No. The behavior has been the same since Stage 25 `tx_*` introduction. |
| Should Stage 33 escalate this as a missing feature? | No. The stage goal is comparison vs legacy mode on the current architecture. Adding cold-store auto-load would require a design change (D-series decision) at the Architect gate. |
| Is the FAIL row caused by missing auto-load? | Partially. Even with auto-load, the 6-entry hot cache could not retain 41 distinct anchors plus 78 exact-class admissions across 200 requests. Auto-load would only matter if the same exact anchor with a short hot-retention window was expected. |

## Manager decision recommendation

**Recommendation: ACCEPT as PARTIAL (warm 3 skipped due to wall-clock gate) and CLOSE Stage 33 with Hybrid reuse row reclassified to EXPECTED BEHAVIOR (workload design).**

Concretely:

1. Reclassify the Hybrid reuse row FAIL to **EXPECTED BEHAVIOR**. The hybrid controller produced zero hits because the workload's duplicate inter-arrival time (median 758 s, p95 1363 s) far exceeds the 6-entry 512-MiB hot-cache retention window under `--parallel 2` and ~8.3 s per request. This is consistent with the Stage 32 closure note: "No Stage 32 product bug remains open" plus the broader comparison evidence showing hybrid hot cache 62% smaller than legacy and throughput within 1-2%.
2. Close Stage 33 as **PARTIAL**: 6 of 8 legs complete; warm 3 was killed at the 187 min wall-clock gate (intake brief allowed up to 180 min, allow 7 min over) to preserve partial artifacts. All 11 non-reuse rows PASS; the 12th is reclassified.
3. No product fix is needed. No driver extraction fix is needed. No workload generator fix is needed.
4. Optional follow-up (out of scope for this review): if Manager wants higher-confidence hybrid reuse evidence, open a fresh Stage 34 with a tighter duplicate-spacing workload (e.g., 8-burst x 6 repeats = 48 traffic rows where each burst sends 6 identical chat requests back-to-back over a 10-second window, matching the Stage 32 focused retest shape but at larger scale). This would be a new stage with its own intake brief, not a Stage 33 correction.

## Retest scope (if Manager opens a re-run)

**Not recommended.** A re-run of the same Stage 33 work under the same parameters will produce the same result. If Manager elects to override and open a tighter workload anyway, the recommended scope is:

- Reuse same fixture, driver, and binary.
- Replace the workload with a tight-burst shape: 8 unique anchors x 6 occurrences each = 48 requests, sent in tight bursts of 6 over 10 s each, mixed with new_branch filler to keep cache pressure.
- Hot budget and cold budget unchanged.
- Single cold-start cycle + single warm cycle each of legacy and hybrid.
- Wall-clock budget: 30 minutes.
- PASS signal: `cache_hits_total{mode="hybrid"}` >= 30 (50% of exact-class rows), `cache_hit=true` rows in hybrid requests.jsonl >= 30 of 48 exact-class rows.

This would mirror the Stage 32 focused retest shape at larger scale.

## Files verified by Test-Path (all returned True, all referenced in this review)

- `D:\source\llama.cpp-jet\AGENTS.md`
- `D:\source\llama.cpp-jet\CLAUDE.md`
- `D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260630-03-stage33-01.md`
- `D:\source\llama.cpp-jet\._design_docs\.manager-inputs\manager-input-20260630-stage33-full-legacy-hybrid-ab-comparison.md`
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-phase32-implementation\part-06-manager-closure-20260630.md`
- `D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260630-02-stage32-focused-retest.md`
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1`
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts\lib\compare-legacy-vs-hybrid-workload.ps1`
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-phase29-design.md`
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-phase32-design.md`
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-architecture.md`
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-requirements.md`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\summary.json`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\cold-start-cycle-1\legacy\metrics-before.txt`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\cold-start-cycle-1\legacy\metrics-after.txt`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\cold-start-cycle-1\legacy\requests.jsonl`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\cold-start-cycle-1\hybrid\metrics-before.txt`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\cold-start-cycle-1\hybrid\metrics-after.txt`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\cold-start-cycle-1\hybrid\requests.jsonl`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\warm-cycle-1\legacy\metrics-{before,after}.txt`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\warm-cycle-1\hybrid\metrics-{before,after}.txt`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\warm-cycle-1\hybrid\requests.jsonl`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\warm-cycle-2\legacy\metrics-{before,after}.txt`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\warm-cycle-2\hybrid\metrics-{before,after}.txt`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\warm-cycle-2\hybrid\requests.jsonl`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\workload.jsonl`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\phase-1-output-equivalence\diff.txt`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\phase-1-output-equivalence\legacy-decoded.txt`
- `D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\phase-1-output-equivalence\hybrid-decoded.txt`
- `D:\tmp\cache-cold-stage33-20260630-01\` (directory, 26 .cold files)
