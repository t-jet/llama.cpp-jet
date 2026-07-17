# Part 129: D39-EXEC-33 route rerun evidence

Date: 2026-07-14
Status: PASS; ARCHITECT EVIDENCE REVIEW NEXT
Scope: exact midpoint then step-2 route nodes from Parts 124-125 and 128

## Execution result

`LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` was exported before both pytest
processes. It skipped only the unrelated shared remote preset. Each node loaded
the local Qwen3.5 MTP model through the fresh seam-ON Release server.

The nodes ran sequentially with `-q --maxfail=1` and fresh artifact roots:

| Ordered node | Pytest result | Route result | Duration |
| --- | --- | --- | --- |
| midpoint | `1 passed`, 2 warnings | PASS | 164.19 s |
| step 2 | `1 passed`, 2 warnings | PASS | 164.80 s |

Acceptance is `2 PASS / 0 FAIL / 0 BLOCKED`. The warnings are dependency and
pytest deprecation warnings; neither node skipped or fell back.

## Bound inputs and isolation

Both nodes preserved the accepted request bytes:

| Request | Bytes | SHA-256 |
| --- | ---: | --- |
| source | 5,687 | `d34dee12bb4b0c0782975f853f25a9a063f1a01d76d1552de1202e7457379a49` |
| incoming | 5,688 | `a81ced76f8500dcbc4ab5c291f5f51aa61253d988dda72fff98205bfcbf1948b` |

Each preflight passed with two requests, owner 1, payloads 1 and 2, and
snapshot generation 36. Process identity, session, token, port, cold root,
artifact root, and proof were fresh per node.

## Terminal evidence

Midpoint returned `prepared_midpoint_abort`. It prepared the exact payload,
did not attempt or prepare the checkpoint, and reached common sync generation
46. Step 2 returned `prepared_boundary_abort`; it prepared both exact and
checkpoint records and reached the same common sync generation. Both terminal
states proved:

- exact payload 1 cold at 187,834,316 serialized bytes;
- checkpoint payload 2 hot at 67,620,328 resident component bytes;
- entry and branch links remained exact 1 and checkpoint 2;
- node count, entry count, LRU membership, and branch prune deltas were zero;
- decision delta was exactly one `retained_cold/cold_room`;
- transaction delta was exactly one `commit/none`;
- all checkpoint cold-file, descriptor, and link observations were unchanged;
- all forbidden-effect deltas were zero, with one failed apply and no success
  snapshot;
- authenticated retrieval, tamper rejection, and consumed retry passed.

Final parsed metrics matched the authenticated state: two branch nodes, one
`retained_cold/cold_room` decision, and one `commit/none` transaction. Cold
inventory contained `1.cold` at 187,834,316 bytes plus the 184-byte ownership
claim. Staging inventory was empty.

## Caps and artifacts

| Node | Peak RSS | Cold root | Server log | Elapsed |
| --- | ---: | ---: | ---: | ---: |
| midpoint | 5,841,715,200 B | 187,834,500 B | 47,089 B | 163.828 s |
| step 2 | 5,834,625,024 B | 187,834,500 B | 47,083 B | 164.516 s |

Both nodes stayed below 16 GiB RSS, 4 GiB cold, 64 MiB log, and 20 minutes.
Each node preserved 25 route files covering command/model metadata, request
and response bytes, discovery, proof, metrics, cold inventories, apply,
prepared/terminal retrieval, preflight, resource capture, and server log. Each
root also preserved the exact pytest command, preload-skip environment, and
combined pytest output.

Artifact roots:

- `._test_output/stage39-route-fixture/exec33-midpoint/midpoint-fault-1783990687367616000-24160`
- `._test_output/stage39-route-fixture/exec33-step2/step2-fault-1783990875457941800-23452`

No build, source/helper/fixture edit, default or canonical run, coverage, or
full QA occurred. Fresh Architect implementation and evidence review is next.
