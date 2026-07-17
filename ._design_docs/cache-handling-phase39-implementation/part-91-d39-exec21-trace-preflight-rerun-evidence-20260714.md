# Part 91: D39-EXEC-21 trace preflight rerun evidence

Date: 2026-07-14
Status: BLOCKED; FRESH ARCHITECT IMPLEMENTATION REVIEW NEXT
Authority: Design Part 47, Architect Part 89, Manager Part 90

## Narrow correction

The dedicated `Stage39MTPServer` adds this one adjacent command pair:

```text
--spec-type draft-mtp --log-verbosity 4
```

Before startup, the helper requires exactly one selector pair and one trace
verbosity pair. It rejects other logging options and
`LLAMA_ARG_LOG_VERBOSITY`. The resource record now measures `server.log` and
terminates the node above 64 MiB. Existing 20-minute, 16 GiB RSS, and 4 GiB
cold-root limits remain unchanged. No product code, default helper, schema,
workload, budget, or other startup option changed.

## Sequential rerun

The midpoint node ran first from a fresh process and artifact root. Result:

```text
0 passed, 1 failed, 0 skipped in 94.24s
```

Trace preflight passed its literal capability checks, then `_metrics()` failed
before proof or apply. `_extract_metrics_json()` selected the first Prometheus
label block, beginning `{mode="hybrid"}`, and `json.loads()` raised
`JSONDecodeError: Expecting property name enclosed in double quotes`.

The step-2 node did not run. Manager Part 90 requires stopping on the first
failure. Acceptance `2 passed, 0 failed, 0 skipped` was not reached.

## Exact evidence

The command contains one adjacent `--spec-type draft-mtp --log-verbosity 4`
sequence. `command.json` records only the two approved test-seam environment
names. The fixed request is 5,687 bytes with SHA-256
`d34dee12bb4b0c0782975f853f25a9a063f1a01d76d1552de1202e7457379a49`.

Trace and draft values before failure:

- `creating MTP draft context`: present
- `bounded partial sequence removal`: present
- `draft-mtp`: present
- checkpoint maximum 32 and spacing 0: present
- real checkpoint creation: present
- target component: 164.758 MiB
- draft component: 14.375 MiB

Pair proof was not reached. Exact/checkpoint pair values are therefore
unavailable. Fault apply was not reached, so midpoint fault records and terminal
proof values are unavailable. No `preflight-result.json`, `proof.json`, or apply
artifact exists.

Maximum samples were 93.797 seconds, 5,587,849,216 RSS bytes, 0 cold-root bytes,
and 33,737 `server.log` bytes. All resource caps held.

## Preserved artifact

- `._test_output/stage39-route-fixture/exec21-midpoint/midpoint-fault-1783980802668733800-15164`

`Test-Path` returns true for the artifact. No `exec21-step2` root exists.

## Handoff

Fresh Architect implementation review is next. Review the trace-enabled metrics
response/parser mismatch and define any correction before another Manager gate.
Canonical TP-39-03, coverage, full QA, build, commit, and push remain blocked.
