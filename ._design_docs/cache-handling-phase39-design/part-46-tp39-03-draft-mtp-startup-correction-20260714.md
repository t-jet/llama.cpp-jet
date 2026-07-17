# Part 46: TP-39-03 draft-MTP startup correction

Date: 2026-07-14
Status: ARCHITECT PASS; MANAGER GATE NEXT
Scope: D39-EXEC-19 route fixture startup and preflight only

## Finding

Design Part 45 copied Part 62's startup list but omitted the option that selects
the capability both documents require. `common_params_speculative::types`
defaults to `COMMON_SPECULATIVE_TYPE_NONE`. `common/arg.cpp` registers
`--spec-type`, maps the value `draft-mtp`, and appends
`COMMON_SPECULATIVE_TYPE_DRAFT_MTP`. `server-context.cpp` creates the target
model's MTP draft context only when that type is present.

The two Part 85 roots confirm the omission. Both commands lack `--spec-type`.
Both admitted the 5,687-byte request, created three target checkpoints, kept the
cold root empty, and stopped before apply. Their save records report
`dft: 0.000`; their preflight results name the three missing MTP records.

## Corrected startup contract

Part 45's fixture contract is superseded only by adding this pair after the
chat-template option:

```text
--spec-type draft-mtp
```

All other Part 45 arguments, literal bytes, process isolation, budgets, caps,
and forbidden fallbacks remain unchanged. Do not add `--spec-draft-model`, use
`--mtp`, set `LLAMA_ARG_SPEC_TYPE`, change draft limits, or change fit policy.
The selected fixture embeds one NextN layer, so no separate draft model is
needed.

This is sufficient for runtime selection. It activates the existing no-separate-
draft branch in `server-context.cpp`, which creates `LLAMA_CONTEXT_TYPE_MTP`,
binds target and draft contexts, and lets `common_speculative_init()` install
`draft-mtp`. The existing 16 GiB RSS and 20-minute caps remain fail-closed and
provide headroom beyond Part 85's roughly 5.33 GiB and 198-second maxima.

## Corrected preflight

Before admission, write `command.json` and assert that the argv contains exactly
one adjacent `--spec-type`, `draft-mtp` pair. After admission, preserve every
Part 45 check and also require:

1. startup records the MTP context, bounded partial sequence removal,
   `draft-mtp`, checkpoint settings, and checkpoint creation;
2. the source save reports a positive draft component, not `dft: 0.000`;
3. both proof rows report positive target and draft component sizes, checked
   resident aggregation, and `runtime_pair_matches=true`;
4. discovery, repeated proof, metrics, generation, files, and one-shot state
   remain unchanged before apply.

Any failure uses the existing fixed `BLOCKED-route-fixture-*` result and stops
before apply. No capability check may be weakened or changed into a skip.

## Rerun contract

After a Manager gate, change only the dedicated `Stage39MTPServer` command and
the coupled assertions above. Run sequentially from fresh processes and roots:

```text
tools/server/tests/unit/test_stage39_live_pressure.py::test_live_pressure_prepared_proof_midpoint_fault_coherent_terminal
tools/server/tests/unit/test_stage39_live_pressure.py::test_live_pressure_prepared_proof_step2_fault_coherent_terminal
```

Each node retains one model process, one slot, one chat request, one apply,
20-minute wall, 16 GiB RSS, and 4 GiB cold-root caps. Acceptance remains exactly
`2 passed, 0 failed, 0 skipped`. Preserve both new artifact roots. Do not run a
build, another route node, canonical TP-39-03, coverage, or full QA in this gate.

## Supersession and handoff

This part supersedes only Part 45's startup list and its inherited Part 62
omission. Part 85 remains historical fail-closed evidence. Product code, route
schema, fixture identity, literal request, budgets, pressure behavior, and fault
assertions do not change.

Architect verdict: PASS for the narrow correction. Next owner: Manager. Next
gate: authorize the helper-only correction and exact two-node rerun.
