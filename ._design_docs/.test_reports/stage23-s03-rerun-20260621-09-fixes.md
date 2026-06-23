# Stage 23 S03 rerun 20260621-09 fix

Status: ready for Architect review
Date: 2026-06-21
Owner: Developer
Bug: F-23-S03-RERUN09-01

## Scope

Focused product fix for the S03 CUDA large-branch-forest crash under 512 MiB
hot and cold budgets. No public flags, public schemas, or metric names changed.
Full CUDA S03 rerun is still QA-owned after Architect review.

## Root cause

The crash report was a real product access violation, not setup failure.
Windows Application Error recorded exception `0xc0000005` in
`llama-server-impl.dll` at fault offset `0x00000000001f0bf1`.

Local symbolization with the matching `llama-server-impl.pdb` resolved the RVA
to:

```text
hybrid_cache_controller::attach_checkpoint_payload
tools/server/server-cache-hybrid.cpp:3615
```

That line reads `source_metadata->boundaries` while selecting checkpoint
boundary metadata. The S03 log showed this crash only after hot-budget pressure:
older demotions were still completing while newer payloads were rejected by the
demotion budget and evicted immediately. That pressure path led to repeated
checkpoint admission during re-materialized saves.

The immediate lifetime bug was the checkpoint attach path keeping a pointer to
entry metadata while the same operation attached a new payload and updated owner
state. Under the pressure/re-materialization path, the optimized build could
read boundary data through that aliased pointer at the crash site. The fix takes
a local metadata snapshot before payload attach and uses that stable snapshot
for boundary selection and descriptor validation.

## Code changes

- `tools/server/server-cache-hybrid.cpp`
  - `attach_checkpoint_payload` now copies the effective metadata into a local
    `metadata_snapshot` before `attach_payload` mutates payload ownership.
  - Checkpoint boundary selection and validation now use the snapshot pointer.

- `tests/test-cache-controller.cpp`
  - Added `test_stage23_demotion_budget_fallback_stale_completion_checkpoint_attach`.
  - The regression queues an older demotion, forces a second payload through
    demotion-budget rejection and immediate eviction, drains the older demotion
    completion, then admits a checkpoint on the evicted-owner entry.
  - Registered the test and updated the printed total to 120 tests, with 8
    Stage 23 focused tests.

## Evidence

Commands run:

```text
cmake --build build-cov --config Release --target test-cache-controller -j 4
.\build-cov\bin\Release\test-cache-controller.exe
cmake --build build-cov --config Release --target llama-server -j 4
```

Results:

- `test-cache-controller` build: PASS.
- `test-cache-controller.exe`: PASS, 120/120 tests.
- New regression line: `Stage 23 demotion budget fallback stale completion checkpoint attach... PASSED`.
- `llama-server` build: PASS.

Binary freshness after builds:

```text
test-cache-controller.exe  2881536   2026-06-21 16:00:42
llama-server.exe             13312   2026-06-21 16:01:00
llama-server-impl.dll     14636032   2026-06-21 16:01:00
```

Crash triage evidence:

```text
Get-WinEvent Application 2026-06-21 14:20..14:25
llvm-symbolizer --obj=build-cov\bin\Release\llama-server-impl.dll 0x1801f0bf1
```

Result: Application Error `0xc0000005`; symbolized frame
`attach_checkpoint_payload`, `server-cache-hybrid.cpp:3615`.

## Risk

Risk is low. The patch changes only local metadata lifetime inside checkpoint
payload attachment. It does not alter restore ranking, eviction policy, cold
budget math, public metrics, or request behavior. Remaining risk is that S03 may
still expose a second pressure bug after this crash is removed; QA must rerun
the focused CUDA row to prove that.

## Retest scope

Next retest after Architect review:

- Rebuild `test-cache-controller` and `llama-server` in `build-cov` Release.
- Run `test-cache-controller.exe`.
- Run one focused CUDA S03 rerun with the same shape as report 09:
  Qwen3.5-4B-MTP, `--cache-mode hybrid`, `--cache-ram 512`,
  `--cache-cold-max-mib 512`, redacted prompt evidence, `--n-gpu-layers all`,
  `--fit off`, fresh cold path, fresh output root.
- Require no crash, `metrics-after.txt`, redacted prompt evidence, bounded cold
  budget behavior, and S03 row behavior evidence before resuming S04..S08 or
  L01..L03.

## Handoff

Next owner: Architect.

Architect should review the narrow metadata-snapshot fix, the symbolized root
cause, and the focused regression. QA owns the CUDA S03 rerun only after
Architect approval. Stage 23 remains stopped at S03.
