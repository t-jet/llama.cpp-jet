# Part 88: D39-EXEC-20 draft-MTP rerun evidence

Date: 2026-07-14
Status: BLOCKED; FRESH ARCHITECT IMPLEMENTATION REVIEW NEXT
Authority: Design Part 46, Architect Part 86, Manager Part 87

## Correction

The dedicated `Stage39MTPServer` now adds exactly one adjacent pair after the
chat-template option:

```text
--spec-type draft-mtp
```

Before admission, the helper writes `command.json` and fails closed unless the
argv contains exactly one adjacent selector pair. The existing source-save
preflight now requires a positive `dft` component. Both proof rows require
positive `target_size_bytes` and `draft_size_bytes`, checked resident-byte
aggregation, and `runtime_pair_matches=true`.

No default helper, product code, fallback, route schema, startup budget, cap, or
other test changed.

## Sequential rerun

Environment:

```text
LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1
LLAMA_SERVER_BIN_PATH=build-stage39-seam-on/bin/Release/llama-server.exe
```

The midpoint node ran first from a fresh process and root. It failed closed
before apply:

```text
1 failed, 0 passed, 0 skipped in 93.22s
BLOCKED-route-fixture-capability: bounded partial sequence removal, draft-mtp
```

The step-2 node did not run. Part 46 requires any failed preflight to stop before
apply, and D39-EXEC-20 does not authorize another flag or a weaker check.
Acceptance `2 passed, 0 failed, 0 skipped` was not reached.

## Preflight values

`command.json` contains one `--spec-type` entry followed immediately by
`draft-mtp`. The server log proves that runtime capability selection worked:

- MTP draft context created against the target model;
- speculative decoding context initialized;
- source save target component: 164.758 MiB;
- source save draft component: 14.375 MiB;
- draft acceptance: 19 of 33 generated tokens;
- context checkpoint settings: maximum 32, minimum spacing 0;
- real context checkpoints created.

The run reached 92.782 seconds maximum sampled elapsed time, 5,588,398,080
maximum RSS bytes, and 0 cold-root bytes. It stayed below all three caps.

## Exact blocker

The required strings `bounded partial sequence removal` and `draft-mtp` are not
present in the default server log. Current source emits those records only at
trace level in `common/common.cpp` and `common/speculative.cpp`. The same log
already proves the MTP context, positive draft save, draft token generation, and
checkpoint creation, but the fixed preflight cannot continue to proof or apply
without those two literal records.

Adding a trace option, changing the log level, or weakening the required record
list would exceed D39-EXEC-20. No apply, fallback, build, canonical TP-39-03,
coverage, full route suite, full QA, commit, or push occurred.

## Preserved artifact

- `._test_output/stage39-route-fixture/exec20-midpoint/midpoint-fault-1783980035334949200-32204`

`Test-Path` returns true for the root. It contains the command, model metadata,
literal request and hash, response, server log, resource samples, and failed
preflight result. It contains no apply artifact. No step-2 root was created.

## Handoff

Fresh Architect implementation review is next. Review should decide whether
the two trace-only records are valid binding preflight at default logging and
define any correction before Manager opens another execution gate.
