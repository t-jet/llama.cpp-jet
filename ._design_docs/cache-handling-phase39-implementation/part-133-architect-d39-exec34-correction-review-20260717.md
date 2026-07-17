# Part 133: Architect D39-EXEC-34 correction review

Date: 2026-07-17
Verdict: REWORK
Scope: Part 132 and `tools/server/tests/unit/test_stage39_live_pressure.py`

## Verified correction behavior

Both fault nodes call `_reject_tampered_terminal_proof()` before
`_retrieve_terminal_proof()`. The tamper helper changes the last HMAC character,
requires a non-200 response, and writes redacted request and response artifacts.
The valid authenticated retrieval still follows it.

The manifest runs after the consumed retry. Its 27 required names are the 25
D39-EXEC-33 route files plus the two tamper files. The forbidden list contains
the exact `fault.json` and `terminal-proof.json` leftovers. The recursive byte
scan covers every file under the node root except the manifest itself and checks
the route token, snapshot token, proof token, valid HMAC, and changed HMAC. The
manifest is written before missing, leftover, or secret counts raise, so failure
is preserved and remains fail closed.

No C++ source, fixture, budget, route, or product behavior changed.

## Blocking finding

### F39-ROUTE-03: tamper test does not prove changed-HMAC input

`test_stage39_terminal_retrieval_rejects_changed_hmac_and_captures_redacted`
uses a `server.control` lambda that ignores its request body and always returns
403. The only request assertion sees the already redacted HMAC. The test would
still pass if `_reject_tampered_terminal_proof()` sent the valid HMAC or any
other value. This does not provide meaningful regression coverage for the
specific D39-EXEC-34 changed-HMAC requirement.

Require the mock control function to capture or assert the raw request before
returning 403. Assert that its HMAC equals `_changed_hmac(proof["terminal_hmac"])`
and differs from the valid HMAC. Keep the existing redacted artifact checks.

## Checks

The five authorized pure nodes pass with
`LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1`: `5 passed, 145 deselected`. Static
inspection confirmed route order, manifest timing, required and forbidden
lists, recursive secret inputs, and fail-closed assertions. No model node, C++
build, canonical run, coverage, or full QA ran.

## Handoff

Developer owns the one pure-test correction. After a fresh Architect re-review
passes, Manager may reopen the same midpoint then step-2 route rerun. Model
execution remains blocked.
