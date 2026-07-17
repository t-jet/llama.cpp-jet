# Part 100: D39-EXEC-24 slot-release smoke evidence

Date: 2026-07-14
Status: BLOCKED-HARNESS; ARCHITECT REVIEW NEXT
Scope: helper correction, pure lifecycle tests, and one midpoint smoke

## Helper correction

The route helper now builds the exact Part 62 source and incoming requests in
that order. It checks message lengths, property order, `max_tokens`, byte
counts, and SHA-256 values before sending either request. Source is 5,687 bytes
with hash `d34dee12bb4b0c0782975f853f25a9a063f1a01d76d1552de1202e7457379a49`.
Incoming is 5,688 bytes with hash
`a81ced76f8500dcbc4ab5c291f5f51aa61253d988dda72fff98205bfcbf1948b`.

The helper waits for HTTP 200 and idle discovery after each admission. It
preserves `discovery-after-source.json`, `metrics-after-source.json`, the two
post-incoming pre-validation captures, and `slot-release-preflight.json`.

## Pure gate

The first invocation reached the repository's unrelated model-preload fixture,
so none of the selected tests ran. The required fixture skip was then set.
The exact pure command passed 12 tests with 29 deselected in 0.06 seconds.
It covered request bytes and order, two HTTP/idle cycles, both lifecycle
states, and fail-closed inventory and event drift.

## Midpoint smoke

One fresh process and root ran. Both requests returned HTTP 200. Captures show:

- post-source: one branch node, no candidates, no cold sets, and zero decision
  or transaction events;
- post-incoming: two branch nodes, one eligible hot `exact_blob` row, payload 1,
  owner 1, `slot_reference_count=0`, 187,834,252 resident bytes, no cold
  candidate, no cold file, and zero decision or transaction events;
- server log: two saved entries after incoming admission.

The helper stopped before proof because its lifecycle validator compared the
hot source owner with `cold_sets[].incoming_owner_entry_id` and required them
to differ. That field keys the discovered hot candidate, so both values are
correctly owner 1. The test model used the same wrong assumption. The helper
and pure model were corrected, and the pure set passed again. No second model
run was made.

The run took 162.18 seconds. Peak captured RSS was 5,815,054,336 bytes, cold
bytes were zero, and log size was 46,719 bytes. All caps held.

## Artifacts and verdict

`Test-Path` confirmed the exec24 root, pytest output, both discovery captures,
both metrics captures, both requests and hashes, both responses, resource log,
server log, and slot-release preflight. `proof.json`, apply requests, apply
responses, and terminal artifacts are absent.

Observed slot lifecycle passes: source is pinned at one node, then released and
eligible at two nodes. Clean cold state and zero pre-apply events pass. Exact
and checkpoint same-owner proof was not reached, so D39-EXEC-24 is
`BLOCKED-HARNESS`, not PASS and not `BLOCKED-structural`. Fresh Architect review
must decide whether the preserved lifecycle is enough to authorize one proof-
only rerun. Step 2, fault apply, product changes, build, canonical TP-39-03,
coverage, full QA, commit, and push remain blocked.
