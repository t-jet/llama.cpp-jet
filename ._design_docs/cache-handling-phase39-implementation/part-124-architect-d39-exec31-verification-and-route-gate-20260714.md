# Part 124: Architect D39-EXEC-31 verification and route gate

Date: 2026-07-14
Verdict: PASS; MANAGER MAY OPEN EXACT TWO-NODE ROUTE GATE
Scope: Parts 121-123 and unchanged D39-EXEC-27 route inputs

## Verification

The Part 123 edit changes only the stale Stage 28 comment in
`test_stage23_cold_room_making_keeps_checkpoint_attach_coherent`. Reconstructing
the before text from Part 123 changes that comment block and no executable
line. Removing comments from both forms produces byte-identical function text.
The recorded executable-only SHA-256 remains
`dc6452929667b061aa7fddf2267cd8dbea9e9d41f5986b8252cdf8b9e2df33df`.

The corrected comment now matches the Release-active assertions: payload 1
demotes, the second demotion tombstones payload 1 to make cold room, and payload
2 remains cold. Both Stage 28 rejection bodies and invocations remain present.
No rebuild or test rerun is needed for this comment-only correction.

Current `server-cache-hybrid.cpp` and `.h` SHA-256 values remain the Part 112
values `8BFD3BB8F0F7E302FAC80F6CA5282190AD2AE7E1CFD84436990797D86F54EC97`
and `701FC17AFEC9D1B710841CF0B16ADEB13F4B0CAAB3DF853A95EAA6F8FECC0442`.
The seam server binary and implementation DLL are newer than both inputs.
Parts 109-121 preserve the passing executable, freshness, controller-fault,
seven-effect, terminal-consumer, authentication, and route-readiness reviews.
F39-TEST-02 is closed.

## Exact Manager route gate

Manager may authorize only these two pytest nodes, in this order, with
`--maxfail=1`: midpoint first, then step 2. Each node must use a fresh process,
port, token, session, cold root, artifact root, IDs, generation, and proof.

```text
tools/server/tests/unit/test_stage39_live_pressure.py::test_live_pressure_prepared_proof_midpoint_fault_coherent_terminal
tools/server/tests/unit/test_stage39_live_pressure.py::test_live_pressure_prepared_proof_step2_fault_coherent_terminal
```

Use the existing fresh seam-ON Release server and unchanged helper. Keep
`--spec-type draft-mtp --log-verbosity 4`, context 8192, hot and cold startup
budgets 2048 MiB, and the accepted D39-EXEC-25 request bytes:

- source: 5,687 bytes,
  `d34dee12bb4b0c0782975f853f25a9a063f1a01d76d1552de1202e7457379a49`;
- incoming: 5,688 bytes,
  `a81ced76f8500dcbc4ab5c291f5f51aa61253d988dda72fff98205bfcbf1948b`.

Keep the production-prepared low-budget inequalities, coupled trace preflight,
terminal matrix, all seven observed forbidden-effect checks, HMAC retrieval and
tamper rejection, consumed retry, and exact decision/transaction deltas. Keep
per-node caps at 20 minutes, 16 GiB RSS, 4 GiB cold root, and 64 MiB server log.
Preserve each node's command, metadata, request and response bytes, discovery,
proof, metrics, cold inventories, apply request and response, prepared and
terminal proof, resource capture, preflight result, manifest, and server log.

Acceptance is exactly `2 PASS / 0 FAIL / 0 BLOCKED`, with no skip or fallback.
Stop after the first failure, blocker, cap breach, preflight drift, or missing
artifact. No build, source edit, fixture change, default or canonical run,
coverage, full QA, commit, push, PR, or reviewer response is authorized.

