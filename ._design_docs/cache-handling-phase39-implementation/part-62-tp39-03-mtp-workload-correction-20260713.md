# Part 62: TP-39-03 MTP workload correction

Date: 2026-07-13
Status: FIXTURE RETAINED; LIVE SEQUENCE SUPERSEDED BY DESIGN PART 29
Scope: F39-ORR-02 documentation correction only

## Verified fixture capability

Use `._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf` only.
The file exists and is 2,834,975,040 bytes. Metadata-only `gguf_dump` reported
`general.architecture = 'qwen35'`, `general.name = 'Qwen3.5-4B'`,
`qwen35.context_length = 262144`, and
`qwen35.nextn_predict_layers = 1`. Current code supplies the Qwen3.5 MTP graph
in `src/models/qwen35.cpp` and installs `draft-mtp` in
`common/speculative.cpp`. Existing evidence at
`._test_output/mtp-probe-server-stderr-20260604-06.log` names this exact file
and records an MTP draft context, bounded partial sequence removal,
`draft-mtp`, and enabled checkpoints. This proves capability only. This
correction claims no new TP-39-03 run or runtime shape.

## Measurement server contract

```text
--model ._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf
--jinja
--chat-template-file ._test_models/Qwen3.5-4B-MTP-GGUF/chat_template_new.jinja
--ctx-size 8192 --batch-size 512 --ubatch-size 512 --parallel 1
--cache-mode hybrid --cache-ram 166 --cache-cold-max-mib 2048
--ctx-checkpoints 32 --checkpoint-min-step 0
--metrics --temp 0 --seed 42
```

This 166/2048 MiB measurement startup is a D39-EXEC-08 bootstrap. Canonical
replaces both budget arguments with Parts 25 and 27's derived values.

Part 64 measured 3,631 source tokens and 3,632 incoming tokens. Context 8192
allows their 7,263-token total to coexist with a 929-token margin. Preflight
recomputes both counts and their checked sum and rejects drift, a sum above
8,192, or a margin below 929 before apply. Startup must still show bounded
partial sequence removal mapped to RS, MTP initialization, and real checkpoint
creation. Measurement must also prove `runtime_has_draft=false`,
`runtime_pair_matches(target_only,false)=true`, and normal production demotion.

## Literal request generation

Build both requests from this ordered ten-message array. `*` means literal
string repetition with no added separator. Assert each UTF-16 string length
before compact JSON serialization.

| Index | Role | Content expression | Length |
| --- | --- | --- | --- |
| 0 | system | `"S|" + ("shared-system-0123456789abcdef|" * 8)` | 250 |
| 1 | user | `"U1|" + ("alpha-0001|" * 64)` | 707 |
| 2 | assistant | `"A1|" + ("bravo-0002|" * 32)` | 355 |
| 3 | user | `"U2|" + ("charlie-0003|" * 64)` | 835 |
| 4 | assistant | `"A2|" + ("delta-0004|" * 32)` | 355 |
| 5 | user | `"U3|" + ("echo-0005|" * 64)` | 643 |
| 6 | assistant | `"A3|" + ("foxtrot-0006|" * 32)` | 419 |
| 7 | user | `"U4|" + ("golf-0007|" * 64)` | 643 |
| 8 | assistant | `"A4|" + ("hotel-0008|" * 32)` | 355 |
| 9 | user | `"U5|" + ("india-0009|" * 64) + SUFFIX` | 721 or 723 |

Source `SUFFIX` is `"suffix-source|"` (14 characters). Incoming `SUFFIX` is
`"suffix-incoming|"` (16 characters). Every earlier role and byte is equal.
Serialize UTF-8 without BOM in property order
`model,messages,max_tokens,temperature,seed,stream`. Source uses
`max_tokens:32`; incoming uses `max_tokens:1`. Both use `temperature:0`,
`seed:42`, and `stream:false`. Save exact bytes and SHA-256. Filler 1 repeats
source exactly. Filler 2 repeats incoming exactly. Never insert generated
assistant output into a later body.

## Eligibility preflight

Measurement runs source, incoming, filler 1, and filler 2 and does not require a
compatible cold set. It sends no guarded apply or owner reassignment. Every
serialized input must come from that role's normal production demotion and
reconcile its final `.cold` file, immutable header, descriptor size, byte map,
and filesystem length. Canonical uses Parts 25 and 27's measured startup
budgets, runs source then incoming, waits for idle save after each, and
discovers before fillers. Before any `apply`, require:

1. Startup names the exact fixture and records MTP draft initialization,
   bounded partial sequence removal, and checkpoints max 32, spacing 0.
2. Source admission has a real checkpoint. Its positive span ends before the
   first rendered-token difference; source/incoming prefix tokens and checksum
   match through that span.
3. Discovery has exactly one compatible cold source checkpoint, no cold exact
   sibling, and no second checkpoint.
4. Incoming owner is distinct and hot, owns one exact payload, has
   `checkpoint_payload_id == 0`, and passes all Part 19 compatibility checks.
5. Target-only completion has both D39-EXEC-08 runtime predicates, and source
   demotion has exact header, descriptor, file, and accounting reconciliation.
6. Selected cold set contains only that checkpoint. All four measured budget
   inequalities, HMAC token, and generation match the same snapshot.

Any missing fact yields `SKIP-preflight-<fixed-reason>`. Preserve requests,
responses, logs, metrics, discovery, rendered difference index, checkpoint
span/checksum, budgets, files, and owner links. Do not send `apply`, consume the
seam, change text, add filler, synthesize inventory, or weaken compatibility.
This fail-closed SKIP is not TP-39-03 PASS.

If preflight passes, send one apply linked to that checkpoint and incoming
exact owner, using unchanged snapshot fields and
`"tp39_03_cold_owner_setup":"selected_incoming_owner"`. Setup must move the
checkpoint into the incoming owner's empty checkpoint link before unchanged
selection and `tx_update()` run.

## Fixed caps

Run one exact measurement pass and one fresh canonical pass. Each pass has a
20-minute wall cap, 16 GiB process RSS cap, 4 GiB cold-root cap, and six chat
completion requests. The four fixed workload requests leave at most two health
or exact-repeat checks. Discovery and apply are control requests outside the
chat cap. A cap breach is `SKIP-preflight-cap` before apply.

Measurement starts a fresh process and cold root with hot 166 MiB and cold 2048
MiB. It records startup KV allocation, RSS, token counts, runtime pair proof,
both complete-pair resident and normally demoted immutable serialized sizes,
file reconciliation, timing, real checkpoint capability, and discovery, but
never sends apply.
Canonical starts another process/root with Part 25's derived startup budgets and
derives lowered apply budgets only after compatible cold-checkpoint preflight.
It cannot reuse measurement generation, HMAC token, IDs, inventories, files,
or budgets. Missing runtime, demotion, files, headers, descriptor sizes, or
reconciliation fails closed. Part 64's four requests took 12 minutes 14 seconds. Host inspection
found 61.64 GiB RAM with 38.03 GiB free and a 16,311 MiB RTX 5060 Ti, so these
revised caps remain bounded. Context/KV startup failure fails closed.

## Handoff

F39-ORR-02 remains corrected. D39-EXEC-08 is recorded in design Part 27 and
implementation Part 69. Fresh Architect review covers Parts 19, 25, 27, 60,
62, 68-69, and test-plan Part 43. No code, test, driver, build, coverage, or
model-backed execution is authorized here.
