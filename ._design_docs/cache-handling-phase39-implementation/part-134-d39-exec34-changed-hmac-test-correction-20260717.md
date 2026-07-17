# Part 134: D39-EXEC-34 changed-HMAC test correction

Date: 2026-07-17
Status: READY FOR ARCHITECT RE-REVIEW
Scope: F39-ROUTE-03 pure test only

## Correction

`test_stage39_terminal_retrieval_rejects_changed_hmac_and_captures_redacted`
now captures the raw request inside its mock control function. Before returning
403, the mock asserts that the request HMAC equals
`_changed_hmac(proof["terminal_hmac"])` and differs from the valid HMAC. The
test also requires exactly one raw request. Existing checks still require the
saved request HMAC to be redacted and the saved response to contain only the
authentication error.

No production helper, model fixture, C++, route behavior, or artifact contract
changed.

## Test evidence

Environment: `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1`.

```text
python -m pytest -q tools/server/tests/unit/test_stage39_live_pressure.py -k
"terminal_retrieval_accepts_valid_hmac or
terminal_retrieval_rejects_changed_hmac_and_captures_redacted or
fault_manifest_is_complete or fault_manifest_missing_file_fails_node or
fault_artifact_redaction_removes_tokens_and_hmacs" --maxfail=1
```

Result: `5 passed, 145 deselected in 0.11s`. Only the five pure tests authorized
by Manager Part 131 ran. No model node, C++ build, fixture, canonical run,
coverage, or full QA ran.

## Handoff

F39-ROUTE-03 is corrected and ready for fresh Architect review. Midpoint and
step-2 model reruns remain blocked until that review passes and Manager reopens
execution.
