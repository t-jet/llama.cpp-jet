# R28-BUG-02 cold-store drift diagnosis (Stage 28 iter 1, Step 3)

Date: 2026-06-26
Author: Developer (diagnosis, Step 3)
Source data: Stage 24 -07 S02 hybrid leg cold store
at `D:\tmp\cache-cold-stage27-fix\stage24-chat-s02-s03-20260626-07\S02-chat\hybrid-stage24\`
Status: diagnosis complete; fix shape identified; fix in Step 4

## Empirical measurement (BEFORE fix)

### Filesystem bytes vs metric

| Source | Value | Files | Notes |
| --- | ---: | ---: | --- |
| Filesystem bytes | 5,374,544,424 (5,125.56 MiB) | 102 | all 52,691,612 bytes (50.25 MiB) each |
| `n_cold_payload_bytes` metric | 526,915,480 (502.5 MiB) | n/a | reported by server `/metrics` cache_cold_bytes |
| Per-id map sum (estimated) | 502.5 MiB | 10 | 10 entries x 50.25 MiB = 502.5 MiB |
| Drift ratio (fs / metric) | 10.2x | n/a | 92 files unaccounted-for |
| Orphan count (files - map entries) | 92 | n/a | files on disk with no per-id map entry |

### Per-id map state

The per-id map `cold_payload_bytes_by_id_` had 10 entries. The cold
store directory had 102 files. So 92 files on disk have NO entry in
the per-id map. The 92 files are permanent orphans unless the
controller reconciles them (it does not, today).

### File naming

All 102 .cold files use the format `<hex>.cold` (e.g., `1e.cold`,
`1c.cold`, `1a.cold`, `552.cold`, `12.cold`). The hex value is the
cold_ref which equals the payload_id (per `server-cache-store-cold.cpp`
write() line 144 `ref = payload_id`). File names are stable for the
lifetime of the file (no temp/rename visible in the file list).

The 10 in-map ids and 92 orphan ids cover disjoint sets of hex
payload_id values. The orphan files were written by the controller
but the per-id map insert was either skipped (write-without-map) or
erased (delete-without-map).

## Source-tree analysis: which orphan-file path is producing this?

The candidate orphan-file paths from design part-02 are:

- **Candidate A: early-continue in `cold_budget_make_room` (line 641)**.
  Code path (cpp):

  ```cpp
  if (!cold_store.remove(it->second.store_ref.id)) {
      continue;  // <-- Candidate A
  }
  ```

  If `cold_store.remove` returns false, the loop `continue`s and
  the per-id map entry stays. The file stays on disk. So the file
  and the map entry stay in sync. The file is NOT an orphan (map
  has the entry); the leak is the budget cannot drain. **This
  candidate does NOT produce orphan files.** (It would produce
  the inverse: file on disk, map entry present, metric matches
  disk.)

- **Candidate B: write-without-map**. Code path: any call to
  `cold_store.write()` that does not flow through
  `complete_demoted_payload` (line 698-712). Search of
  `server-cache-hybrid.cpp` shows exactly ONE caller of
  `cold_store.write`: the `io_worker.process_demotion()` function
  in `server-cache-io-worker.cpp`, invoked from the completion
  handler in `hybrid_cache_controller::handle_demotion_completion`.
  The completion handler always invokes `complete_demoted_payload`
  on success, which inserts into the per-id map. No
  write-without-map path exists in the production code. **This
  candidate does NOT produce orphan files.**

- **Candidate C: cleanup-loop delete-without-map**. Code path: the
  `update()` cleanup at lines 977-1000. The bug (cpp):

  ```cpp
  size_t n_deleted = cold_store.delete_ids(cold_to_delete);
  if (n_deleted > 0) {
      ...
      for (uint64_t id : cold_to_delete) {
          auto bytes_it = cold_payload_bytes_by_id_.find(id);
          const size_t removed_bytes = bytes_it != ... end() ? ... : 0;
          if (removed_bytes > 0 && n_cold_payload_bytes >= removed_bytes) {
              n_cold_payload_bytes -= removed_bytes;
          } else if (removed_bytes > 0) {
              n_cold_payload_bytes = 0;
          }
          cold_payload_bytes_by_id_.erase(id);  // <-- UNCONDITIONAL ERASE
      }
  }
  ```

  The per-id map is erased for ALL ids in `cold_to_delete`, even
  the ones that `delete_ids` did NOT actually delete. When
  `n_deleted < cold_to_delete.size()`, the descriptors are
  retained for retry (line 996-1000), but the per-id map entries
  are already gone. On the next cleanup pass the file is still
  on disk, the descriptor is still present (cold residency, not
  referenced by any branch), and the per-id map erase is a no-op
  (already empty). The file remains as a permanent orphan.
  **This candidate DOES produce orphan files.**

- **Candidate D: `remove_payload` cold path unconditional erase**
  (line 3320-3338). Code path (cpp):

  ```cpp
  cold_store.remove(descriptor_it->second.store_ref.id);  // return ignored
  if (n_cold_payload_bytes >= cold_bytes) {
      n_cold_payload_bytes -= cold_bytes;
  } else {
      n_cold_payload_bytes = 0;
  }
  cold_payload_bytes_by_id_.erase(payload_id);  // <-- UNCONDITIONAL ERASE
  ```

  If `cold_store.remove` returns false (file still on disk), the
  per-id map is erased anyway, then `payload_descriptors.erase(id)`
  is called. The descriptor is gone, the file is still on disk.
  **This candidate also produces orphan files**, but is
  triggered only by eviction (not the regular cleanup path).

## Root cause

**Candidate C (cleanup-loop delete-without-map) is the primary
orphan source.** With high eviction churn on the MTP fixture (each
save at cold residency triggers cleanup), even one transient
`delete_ids` partial failure (Windows file lock, AV scan, in-flight
renaming) leaves a permanent orphan. The 92 orphan files in the
S02 cold store accumulate over hundreds of eviction cycles.

**Candidate D (remove_payload cold path) is the secondary orphan
source**, triggered by cold-resident descriptor removal via
eviction. Smaller impact in the S02 log because the eviction path
typically finds `residency == demoting` or `residency == hot`,
not `residency == cold`.

## Fix shape

### Fix 1 (Candidate C primary): re-order the cleanup loop

Modify `update()` lines 977-1000 to:

1. Call `cold_store.remove(id)` per id, check return value.
2. Only erase the per-id map and decrement the metric for ids
   that were actually deleted.
3. For ids whose file delete failed, retain the descriptor and
   per-id map entry for the next cleanup pass (consistent with
   the existing "descriptors retained for retry" warning path).

### Fix 2 (Candidate D secondary): gate the cold path on success

Modify `remove_payload` lines 3320-3338 to:

1. Only erase the per-id map and decrement the metric if
   `cold_store.remove(...)` returned true.
2. If the remove failed, retain the descriptor and the per-id
   map entry. Skip `payload_descriptors.erase(id)` so the
   cleanup loop can retry the file deletion.

### Fix 3: add TP-28-UT-01 regression test

Add a focused test in `tests/test-cache-controller.cpp` that
drives the cold-cleanup path with a stubbed `cold_store.remove`
that returns false, and verifies the per-id map and metric
remain consistent with the file (file on disk, map entry
present, metric bytes present).

## Estimated fix size

| File | Lines | Notes |
| --- | ---: | --- |
| `tools/server/server-cache-hybrid.cpp` `update()` | +20 / -10 | re-order cleanup loop |
| `tools/server/server-cache-hybrid.cpp` `remove_payload` | +5 / -3 | gate erase on remove success |
| `tests/test-cache-controller.cpp` TP-28-UT-01 | +50 / -0 | focused regression test |
| `._design_docs/.test_reports/test-report-20260627-cold-store-diag.md` | new file | this report |
| Total | +75 / -13 | net +62 lines |

## Verification approach

- V1 fix on disk: Select-String verifies the gated erase at the
  named lines.
- V2 clean build: `cmake --build build-cuda --config Release
  --target llama-server --target test-cache-controller` exits 0.
- V3 TP-28-UT-01 PASS: new test drives the cold-cleanup
  invariant after the fix.
- V4 Stage 24 rerun S02 hybrid (out of scope for this session;
  handled by Manager gate): filesystem bytes == per-id map sum
  == n_cold_payload_bytes metric (within rounding).

## Artifacts

| Path | Description |
| --- | --- |
| `D:\tmp\cache-cold-stage27-fix\stage24-chat-s02-s03-20260626-07\S02-chat\hybrid-stage24\*.cold` | 102 .cold files, 5.37 GiB total |
| This report | `._design_docs/.test_reports/test-report-20260627-cold-store-diag.md` |

## Hard constraints honored

- No production code modified in Step 3 (diagnosis only).
- Step 4 fix is the only production-code change for R28-BUG-02.
- ASCII only, LF endings, no BOM, no trailing whitespace.
