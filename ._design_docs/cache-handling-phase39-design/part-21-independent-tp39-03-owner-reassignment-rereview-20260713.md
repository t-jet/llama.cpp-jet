# Part 21: independent TP-39-03 owner-reassignment re-review

Date: 2026-07-13
Status: REWORK REQUIRED
Review scope: corrected design Part 19, implementation Parts 60-61, and
test-plan Part 43 against Part 20 F39-ORR-01 and F39-ORR-02

## Verdict

REWORK REQUIRED. F39-ORR-01 is closed at design level. F39-ORR-02 remains
blocking because the named Qwen3-0.6B fixture cannot create the required
runtime checkpoint, regardless of the larger context limit. The workload is
also not reproducible because the claimed fixed transcript is not specified.

Manager gate readiness: NOT READY. Code, tests, driver changes, and QA remain
blocked.

## Evidence reviewed

- Design Part 19 and implementation Parts 60-61
- Test-plan Part 43 and historical review Part 20
- Implementation Part 54 executed fixture result
- `common/common.h`, `tools/server/server-context.cpp`, and
  `tools/server/server-cache-hybrid.cpp`

## F39-ORR-01: closed

Part 19 now requires locked destination compatibility validation before
one-shot consumption. It covers namespace, runtime pair shape, descriptor and
cold-object identity, target/draft sizes and checksums, bounded equal token
span, ordered position span, preparation metadata, boundary resolution, and
the checkpoint metadata predicates used by restore. Failure uses the fixed
pre-consumption reason and preserves generation, ownership, links, files,
bytes, ranks, counters, and one-shot state.

Parts 60 and 43 carry matching negative tests, atomic rollback, redaction,
normal-selector, and normal `tx_update()` requirements. No production restore
or selector change is proposed.

## F39-ORR-02: still open

The correction names Qwen3-0.6B-Q8_0 with `--ctx-size 16384` and expects a real
checkpoint at or beyond token 8192. That is not a reachable contract for this
fixture.

Implementation Part 54 records the executed fact: "Qwen3-0.6B produces no
runtime checkpoints." Current checkpoint creation confirms why. In
`server-context.cpp`, `do_checkpoint` requires completion work plus a target
context whose sequence-removal type is FULL or RS, or a model with SWA. Context
size and the 8192 minimum spacing are later conditions; they do not enable
checkpoint creation for a plain transformer context that fails the earlier
model/runtime gate. Raising `--ctx-size` therefore cannot turn this fixture
into a checkpoint producer.

The workload is not executable as written for a second reason. Parts 19, 60,
and 43 call the ten-turn transcript "fixed" but provide neither its literal
messages nor a checked-in request fixture. Rendered token count, shared prefix,
different suffix, checkpoint boundary, and repeatability cannot be verified.

Because no source checkpoint can be admitted, later filler pressure cannot
produce exactly one cold compatible checkpoint, remove its exact sibling, or
leave the incoming hot exact owner with an empty checkpoint link. Measurement
passes, 20-minute caps, 12-request caps, rollback, security checks, budget
checks, and normal-selector assertions do not repair this missing precondition.

## Required correction

1. Select an available checkpoint-producing target/runtime fixture and record
   startup evidence that satisfies the production `do_checkpoint` gate.
2. Prove its context and batch limits permit a checkpoint with
   `n_tokens >= 8192` while leaving room for completion and the second request.
3. Check in or specify the literal ten-turn source and incoming request bodies,
   including the exact shared prefix and changed suffix.
4. Give the exact server flags, including checkpoint count and minimum spacing,
   and preserve the created-checkpoint log plus admitted descriptor evidence.
5. Keep the existing exact pre-apply inventory, four budget inequalities,
   caps, rollback, redaction, security, normal selector, and normal
   `tx_update()` assertions.
6. If no local fixture can satisfy the production checkpoint gate, record
   TP-39-03 as BLOCKED-fixture and return to Manager for a fixture or contract
   decision. Do not authorize implementation from the current plan.

## Contract checks

| Check | Result |
| --- | --- |
| Destination checkpoint compatibility | PASS at design level |
| Full validation before consumption | PASS at design level |
| Rollback, terminal state, and generation | PASS at design level |
| Security and redaction | PASS at design level |
| Unchanged normal selector and `tx_update()` | PASS at design level |
| Exact pre-apply owner/link shape | PASS as an assertion |
| Qwen3-0.6B checkpoint reachability | REWORK |
| Literal reproducible workload | REWORK |

## Handoff

Verdict: REWORK REQUIRED.

Next owner: Developer for documentation correction, then fresh independent
Architect re-review. Manager authorization is not ready. No code, test,
driver, build, or QA work is authorized by this review.
