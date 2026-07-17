# Part 81: TP-39-03 fault common-epilogue implementation evidence

Date: 2026-07-14
Status: BLOCKED
Authority: D39-EXEC-18

## Root cause and corrections

The original midpoint failure came from fixture sizing, not fault order. Both
natural fixtures set the cold budget from the checkpoint component alone. The
exact prepared object is larger, so step 1 correctly latched
`prepared_boundary_abort` before the midpoint hook. The fixtures now use the
larger component plus the cold header. This satisfies
`max(S_exact, S_checkpoint) <= C_low < S_exact + S_checkpoint`.

Focused execution exposed two guarded seam defects after that correction:

- authenticated retrieval copied the failed terminal status into the control
  operation result, so valid failed proofs could never be retrieved; retrieval
  now succeeds as an operation and returns the frozen failed snapshot;
- the step-2 prepared flag was set after the injected return; it now records
  successful preparation before the step-2 fault is latched.

Route fixtures also omitted workload admission and used `proof_payload_ids`
instead of the route schema's `payload_ids`. Both are corrected. All changes
remain under the guarded Stage 39 seam or in its focused fixtures. Seam-OFF
production behavior is unchanged.

## Changed files

- `tools/server/server-cache-hybrid.cpp`
- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_stage39_live_pressure.py`
- this evidence part, the implementation entry, and `document-index.md`

## Evidence

Focused Release builds:

```text
cmake --build build-stage39-seam-on --config Release --target test-cache-controller --parallel 2
PASS
cmake --build build-stage39-seam-on --config Release --target llama-server --parallel 2
PASS
```

The rebuilt controller ran its full registered suite because it has no name
filter. Both required cases passed and the process exited 0:

```text
test_stage39_live_pressure_prepared_proof_midpoint_fault_common_epilogue: PASS
test_stage39_live_pressure_prepared_proof_step2_fault_common_epilogue: PASS
All tests passed successfully!
exit code: 0
```

Exact route command:

```text
LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1
python -m pytest -q \
  tools/server/tests/unit/test_stage39_live_pressure.py::test_live_pressure_prepared_proof_midpoint_fault_coherent_terminal \
  tools/server/tests/unit/test_stage39_live_pressure.py::test_live_pressure_prepared_proof_step2_fault_coherent_terminal
```

Final result: 2 failed in 12.34 seconds. Workload admission and proof schema
both succeeded, but each proof contained only `exact_blob`; the tests require
`["exact_blob", "checkpoint"]`. Server logs identify the fixture as degraded
plain-transformer metadata. This local Qwen completion workload does not create
the required same-owner checkpoint payload.

No canonical live TP-39-03 run, coverage, full QA, commit, or push occurred.

## Verdict and next gate

D39-EXEC-18 remains BLOCKED only on the two route fixtures. The controller
midpoint and step-2 cases pass. A reviewed checkpoint-capable route workload or
fixture is required before rerunning the same two node IDs. Fresh Architect
implementation review remains blocked until both route tests pass.
