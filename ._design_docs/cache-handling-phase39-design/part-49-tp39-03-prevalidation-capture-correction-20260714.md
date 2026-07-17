# Part 49: TP-39-03 pre-validation capture correction

Date: 2026-07-14
Status: ARCHITECT PASS; MANAGER DIAGNOSTIC GATE NEXT
Scope: D39-EXEC-22 midpoint helper evidence only

## Finding

The exec22 midpoint reached discovery and parsed metrics, then stopped at
`expected one owned hot exact row`. The helper wrote neither value before that
assertion. Logs prove one saved cache entry and positive target and draft
components, but they do not preserve discovery rows. Source alone cannot tell
whether the response had zero, one, or several hot candidates, or which owner,
kind, residency, and size each row reported.

No inventory assertion may change from this evidence. No proof or apply run is
authorized.

## Capture correction

Add one helper-only capture point in `Stage39MTPServer.admit_pair()`. After the
first successful discovery response and successful `_metrics()` parse, but
before reading or validating `hot_candidates`, `cold_sets`, or cold files,
write these files with the existing sorted JSON writer:

```text
discovery-before-validation.json
metrics-before-validation.json
```

`discovery-before-validation.json` must contain the complete parsed discovery
object, including every row and field. Apply the existing recursive redaction
only to `snapshot_token`; do not summarize, filter, reorder arrays, or replace
row values. `metrics-before-validation.json` must contain the parser's exact
canonical result: decision rows, transaction rows, and total branch nodes.

If either write fails, stop with `BLOCKED-route-fixture-capture`. Do not use a
log reconstruction or a second discovery request as a substitute.

## One diagnostic run

Add helper-process opt-in `LLAMA_STAGE39_CAPTURE_ONLY=1`. It is not passed to
the model process and must not appear among the child environment names in
`command.json`. When set, the helper writes both files, then calls `_block()`
with:

```text
BLOCKED-route-fixture-diagnostic: pre-validation capture complete
```

This stop must occur before the current inventory assertions, proof request,
repeat discovery, apply construction, or fault request. Run only the midpoint
node, from a fresh process, port, token, cold root, and artifact root. Do not run
step 2.

The diagnostic accepts a pytest failure only when the fixed diagnostic reason
is present and both JSON files are valid. Preserve command, metadata, source
request and hash, response, server log, resource capture, preflight result, and
cold root. There must be no `proof.json`, `apply-request.json`,
`apply-response.json`, prepared proof, or terminal metrics artifact.

Keep the 20-minute wall, 16 GiB RSS, 4 GiB cold-root, 64 MiB log, one-process,
one-slot, and one-chat-request caps. Any cap or earlier capability failure wins
over the diagnostic result and stops the run.

## Next decision

A fresh Architect review must report exact hot and cold row counts and each
row's payload ID, owner ID, kind, residency, protected-root flag, slot reference
count, resident bytes, and eligibility, plus parsed metric values. That review
may then classify the mismatch as helper assertion, fixture timing, or product
state. Observed rows remain mandatory before any proof or apply authorization.

This part supersedes only Part 48's assumption that post-parse validation would
leave enough evidence for diagnosis. Parts 45-48, Manager Part 93, and the
exec22 stop remain binding. Product code, route schema, parser, model workload,
budgets, tests, coverage, QA, build, commit, and push remain blocked.
