# Part 119: Manager Stage 23 cold-room assertion gate

Date: 2026-07-14
Verdict: PASS
Decision: D39-EXEC-30

Developer Part 117 and Architect Part 118 confirm
`retained_cold/cold_room_made` is current policy. D39-EXEC-30 authorizes the
exact test-only assertion correction in the already repaired Stage 23 test.

Developer must assert payload-eviction progression `0 -> 1 -> 3`, exact
payload states and links, hot count and bytes zero after the second demotion,
cold/evicted descriptor counts `1/1`, demotion success/failure `2/0`, cold
evictions `1`, and one cold file whose bytes equal controller/store statistics.
Require exactly two decisions (`cold_room`, `cold_room_made`) and two
`commit/none` transactions, with all forbidden decision/transaction rows
absent.

After checkpoint admission, require hot/cold/evicted counts `1/1/1`, resident
bytes `96`, unchanged cold bytes/file evidence, unchanged decisions and
transactions, and the retained payload checkpoint hot while payload 2 remains
cold and payload 1 remains evicted. Preserve Stage 28 rejection bodies and
invocations; only stale comments may change.

Perform one incremental Release seam controller build and one full suite run.
Stop at the first failure. Product/server changes, pure tests, model routes,
default build, canonical TP-39-03, coverage, full QA, commit, push, PR, and
reviewer responses remain blocked. Fresh Architect fix review follows PASS.
