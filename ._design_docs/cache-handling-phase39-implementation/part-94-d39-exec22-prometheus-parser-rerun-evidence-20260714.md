# Part 94: D39-EXEC-22 Prometheus parser rerun evidence

Date: 2026-07-14
Status: BLOCKED
Scope: helper-only parser correction and exact rerun gate

## Correction

`test_stage39_live_pressure.py` now uses one strict Prometheus parser for both
MTP metrics callers. It accepts only anchored Stage 39 target samples, parses
labels independent of order, decodes supported escapes, rejects duplicate or
wrong labels and tuples, and requires nonnegative integer values. Decision and
transaction rows are sorted. The returned helper shape and default
`Stage39Server` remain unchanged. Both callers fail closed with
`BLOCKED-route-fixture-drift`; there is no JSON fallback.

## Pure parser gate

The four node IDs required by design Part 48 passed. The parameterized schema
node produced nine cases, so pytest reported `12 passed in 0.06s`, with zero
failures and zero skips. The preserved output is:

```text
._test_output/stage39-route-fixture/exec22-parser/pytest.txt
```

The tests prove the exact helper shape, deterministic ordering, ignored
non-sample braces, schema and value rejection, snapshot drift detection, and a
terminal `commit/none` sum of one.

## Exact route rerun

Midpoint ran first from a fresh process and root. It failed after successful
admission and metrics parsing:

```text
BLOCKED-route-fixture-inventory: expected one owned hot exact row
```

Pytest reported one failure, zero passes, and zero skips in 93.99 seconds.
Step 2 did not run. No proof or apply request was sent, so no midpoint or step-2
fault value exists.

The raw discovery response and parsed metrics existed only in helper memory.
The helper checks `hot_candidates` before it writes `discovery.json` or
`metrics-before-apply.json`, and process cleanup removed the in-memory values.
Read-only searches of the preserved root and pytest temporary tree found no
copy. Exact discovery row counts, owner IDs, residency values, and metric
values are therefore unrecoverable from this run. They must not be inferred.
This capture gap prevents diagnosis from the failed response alone. The next
review must require pre-validation preservation before authorizing a rerun.

The preserved midpoint root is:

```text
._test_output/stage39-route-fixture/exec22-midpoint/
midpoint-fault-1783981741515362100-33236
```

`Test-Path` returned true. The root contains command, model metadata, exact
5,687-byte request and hash, response, preflight result, resource capture, and
33,791-byte server log. Peak recorded values were 93.547 seconds,
5,587,501,056 RSS bytes, zero cold bytes, and 33,737 log bytes. All caps held.
The command contains exactly one `--spec-type draft-mtp` pair and one
`--log-verbosity 4` pair. The log records 3,631 target tokens, 19 accepted draft
tokens, a 164.758 MiB target component, a 14.375 MiB draft component, real
checkpoint creation, and one saved entry with 243.620 MiB payload.
These are the only inventory facts preserved by the artifact. The metrics
parser returned successfully before the inventory blocker, but its returned
shape and values were not written.

## Gate

D39-EXEC-22 acceptance is not met: pure parser gate passed, but route result is
zero passed, one failed, zero skipped; step 2 is not run. Product code, build,
canonical TP-39-03, coverage, full QA, commit, and push remain blocked. Next
owner is a fresh Architect implementation review of the parser and the live
inventory mismatch. No broader correction or rerun is authorized.
