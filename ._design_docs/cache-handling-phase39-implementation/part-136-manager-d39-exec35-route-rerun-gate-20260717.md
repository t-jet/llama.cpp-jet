# Part 136: Manager D39-EXEC-35 route rerun gate

Date: 2026-07-17
Verdict: PASS
Decision: D39-EXEC-35

Architect Part 135 closes F39-ROUTE-03 and confirms the D39-EXEC-34 tamper
and manifest correction. D39-EXEC-35 authorizes the same two route nodes from
Parts 124-125, in this order:

1. midpoint fault;
2. step-2 fault.

Run each node in a fresh process, session, port, cold root, and artifact root.
Set `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1`; this may skip only the unrelated
shared remote preset. Both nodes must load the accepted local Qwen3.5 MTP
fixture through the fresh seam-ON Release server. Keep the accepted source and
incoming request bytes, hashes, budgets, caps, route assertions, and terminal
matrix unchanged.

Each node must preserve the changed-HMAC rejection request and response plus a
passing `artifact-manifest.json`. Acceptance remains `2 PASS / 0 FAIL / 0
BLOCKED`, with no skip or fallback. Record command, environment, process
isolation, request hashes, terminal evidence, resource caps, manifest result,
artifact roots, and cleanup in the next implementation evidence part.

No source, helper, fixture, product behavior, build, default or canonical
TP-39-03, coverage, full QA, commit, push, PR, or reviewer response is
authorized. Stop after either node fails. Fresh Architect evidence review must
pass before clean-build QA runs the complete Stage 39 plan.
