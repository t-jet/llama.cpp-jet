# Part 45: TP-39-03 route fixture correction

Date: 2026-07-14
Status: HISTORICAL ARCHITECT PASS; STARTUP LIST SUPERSEDED BY PART 46
Scope: D39-EXEC-18 route fixtures only

## Verdict

Reuse the Part 62 Qwen3.5-4B MTP asset and literal source request. Do not reuse
the superseded owner-reassignment sequence. One source admission naturally
creates the hot exact and checkpoint descriptors needed by the two route tests.
This is the smallest route fixture that matches the controller baseline from
design Part 29.

Part 81's controller PASS remains valid. Part 82's route blocker is resolved at
design level. Developer work and model execution still require a Manager gate.

## Fixture contract

Each route node starts its own server, port, cold root, process token, and
one-shot test session. Use only:

```text
--model ._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf
--jinja
--chat-template-file ._test_models/Qwen3.5-4B-MTP-GGUF/chat_template_new.jinja
--ctx-size 8192 --batch-size 512 --ubatch-size 512 --parallel 1
--cache-mode hybrid --cache-ram 2048 --cache-cold-max-mib 2048
--ctx-checkpoints 32 --checkpoint-min-step 0
--metrics --temp 0 --seed 42
--host 127.0.0.1 --no-ui
```

The helper also supplies its unique port and cold path. The server binary must
be the seam-ON Release binary. Runtime opt-in and the admin token remain
separate environment variables. The 2048 MiB startup hot budget is deliberate:
Part 67 observed two hot exact owners and real checkpoints without demotion at
that budget. The route baseline needs one complete pair hot and cold empty.
Part 62's 166 MiB budget is for size measurement and must not be copied here.

Do not fall back to `Qwen3-0.6B-Q8_0.gguf`, a plain transformer, a short prompt,
synthetic checkpoint creation, direct controller setup, owner reassignment, or
another chat template.

## Literal admission

Build one `/v1/chat/completions` source request from this ordered array. `*`
means literal repetition without a separator:

| Index | Role | Content expression | Length |
| --- | --- | --- | --- |
| 0 | system | `"S\|" + ("shared-system-0123456789abcdef\|" * 8)` | 250 |
| 1 | user | `"U1\|" + ("alpha-0001\|" * 64)` | 707 |
| 2 | assistant | `"A1\|" + ("bravo-0002\|" * 32)` | 355 |
| 3 | user | `"U2\|" + ("charlie-0003\|" * 64)` | 835 |
| 4 | assistant | `"A2\|" + ("delta-0004\|" * 32)` | 355 |
| 5 | user | `"U3\|" + ("echo-0005\|" * 64)` | 643 |
| 6 | assistant | `"A3\|" + ("foxtrot-0006\|" * 32)` | 419 |
| 7 | user | `"U4\|" + ("golf-0007\|" * 64)` | 643 |
| 8 | assistant | `"A4\|" + ("hotel-0008\|" * 32)` | 355 |
| 9 | user | `"U5\|" + ("india-0009\|" * 64) + "suffix-source\|"` | 721 |

Preserve every role, string length, property order, UTF-8 byte, and compact JSON
rule from Part 62. The body is:

```text
model="Qwen3.5-4B", messages=<array above>
property order: model,messages,max_tokens,temperature,seed,stream
max_tokens=32, temperature=0, seed=42, stream=false
```

Save the exact bytes and SHA-256. Do not send the incoming request, fillers, a
generated assistant response, or any other completion. Wait for idle admission
before discovery. The admission cap is one chat request per node.

## Capability and baseline preflight

Before sending `apply`, require all of these facts in the same process:

1. The model path exists, has size 2,834,975,040 bytes, and metadata names
   architecture `qwen35`, context length 262144, and one NextN layer.
2. Startup logs name the exact model and record an MTP draft context,
   `draft-mtp`, bounded partial sequence removal, checkpoint maximum 32, and
   spacing 0.
3. The literal source request returns HTTP 200 and the server becomes idle.
4. Discovery returns exactly one eligible hot exact row. It has a nonzero owner,
   no cold candidate, positive startup budgets, and the cold root has no final,
   staging, quarantine, or manifest file.
5. A `proof` request for that exact payload expands to exactly two rows in this
   order: `exact_blob`, `checkpoint`. Both rows are hot, share the discovered
   owner, have distinct nonzero payload IDs, pass runtime pair matching, have
   positive target size and checked resident size, and match their kind links.
6. Discovery generation and HMAC token remain current after proof. Repeated
   discovery and proof are non-consuming and do not change generation, metrics,
   descriptors, files, topology, ranks, budgets, or one-shot state.

The route apply must use those two exact IDs and no others. Prepared bindings
keep exact at pressure step 1 and checkpoint at step 2. Budget derivation stays
the approved guarded calculation:

```text
R_exact <= H_low < R_exact + R_checkpoint
max(S_exact, S_checkpoint) <= C_low < S_exact + S_checkpoint
```

The real preparation boundary supplies `S_exact` and `S_checkpoint`. No prompt
estimate, resident-size substitute, copied canonical value, or cross-process
value is valid.

## Fail-closed behavior and caps

Any missing or drifting preflight fact stops before `apply`, leaves the one-shot
control unconsumed, and reports a fixed `BLOCKED-route-fixture-*` reason. A skip,
fallback fixture, exact-only proof, or synthetic pair cannot pass this gate.
The exact pytest command must finish with `2 passed`, `0 failed`, and `0 skipped`.

Each node has these limits:

- 20-minute wall clock, including startup and the one chat request;
- 16 GiB process RSS;
- 4 GiB cold-root size;
- one model process, one slot, one chat request, and one fault apply;
- health, discovery, proof, retrieval, and metrics requests only outside the
  chat cap.

A cap breach terminates that node, preserves its logs and inventories, and is
`BLOCKED-route-fixture-cap`. The two nodes may consume at most 40 minutes in
total. They run sequentially because each server can consume its one-shot state.

## Exact route evidence

Run only these node IDs for this correction gate:

```text
tools/server/tests/unit/test_stage39_live_pressure.py::test_live_pressure_prepared_proof_midpoint_fault_coherent_terminal
tools/server/tests/unit/test_stage39_live_pressure.py::test_live_pressure_prepared_proof_step2_fault_coherent_terminal
```

Keep their current fault assertions. Add baseline assertions for the exact two
IDs, same owner, hot residency, empty cold root, and no pre-apply decision or
transaction delta. The midpoint node must prove checkpoint was not attempted.
The step-2 node must prove checkpoint prepared but was not classified, admitted,
published, or committed. Both still require failed HTTP response, coherent
terminal entry and branch state, one production common sync, authenticated
generation order, and no success snapshot.

No node may reuse another node's process, token, IDs, generation, request bytes,
proof, cold root, metrics baseline, or artifact directory. These route results
also do not supply canonical TP-39-03, coverage, or QA evidence.

## Boundary and handoff

The fixture uses an existing public chat admission path to create natural model
state, then the already approved default-OFF, runtime-OFF guarded route. It does
not change production policy, route schema, cold format, metric labels, owner
links, checkpoint creation, or unguarded behavior. The seam changes budgets and
order only after the natural pair passes preflight; normal production code owns
the exact demotion, common epilogue, and fault result.

Historical verdict: PASS for route-fixture design. Manager Part 84 authorized
execution, and Part 85 then proved this startup list omitted the required
speculative selector. Design Part 46 supersedes only that list and its coupled
preflight. All other fixture terms remain binding.
