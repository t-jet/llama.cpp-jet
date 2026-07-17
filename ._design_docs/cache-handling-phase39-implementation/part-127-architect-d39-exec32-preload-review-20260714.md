# Part 127: Architect D39-EXEC-32 preload review

Date: 2026-07-14
Verdict: PASS; MANAGER MAY OPEN CORRECTED TWO-NODE RERUN
Scope: Part 126 setup blocker and unchanged Parts 124-125 route contract

## Finding

Part 126 is a harness-setup blocker. Pytest entered the module-scoped autouse
fixture in `tools/server/tests/conftest.py` before constructing the Stage 39
helper. Because `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD` was unset, that fixture
called `ServerPreset.load_all()` and tried to fetch
`ggml-org/test-model-stories260K`. The seam binary has no HTTPS support, so the
unrelated preset server exited before either route node ran.

Setting `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` is the exact correction.
`conftest.py` uses it only to bypass `ServerPreset.load_all()`. The Stage 39 test
module does not use that preset. Its `Stage39MTPServer` still checks the local
model, template, byte size, and GGUF metadata, then starts a fresh server with
the Qwen3.5 MTP model, `--spec-type draft-mtp`, trace verbosity, context 8192,
and the approved cache budgets. It still admits both fixed model requests and
requires the complete capability, lifecycle, proof, metric, and artifact
preflight before apply.

This use does not turn model-backed evidence into a startup-only substitute.
The environment variable suppresses only pytest's shared remote preset; the
node's own local MTP load and inference remain mandatory. Earlier Stage 39
focused commands in Parts 81, 85, 88, 106, and 109 use the same setting. The
repository warning against preload-skip evidence remains satisfied because
PASS still depends on the model launched by `Stage39MTPServer`. No design,
helper, fixture, product, or assertion correction is needed.

## Corrected rerun contract

Manager may authorize the same nodes from Part 124, in the same order, with a
fresh PowerShell process environment:

```powershell
$env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'
python -m pytest tools/server/tests/unit/test_stage39_live_pressure.py::test_live_pressure_prepared_proof_midpoint_fault_coherent_terminal -q --maxfail=1
python -m pytest tools/server/tests/unit/test_stage39_live_pressure.py::test_live_pressure_prepared_proof_step2_fault_coherent_terminal -q --maxfail=1
```

Run step 2 only after midpoint PASS. Each node needs a fresh process, port,
token, session, cold root, artifact root, IDs, generation, and proof. Preserve
the environment setting and exact pytest command in the command evidence.
Retain Part 124's fixed model, template, argv, request bytes and hashes,
low-budget inequalities, trace preflight, terminal matrix, seven observed
forbidden-effect checks, authentication checks, exact metric deltas, artifact
list, and per-node caps.

Acceptance remains exactly `2 PASS / 0 FAIL / 0 BLOCKED`, with no skip or
fallback. Stop after the first failure, blocker, cap breach, drift, or missing
artifact. No build, edit, default or canonical run, coverage, full QA, commit,
push, PR, or reviewer response is authorized.

## Handoff

Architect review passes. Manager owns the corrected bounded rerun gate. Fresh
Architect implementation and evidence review follows only after both nodes
pass.
