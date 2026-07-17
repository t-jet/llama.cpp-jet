# Part 126: D39-EXEC-32 route execution evidence

Date: 2026-07-14
Status: BLOCKED; MANAGER DISPOSITION NEXT
Scope: exact midpoint then step-2 route nodes from Parts 124-125

## Execution result

The midpoint pytest command ran first with `-q --maxfail=1`. Pytest stopped in
module setup after 2.15 seconds with one ERROR. The Stage 39 MTP helper did not
start, so no route request, model admission, proof, apply, or fault occurred.
The step-2 node was not run, as required by the stop-first-failure rule.

`tools/server/tests/conftest.py::do_something` ran the shared preset preload.
It launched the seam server against `ggml-org/test-model-stories260K`. That
binary has no HTTPS support, could not resolve the remote repository, then
exited because no model path was available. Pytest raised:

```text
RuntimeError: Server process died with return code 1
```

This is a pytest setup blocker, not a Stage 39 product or route verdict. The
route node normally bypasses this unrelated preload when
`LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` is set. D39-EXEC-32 did not authorize a
rerun after first failure, so no correction or retry was attempted.

## Node matrix

| Ordered node | Pytest result | Route result | Disposition |
| --- | --- | --- | --- |
| midpoint | ERROR in shared setup | Not entered | BLOCKED |
| step 2 | Not run | Not entered | Stopped after midpoint |

Executed-node classification is `0 PASS / 0 FAIL / 1 BLOCKED`. This does not
meet the required `2 PASS / 0 FAIL / 0 BLOCKED` acceptance.

## Artifact matrix

Artifact root:
`._test_output/stage39-route-fixture/exec32-midpoint`

| Artifact group | Result |
| --- | --- |
| Pytest command and combined output | Present: `pytest-command.txt`, `pytest-output.txt` |
| Server command and model metadata | Missing; helper constructor not entered |
| Source/incoming request bytes, hashes, and responses | Missing; admissions not entered |
| Source/final discovery and proof | Missing; route not entered |
| Pre-apply/final metrics and cold inventories | Missing; route not entered |
| Apply request and response | Missing; fault not entered |
| Prepared and terminal proof | Missing; fault not entered |
| Resource capture and preflight result | Missing; helper not entered |
| Node artifact manifest and server log | Missing; helper not entered |

The output records the exact local seam binary path, failed preset command,
process IDs, server log, stack trace, pytest warnings, elapsed time, and final
error count. No `llama-server` process from this attempt remained after pytest.

## Scope and handoff

No build, code, helper, fixture, default, canonical, coverage, or full-QA work
ran. No commit, push, PR, or reviewer response occurred. Manager owns the next
decision. Any rerun needs a new gate that binds the standard preload-skip
environment before repeating midpoint first with a fresh root.
