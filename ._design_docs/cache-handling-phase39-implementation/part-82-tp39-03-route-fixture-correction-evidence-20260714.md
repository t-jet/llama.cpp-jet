# Part 82: TP-39-03 route fixture correction evidence

Date: 2026-07-14
Status: HISTORICAL BLOCKER; RESOLVED BY DESIGN PART 45
Authority: D39-EXEC-18

## Scope

This session examined only the two failed D39-EXEC-18 route fixtures. It did
not change product code, guarded route code, test code, or Part 81 history.

## Root cause

`Stage39Server` starts the default `Qwen3-0.6B-Q8_0.gguf` fixture without MTP
or checkpoint startup options. `admit_inventory()` sends six plain completion
requests. Discovery therefore returns eligible exact payloads, but the proof
operation returns only `exact_blob` for the selected owner. The required
natural same-owner pair is absent before either fault apply runs.

The test helper comment assumes a checkpoint-capable fixture but does not
create one. Its fallback wording also says the route may skip, while the live
assertion correctly requires the exact ordered pair
`["exact_blob", "checkpoint"]`. Both tests fail at that assertion. Fault
handling is not reached.

## Approved fixture audit

Repository route tests contain no existing helper that admits a natural
same-owner exact and checkpoint pair. Controller tests create the pair through
guarded internal setup, but that synthetic setup cannot prove the route's
natural workload contract.

Implementation Part 62 defines the only approved checkpoint-capable workload:
the Qwen3.5-4B-MTP model, `--ctx-checkpoints 32`,
`--checkpoint-min-step 0`, context 8192, the chat template, and literal long
requests. Parts 62 and 69 require runtime capability, admission, span,
compatibility, file, and accounting preflight. Replacing the route fixture
with that model and workload would add model-backed execution and preconditions
outside Part 80's bounded route-fixture authorization. A shortened MTP prompt
or newly synthesized checkpoint would invent an unreviewed workload or weaken
the natural same-owner requirement.

## Evidence

Part 81 remains the last execution result:

```text
test_live_pressure_prepared_proof_midpoint_fault_coherent_terminal: FAIL
test_live_pressure_prepared_proof_step2_fault_coherent_terminal: FAIL
2 failed in 12.34 seconds
```

Both failures occur because proof rows equal `["exact_blob"]`. The controller
pair remains PASS. This session did not rerun either route node because no
authorized fixture correction was available.

## Verdict and next gate

D39-EXEC-18 remains blocked at execution, but its fixture design blocker is
closed by design Part 45 and implementation Part 83. They approve bounded use
of Part 62's MTP source admission for the two node IDs, with exact startup,
literal request, isolated processes, caps, and fail-closed preflight. Manager
approval is next before Developer changes the helper or runs the model-backed
pair.

Canonical live TP-39-03, coverage, full QA, commit, and push remain blocked.
