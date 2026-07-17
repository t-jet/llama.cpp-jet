VERDICT: PASS

# Part 22: independent TP-39-03 MTP workload re-review

Date: 2026-07-13
Status: PASS; MANAGER CORRECTION-PLAN GATE READY
Scope: F39-ORR-02 correction in implementation Part 62, with Parts 19,
60-61, and test-plan Part 43 checked for consistency

## Verdict

F39-ORR-02 is closed at design level. The named Qwen3.5-4B fixture can enter
the production checkpoint path, the workload is fixed and reproducible, and
the preflight fails closed without weakening TP-39-03 closure.

Manager gate readiness: READY. This PASS does not authorize code, tests, build,
driver execution, or QA. Manager authorization remains the next gate.

## Evidence reviewed

- Design Parts 19 and 21; implementation Parts 60-62; test-plan Part 43
- Fixture file and metadata from metadata-only `gguf_dump`
- Existing `mtp-probe-server-stderr-20260604-06.log`
- `common/common.cpp`, `common/arg.cpp`, `common/speculative.cpp`,
  `src/llama-arch.cpp`, `src/llama-model.cpp`, `src/models/qwen35.cpp`,
  `tools/server/server-context.cpp`, and `tools/server/server-cache-hybrid.cpp`

## F39-ORR-02 closure

The fixture exists at the fixed path and is 2,834,975,040 bytes. Metadata
reports architecture `qwen35`, name `Qwen3.5-4B`, training context 262144, and
one NextN prediction layer. Current source classifies Qwen3.5 as hybrid and as
supporting bounded rollback. The existing startup log for the same file records
an MTP draft context, bounded partial sequence removal, `draft-mtp`, and enabled
checkpoints.

Production maps bounded partial removal to `COMMON_CONTEXT_SEQ_RM_TYPE_RS`.
`do_checkpoint` accepts RS before applying the message-boundary and minimum
spacing conditions. Therefore `--ctx-size 4096` does not remove checkpoint
eligibility. `--checkpoint-min-step 0` only removes spacing between eligible
checkpoints; it does not manufacture eligibility. The prior Qwen3-0.6B error is
not repeated.

Part 62 fixes ten ordered messages, roles, content expressions, source and
incoming suffixes, generation values, compact property order, four workload
requests, and two-pass caps. Recalculation matches every stated UTF-16 length,
including 721 for source U5 and 723 for incoming U5. The two bodies are equal
through the earlier messages and differ only in the final user suffix. The
chat-boundary checkpoint path can therefore end before the rendered-token
difference. Saved byte bodies and SHA-256 values make each run auditable.

The owner move remains compatible with Part 19. Preflight requires one cold
checkpoint, no exact sibling or second checkpoint, a distinct hot incoming
exact owner with an empty checkpoint link, matching tokens and metadata through
the checkpoint span, all four budget inequalities, and the same generation and
HMAC snapshot. No destination link can be overwritten.

Missing eligibility, inventory, compatibility, budget, or cap facts return a
fixed `SKIP-preflight-*` result before apply. Part 62 says this is not TP-39-03
PASS, and Part 43 still requires every Stage 39 row to pass for closure. The
SKIP path preserves evidence and blocks seam consumption; it does not relax the
row or Stage 39 closure contract.

## Contract checks

| Check | Result |
| --- | --- |
| Exact local fixture and metadata | PASS |
| Production checkpoint eligibility | PASS |
| Context 4096 compatibility | PASS |
| Literal workload reproducibility | PASS |
| Destination owner/link compatibility | PASS |
| Exact pre-apply inventory and budgets | PASS |
| Fixed time, RSS, disk, and request caps | PASS |
| Fail-closed SKIP versus closure | PASS |

## Handoff

Verdict: PASS.

Next owner: Manager for the TP-39-03 correction-plan gate. Implementation and
QA remain blocked until Manager authorization.
