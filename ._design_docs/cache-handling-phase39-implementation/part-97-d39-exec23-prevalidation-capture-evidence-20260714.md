# Part 97: D39-EXEC-23 pre-validation capture evidence

Date: 2026-07-14
Status: DIAGNOSTIC ACCEPTED; ROUTE NOT PASS
Scope: one capture-only midpoint node

## Helper correction

The dedicated MTP helper now writes the complete discovery object and parsed
metrics immediately after the first successful discovery and metrics parse.
Recursive redaction changes only `snapshot_token`. With
`LLAMA_STAGE39_CAPTURE_ONLY=1`, the helper then stops with:

```text
BLOCKED-route-fixture-diagnostic: pre-validation capture complete
```

The opt-in stays in the pytest process. `command.json` lists only
`LLAMA_STAGE39_LIVE_TEST_SEAM` and `LLAMA_STAGE39_LIVE_TEST_TOKEN` as child
environment names.

## Diagnostic result

One fresh midpoint node ran. Pytest reported one expected failure, zero passes,
and zero skips in 87.20 seconds. The fixed stop occurred at 86.828 seconds.
Step 2 did not run.

The discovery file is valid JSON. It reports snapshot generation 18, hot and
cold budgets of 2,147,483,648 bytes, zero hot candidates, zero cold sets, and
zero cold candidate rows. Because no row exists, there are no payload IDs,
owner IDs, kinds, residency values, protected-root flags, slot-reference
counts, resident sizes, or eligibility values to report.

The metrics file is valid JSON. Parsed values are:

- `branch_forest.total_nodes`: 1
- `cache_cold_transactions`: zero rows
- `cache_two_layer_decisions`: zero rows

These values come directly from the two capture files, not log reconstruction.
The observation explains the prior `expected one owned hot exact row` blocker
but does not classify its cause.

## Artifacts and caps

`Test-Path` returned true for the node root, pytest output, discovery capture,
and metrics capture:

```text
._test_output/stage39-route-fixture/exec23-midpoint/
midpoint-fault-1783982573746578100-33452
```

The node preserves command, model metadata, the 5,687-byte source request and
hash, 869-byte response, preflight result, resource capture, 33,791-byte server
log, and empty cold root. Peak recorded values were 86.812 seconds,
5,586,649,088 RSS bytes, zero cold bytes, and 33,737 log bytes. All fixed caps
held.

No `proof.json`, `apply-request.json`, `apply-response.json`,
`prepared-proof-retrieval.json`, `metrics-final.json`,
`metrics-before-apply.json`, or post-validation `discovery.json` exists.

## Verdict and next gate

D39-EXEC-23 diagnostic acceptance is met: both required captures are parseable
and the fixed stop precedes inventory checks, proof, and apply. This is not a
route PASS. Fresh Architect review must classify the empty inventory as helper
assertion, fixture timing, or product state before any correction or new run.
Step 2, proof, apply, assertion and fixture changes, product code, build,
canonical TP-39-03, coverage, full QA, commit, and push remain blocked.
