# Part 137: D39-EXEC-35 route rerun evidence

Date: 2026-07-17
Status: PASS; ARCHITECT EVIDENCE REVIEW PASSED IN PART 138
Scope: exact midpoint then step-2 route nodes from Parts 124-125 and 136

## Commands and isolation

Both nodes ran sequentially in separate pytest processes with `-q --maxfail=1`.
The environment set `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1`,
`LLAMA_SERVER_BIN_PATH` to the seam-ON Release server, and a new
`LLAMA_STAGE39_ROUTE_ARTIFACT_ROOT` for each process. The local Qwen3.5-4B MTP
fixture loaded with `draft-mtp`, context 8192, and 2048 MiB hot/cold budgets.

| Node | Port | Process identity | Session prefix | Pytest result |
| --- | ---: | --- | --- | --- |
| midpoint | 47047 | `5b7ba02d1094a16d0784c574a6f8e7ea` | `22338df227af` | `1 passed` in 180.43 s |
| step 2 | 52916 | `4cadb12b0c6d1c3d28cca9721c31207e` | `6bd810254175` | `1 passed` in 175.01 s |

Both runs used distinct ports, processes, sessions, route tokens, cold roots,
artifact roots, run IDs, generations, IDs, and proofs. Neither skipped or used
a fallback. The warnings were dependency and pytest deprecation warnings.

## Bound inputs and terminal evidence

Both saved request files match the accepted inputs: source 5,687 bytes with
SHA-256 `d34dee12bb4b0c0782975f853f25a9a063f1a01d76d1552de1202e7457379a49`,
and incoming 5,688 bytes with SHA-256
`a81ced76f8500dcbc4ab5c291f5f51aa61253d988dda72fff98205bfcbf1948b`.

Midpoint returned `prepared_midpoint_abort`; it prepared the exact record and
did not attempt the checkpoint. Step 2 returned `prepared_boundary_abort`; it
prepared exact then checkpoint records. Both reached generation 46 with one
common sync. Exact payload 1 remained cold at 187,834,316 bytes; checkpoint
payload 2 remained hot at 67,620,328 resident bytes. Entry and branch links
remained exact 1 and checkpoint 2. Staging was empty. Topology, LRU, branch
prune, descriptor, link, checkpoint cold-file, and all observed forbidden
effect deltas were zero. Each run recorded one failed apply, no success
snapshot, exactly one `retained_cold/cold_room` decision, and exactly one
`commit/none` transaction. Changed-HMAC rejection, valid retrieval, and
consumed retry passed in both nodes.

## Caps, manifests, and cleanup

| Node | Peak RSS | Cold root | Server log | Route elapsed |
| --- | ---: | ---: | ---: | ---: |
| midpoint | 5,844,189,184 B | 187,834,500 B | 47,089 B | 179.968 s |
| step 2 | 5,843,173,376 B | 187,834,500 B | 47,083 B | 174.593 s |

Both stayed below 16 GiB RSS, 4 GiB cold, 64 MiB log, and 20 minutes. Each run
preserved all 27 manifest-required route files plus `artifact-manifest.json`.
Both manifests report every required file present, both forbidden leftovers
absent, zero unredacted token matches, and zero valid or changed-HMAC matches.

Artifact roots:

- `._test_output/stage39-route-fixture/exec35-midpoint/midpoint-fault-1784276585561353900-26272`
- `._test_output/stage39-route-fixture/exec35-step2/step2-fault-1784276835937065200-25756`

Each parent root also preserves its pytest command, environment, and output.
After each node, no `llama-server` process remained. No source, helper, fixture,
product, build, default or canonical run, coverage, full QA, commit, push, PR,
or reviewer response occurred.

Acceptance is `2 PASS / 0 FAIL / 0 BLOCKED`. Architect Part 138 accepts this
evidence. Manager clean-build QA gate is next; canonical TP-39 rows and full QA
remain blocked pending that decision.
