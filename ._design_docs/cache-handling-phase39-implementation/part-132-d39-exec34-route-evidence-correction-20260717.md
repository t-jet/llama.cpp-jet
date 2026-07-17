# Part 132: D39-EXEC-34 route evidence correction

Date: 2026-07-17
Status: ARCHITECT REWORK IN PART 133
Scope: Python route helper and pure tests only

## Plan

1. Add changed-HMAC terminal retrieval before valid retrieval in each fault node.
2. Preserve redacted tamper request and response files.
3. Write a fail-closed artifact manifest after the consumed retry.
4. Add and run only the five authorized pure test cases.

## Implementation

`tools/server/tests/unit/test_stage39_live_pressure.py` now sends one terminal
retrieval with the last HMAC character changed. The helper requires a non-200
response and writes `prepared-proof-tamper-request.json` and
`prepared-proof-tamper-response.json` through the existing recursive redactor.
The valid authenticated retrieval follows the rejection, so the negative
request cannot replace the required positive proof.

Each midpoint and step-2 node writes `artifact-manifest.json` after its
consumed retry. The manifest records all 27 required fault-node artifacts,
the exact forbidden `fault.json` and `terminal-proof.json` leftovers, and raw
match counts for route, snapshot, proof tokens, the valid terminal HMAC, and
the changed HMAC. A missing required file, present forbidden file, or nonzero
secret match raises `AssertionError` after the manifest is preserved.

Five pure tests cover valid retrieval, changed-HMAC rejection with redacted
capture, complete manifest output, missing-file fail closure, and redaction.
The redaction test also injects an unredacted token and proves that manifest
validation fails.

## Files changed

- `tools/server/tests/unit/test_stage39_live_pressure.py`
- `._design_docs/cache-handling-phase39-implementation/part-132-d39-exec34-route-evidence-correction-20260717.md`
- `._design_docs/cache-handling-phase39-implementation.md`
- `._design_docs/document-index.md`

## Test evidence

Environment: `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1`.

```text
python -m pytest -q tools/server/tests/unit/test_stage39_live_pressure.py -k
"terminal_retrieval_accepts_valid_hmac or
terminal_retrieval_rejects_changed_hmac_and_captures_redacted or
fault_manifest_is_complete or fault_manifest_missing_file_fails_node or
fault_artifact_redaction_removes_tokens_and_hmacs" --maxfail=1
```

Result: `5 passed, 145 deselected in 0.11s`. The two warnings come from the
installed requests dependencies and pytest-asyncio configuration. No model
node, C++ build, fixture, canonical run, coverage, or full QA ran.

## Handoff

D39-EXEC-34 needs the F39-ROUTE-03 pure-test correction from Part 133. Midpoint
and step-2 reruns remain blocked until fresh Architect re-review passes.
