# Part 23: TP-39-03 context-capacity correction

Date: 2026-07-13
Status: CORRECTED; READY FOR FRESH INDEPENDENT ARCHITECT REVIEW
Scope: TP-39-03 MTP workload capacity only

## Manager decision

D39-EXEC-06 authorizes this narrow correction:

> Correct TP03 MTP ctx from 4096 to 8192 based on Part64 measured source3631+incoming3632=7263; preserve prior security/preflight/ownership.

No request body, production selector, guarded ownership rule, security guard,
failure classification, or closure criterion changes.

## Evidence and decision

Part 64 ran the literal Part 62 workload. It measured 3,631 source tokens and
3,632 incoming tokens, and created real 50.251 MiB checkpoints. The controller
token limit was 4,096, so the required owners could not coexist:

```text
3631 + 3632 = 7263 > 4096
```

Token enforcement removed the prior owner after each alternating save. The
measurement correctly stopped before apply. This is a workload-capacity defect,
not a checkpoint-eligibility failure or product defect.

Set `--ctx-size 8192`. The measured total then leaves 929 tokens. Preflight must
recompute both token counts from saved canonical bodies, use checked addition,
and require the sum to be at most 8,192 with at least 929 tokens free. Token
drift fails before apply.

Checkpoint eligibility remains unchanged. The target context must still map
bounded partial sequence removal to RS. Startup must name the fixed Qwen3.5-4B
MTP fixture and show MTP initialization, enabled checkpoints, and real checkpoint
creation. A larger context cannot substitute for those facts.

## Resource caps and execution order

Keep one slot, batch and ubatch 512, checkpoint max 32, minimum spacing 0, and
2048 MiB positive measurement budgets; Part 25 derives canonical startup
budgets. Increase each pass from 15 to
20 minutes and process RSS from 12 to 16 GiB. Keep the 4 GiB cold-root and six
chat-request caps.

Part 64's four requests took 12 minutes 14 seconds. Host inspection recorded
61.64 GiB RAM with 38.03 GiB free and a 16,311 MiB RTX 5060 Ti. The revised
caps leave host headroom while allowing larger context/KV initialization and
the discovery/control tail. Startup allocation failure or any cap breach fails
closed before apply.

Run an exact measurement pass first. It uses a fresh process and cold root,
records KV allocation, RSS, request time, token counts, checkpoint sizes,
resident pair bytes, immutable cold-object bytes, inventory, and discovery. It
must not send apply. D39-EXEC-07 and Part 25 supersede the earlier measurement
preflight: measurement proves sizes and checkpoint capability without requiring
a cold candidate.

Stop that process. Part 25 derives canonical startup budgets from exact measured
resident and immutable serialized sizes. Source then incoming admission must
create cold source residency before discovery. Derive lowered apply budgets only
after compatible cold-checkpoint preflight. Do not reuse measurement generation,
HMAC token, payload or owner IDs, inventories, or files.

## Preserved contracts

Parts 19, 60-62, and test-plan Part 43 retain the prior exact complete-set,
destination-link, compatibility, admission-latch, one-shot, generation,
rollback, redaction, loopback, admin-token, strict-schema, and normal
`tx_update()` rules. Apply remains forbidden unless canonical preflight proves
one compatible cold checkpoint, no sibling collision, a distinct hot incoming
owner with an empty checkpoint link, and all four budget inequalities.

## Handoff

Fresh independent Architect review is next. Code, tests, driver changes, model
execution, coverage, and QA remain blocked pending review PASS and Manager gate.
