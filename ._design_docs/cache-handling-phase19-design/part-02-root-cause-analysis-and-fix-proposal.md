# Stage 19 design part 2: root cause analysis and fix proposal

Status: authored; pending Architect design review
Date: 2026-06-18
Stage: 19 (System-Level Model Warmup Crash Investigation)
Source: [entry doc](../cache-handling-phase19-design.md)

## Root cause analysis approach

If the reproduction crashes, the root cause analysis proceeds in three
steps. Each step has a read-only verification command before concluding.

### Step 1: Confirm validation block does not run on baseline

Verification: with the binary at HEAD, run `Select-String` on
`tools/server/server-context.cpp` to confirm the gate is at line 1242
and the block runs only when `cache_ram_mib != 0`.

```text
Select-String -Path tools/server/server-context.cpp -Pattern 'if \(params_base.cache_ram_mib != 0\)'
```

Expected: exactly 1 match (the validation block at line 1242; the
duplicate at post-slot-init 1554-1557 was deleted in Stage 18 Item 1).

Conclusion: baseline path with default `cache_ram_mib = 0` skips the
validation block. The Stage 18 fix cannot affect this path. Any baseline
crash is independent of the validation block ordering.

### Step 2: Locate the crash site in `load_model`

Verification: in the reproduction run `server.err.log`, find the LAST
log line before the abrupt exit. Compare against the source structure
of `load_model`:

- Line 1108: function entry, `SRV_INF("loading model '%s'...")`
- Lines 1112-1138: `mtmd_context_params` setup
- Lines 1140-1163: optional `mmproj` memory usage
- Lines 1165-1241: optional `fit_params` and `has_draft || spec_mtp` measurement
- Lines 1242-1291: cache validation block (Stage 18)
- Line 1292: `llama_init = common_init_from_params(params_base)` (warmup)
- Lines 1293-1306: model and context extraction
- Lines 1308-1370: optional `model_dft` and `ctx_dft` init
- Lines 1372-1400: optional `mctx` (multimodal) init
- Lines 1402-1410: optional ctx_shift / n_cache_reuse adjustments
- Lines 1412-1416: optional swa_full adjustment
- Lines 1418-1430: speculative decoding init (slot init preamble)
- Lines 1432-1500: slot loop, `slot.reset()`
- Lines 1502+: post-slot-init cache controller creation, metrics, JSON load

Crash site candidates (Stage 17 evidence: crash at ~2.5 seconds,
between slot init preamble and slot loop):

| Site | Lines | Function | Hypothesis |
| --- | --- | --- | --- |
| `common_init_from_params` | 1292 | warmup path | probable; warmup + slot init window |
| `model_dft` init | 1310-1341 | draft model load | unlikely (no draft model flag in baseline) |
| `ctx_dft` init (MTP path) | 1342-1366 | MTP context | unlikely (no speculative flag in baseline) |
| `mctx` init | 1372-1387 | multimodal | unlikely (no mmproj flag in baseline) |
| `slots.emplace_back()` | 1442 | slot creation | possible (slot init window) |
| `slot.reset()` | 1497 | slot state reset | possible (last stage before crash per Stage 17 evidence) |

### Step 3: Distinguish environmental from code-related

Verification: collect system-state evidence at reproduction time:

- `Get-Process` baseline working set of `llama-server.exe`
- Total system available memory (`Get-CimInstance Win32_OperatingSystem`)
- `fit_params` projection value in `server.err.log` (Stage 17 evidence:
  9933 MiB vs original 1466 MiB)

If `fit_params` projection is high (>5000 MiB) AND system available
memory is below projection, classify as Branch B (environmental).
Otherwise classify as Branch A (code-related) and inspect the specific
crash site for stack-overrun patterns.

## Fix proposal

The design includes a minimal conditional fix proposal that the
Developer session can apply if Branch A is selected. Branch B and Branch
C do not require code changes.

### Branch A fix (conditional)

If the crash site is in the slot init preamble (Step 2 candidates), the
fix mirrors the Stage 18 style:

1. Move the speculative decoding init and `slots.emplace_back()` loop
   into a guarded block that runs only after `model_tgt != nullptr` and
   `ctx_tgt != nullptr` AND
   `llama_memory_can_shift(llama_get_memory(ctx_tgt))` returns success.
2. Replace any `throw std::runtime_error` in the slot init preamble
   with `return false` so `load_model()` exits with code 1 instead of
   crashing.
3. Add SRV_ERR log lines BEFORE the crash-prone step with bounded
   message (no stack trace dump, no internal state, no raw pointers).

The exact fix depends on the Step 2 crash site evidence. The Developer
session proposes a concrete implementation plan in a follow-up part
file.

### Branch B fix

No code fix. Document environmental trigger in the Stage 19 closure
follow-up. Surface as new separate stage (Stage 19 follow-up or Stage
21).

### Branch C fix

No fix needed. Stage 19 closes with no-reproduction evidence. The
Stage 18 fix is sufficient.

This file uses LF line endings, plain ASCII status labels, and stays under
the 300-line durable doc cap.
