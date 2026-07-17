# Part 92: Architect D39-EXEC-21 implementation review

Date: 2026-07-14
Verdict: REWORK; DESIGN PART 48 PASS
Scope: Parts 47 and 89-91, current metrics helpers, and exec21 midpoint evidence

## Verdict

D39-EXEC-21 correctly added trace level 4, enforced the approved argv and log
cap, and passed the complete capability trace. It did not reach pair proof or
fault apply. Current implementation remains REWORK because both MTP metrics
callers treat Prometheus text as JSON.

Design Part 48 is the complete narrow correction. It changes test parsing only.
No product, exporter, route, metric, or evidence schema change is needed.

## Evidence and root cause

The preserved exec21 root is:

```text
._test_output/stage39-route-fixture/exec21-midpoint/midpoint-fault-1783980802668733800-15164
```

It contains the exact command, 5,687-byte request and hash, response, model
metadata, 33,791-byte log, and resource samples. Trace capability passed. Peak
values were 93.797 seconds, 5,587,849,216 RSS bytes, and zero cold bytes. No
proof, preflight-result, or apply artifact exists.

`server-context.cpp` builds `/metrics` as Prometheus text and sets content type
`text/plain; version=0.0.4`. `Stage39MTPServer._metrics()` calls it before proof
and again after repeated discovery. `_metrics_after_pressure()` calls it after
the fault. Both use `_extract_metrics_json()`, whose first-brace/last-brace
slice selects Prometheus labels. `Stage39Server` neither defines `_metrics()`
nor calls the extractor, so its existing Qwen3-0.6B route tests are outside the
correction.

## Required implementation and focused tests

Developer must implement Part 48 in one pass:

1. remove the brace-slicing extractor and all `json.loads()` calls around it;
2. add one strict, line-anchored Prometheus parser shared by both MTP callers;
3. return sorted decision and transaction rows plus total branch nodes in the
   existing helper-only shape;
4. accept empty pre-event decision/transaction families, but require exactly
   one hybrid/all namespace-node sample;
5. reject malformed target samples, wrong or duplicate labels, duplicate
   tuples, and non-integer or non-finite values;
6. make `_metrics()` record fixed `BLOCKED-route-fixture-drift` on parser
   failure; do not fall back to JSON or a broad brace search;
7. add and pass the four exact pure pytest nodes named in Part 48 before any
   model execution.

All current preflight equality, terminal commit, topology, trace, pair, fault,
resource, redaction, one-shot, and artifact assertions stay in place.

## Process review

Part 83 identified the main process problem: executable fixture facts arrived
after prose gates. Exec20 and exec21 add two examples. Logging level and metrics
wire format were both treated as late execution details, so each required an
expensive model start to discover.

Future stages should enforce Part 83's contract capsule and cheap-to-expensive
order. In this loop, Manager should require pure parser tests and a checked-in
representative Prometheus body before authorizing another model run. A single
boundary review should cover endpoint content type, parser, internal evidence
shape, every caller, and fail-closed outcome. Model reruns should validate model
behavior, not discover helper syntax or wire formats.

## Handoff

Part 48 supersedes only the invalid metrics-extraction assumption. Part 91 is
historical evidence; its stop decision remains correct. Next owner: Manager for
one helper-only correction gate, four pure tests, then the same two-node rerun.
Canonical TP-39-03, coverage, full QA, build, commit, and push remain blocked.
