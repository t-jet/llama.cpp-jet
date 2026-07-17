# Part 89: Architect D39-EXEC-20 implementation review

Date: 2026-07-14
Verdict: REWORK, NARROW CORRECTION READY
Scope: D39-EXEC-20 implementation, Part 88, and preserved midpoint artifact

## Review result

D39-EXEC-20 did not reach implementation acceptance. The helper selected
`draft-mtp`, enforced the approved command, admitted the fixed request, stayed
inside all caps, and failed before apply. Runtime capability is proven. The
remaining blocker is a mismatch between binding trace literals and default
verbosity, not a model, product, or fixture failure.

Design Part 47 is the complete correction. Its explicit trace setting is less
intrusive than changing product logs or replacing direct capability evidence.

## Evidence

The preserved root
`._test_output/stage39-route-fixture/exec20-midpoint/midpoint-fault-1783980035334949200-32204`
contains `command.json`, the 5,687-byte request, response, resource samples,
log, and failed preflight result; it has no apply artifact. The command has one
`--spec-type draft-mtp` pair. The log records:

- MTP context creation and speculative context initialization;
- target 164.758 MiB and draft 14.375 MiB at save;
- draft acceptance of 19 out of 33 tokens;
- checkpoint settings and production checkpoint creation;
- 5,588,398,080 maximum RSS bytes, 92.782 seconds, and zero cold bytes.

`common/common.cpp` emits bounded partial sequence removal with `COM_TRC`.
`common/speculative.cpp` emits installed `draft-mtp` with `SPC_TRC`.
`common/log.h` assigns trace level 4; `common_params::verbosity` defaults to 3.
`common/arg.cpp` registers `--log-verbosity 4` and
`LLAMA_ARG_LOG_VERBOSITY`. The CLI is therefore exact and supported.

## Required correction and safeguards

Under a new Manager gate, add only `--log-verbosity 4`, its exact one-pair
pre-start assertion, and the 64 MiB server-log cap to `Stage39MTPServer`.
Retain every preflight assertion enumerated in design Part 47. Do not change
product log levels, use verbose/debug mode, set the environment override,
remove a capability literal, or run another workload.

Rerun only the midpoint and step-2 route nodes, sequentially with fresh isolated
state. Acceptance is `2 passed, 0 failed, 0 skipped`; any failed preflight or
cap stops execution. Canonical TP-39-03, coverage, full QA, commit, and push
remain blocked.

## Process review

Part 83's process diagnosis remains sound. This failure reinforces its main
point: a model-backed contract capsule must include exact logging level and
prove every required record in the cheap capability smoke before route work.
Stage 40 should adopt Part 83's executable capsule, evidence matrix, coupled
boundary review, stop rules, and cheap-to-expensive run order. These process
changes do not weaken Stage 39 gates.

Architect verdict: current D39-EXEC-20 evidence is REWORK; design Part 47 PASS.
Next owner: Manager for the narrow correction and two-node rerun gate.
