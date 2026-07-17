# Part 138: Architect D39-EXEC-35 evidence review

Date: 2026-07-17
Verdict: PASS
Scope: Parts 124-125, 130, 135-137 and both Part 137 artifact roots

## Review

The authorized midpoint and step-2 nodes ran in order, in separate pytest and
server processes, and produced `2 PASS / 0 FAIL / 0 BLOCKED`. Their ports,
process identities, session IDs, run IDs, route roots, cold roots, and proofs
are separate. Process-local payload IDs and generations restart at the same
numeric values in both runs; fresh process and session bindings make them
independent allocations, not shared state.

Direct SHA-256 checks of the saved requests match the gate: source is 5,687
bytes with `d34dee12bb4b0c0782975f853f25a9a063f1a01d76d1552de1202e7457379a49`,
and incoming is 5,688 bytes with
`a81ced76f8500dcbc4ab5c291f5f51aa61253d988dda72fff98205bfcbf1948b`.
Both commands use the accepted local Qwen3.5 MTP fixture, seam-ON Release
server, `draft-mtp`, context 8192, 2048 MiB hot and cold budgets, and log
verbosity 4.

Both terminal records preserve generations 36, 42, 45, and 46 with one common
sync. Exact payload 1 is cold at 187,834,316 bytes; checkpoint payload 2 is hot
at 67,620,328 resident bytes. Entry and branch links remain 1 and 2, staging is
empty, and topology, LRU, branch-prune, descriptor, link, checkpoint cold-file,
and all forbidden-effect deltas are zero. Each node has one failed apply, no
success snapshot, one `retained_cold/cold_room` decision, and one
`commit/none` transaction. Midpoint has one prepared exact record and no
checkpoint attempt; step 2 has exact then checkpoint records.

The corrected helper SHA-256 is
`C483067E0DE420B0766C8553A38A6805D43E64A36B5C7B7BE5B2FA65F47DFDD5`.
Its route order sends `_changed_hmac(valid_hmac)`, requires rejection, then
retrieves the byte-equivalent proof with the valid HMAC and requires the apply
retry to fail as consumed. Both saved tamper responses are
`400/stale_prepared_proof`; both saved retrievals equal their embedded terminal
proofs. Part 135's raw-request test binds the first request to the changed HMAC
and rejects the valid or any other value, so redaction does not weaken this
evidence.

## Artifacts, caps, and scope

Each manifest reports 27/27 required files, both forbidden leftovers absent,
zero unredacted token matches, and zero valid or changed-HMAC matches. Direct
file enumeration agrees. Midpoint peaks at 5,844,189,184 bytes RSS,
187,834,500 cold-root bytes, 47,089 log bytes, and 179.968 seconds. Step 2 peaks
at 5,843,173,376 bytes RSS, 187,834,500 cold-root bytes, 47,083 log bytes, and
174.593 seconds. All values are below the gate caps.

The parent records contain only the two authorized pytest commands and their
environment. Product source hashes remain the Part 124 values, the seam binary
is newer than both product inputs, and no `llama-server` process remains. No
rerun, model execution, build, canonical TP-39-03, coverage, or full QA was
performed during this review. The evidence shows no D39-EXEC-35 scope drift.

## Handoff

D39-EXEC-35 evidence review passes with no open finding. Manager may open the
fresh clean-build QA gate for the complete approved Stage 39 plan, including
canonical TP-39 rows and coverage. Those activities remain blocked until that
Manager decision.
