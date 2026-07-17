VERDICT: PASS

# Part 24: independent TP-39-03 context-capacity review

Date: 2026-07-13
Status: PASS; MANAGER CORRECTION GATE READY
Scope: D39-EXEC-06, design Part 23, implementation Part 65, and aligned
TP-39-03 contract edits

## Verdict

The correction is narrow and internally consistent. It changes the TP-39-03
controller/context capacity from 4,096 to 8,192 after Part 64 measured the two
required owners at 3,631 and 3,632 tokens. Their checked total is 7,263, leaving
929 tokens. Security, compatibility, ownership, rollback, selector, metric,
and closure contracts remain unchanged.

Manager gate readiness: READY. This PASS does not authorize driver changes,
builds, tests, model execution, coverage, or QA.

## Evidence checked

- Part 64 preserves four literal responses with prompt counts 3,631 and 3,632,
  real 50.251 MiB checkpoints, one retained entry after each alternating save,
  and no apply after discovery failed under the 4,096-token limit.
- Qwen3.5 maps to recurrent-state rollback support in `llama-arch.cpp`.
  `common_context_can_seq_rm()` maps a positive rollback snapshot count to RS,
  and `server-context.cpp` admits RS into the checkpoint path. The existing
  fixture log records bounded partial sequence removal, `draft-mtp`, and enabled
  checkpoints. Context 8,192 does not weaken those eligibility requirements.
- Parts 19, 60-62, and test-plan Part 43 now bind context 8,192, exact token
  counts, checked addition, the 929-token minimum margin, and unchanged positive
  2,048 MiB startup budgets.
- Each pass has a 20-minute wall cap, 16 GiB process RSS cap, 4 GiB cold-root
  cap, and six-chat cap. Part 64 took 12 minutes 14 seconds at context 4,096.
  The corrected contract requires fresh KV/RSS capture and fails closed on
  startup allocation failure or cap breach; it does not assume the larger
  allocation will succeed.
- Measurement sends no apply. Canonical execution uses another process and cold
  root, repeats measurement, and derives budgets from its own snapshot. It may
  not reuse generation, HMAC token, identities, inventories, files, serialized
  sizes, or lowered budgets.

## Findings

No blocking findings.

Advisory: Part 64 says Part 62 fixed context 4,096. That sentence records the
contract under which Part 64 ran; Parts 23 and 65 supersede it. Future edits to
Part 64 should label that sentence as the pre-D39-EXEC-06 contract, but the
historical evidence and this gate are unambiguous without rewriting Part 64.

## Handoff

Next owner: Manager. Manager may approve the D39-EXEC-06 correction gate.
Developer work remains blocked until that approval. After approval, Developer
may update only the driver capacity, cap enforcement, resource capture, token
checks, and fresh-pass isolation named by Part 65, then produce the required
focused and model-backed evidence.
