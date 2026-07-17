# Part 128: Manager preload-skip route rerun gate

Date: 2026-07-14
Verdict: PASS
Decision: D39-EXEC-33

Architect Part 127 confirms `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` bypasses
only unrelated shared remote preset setup. It does not bypass the local MTP
model, route preflight, or evidence capture.

D39-EXEC-33 authorizes the same exact midpoint then step-2 route nodes from
Parts 124-125, sequentially with `--maxfail=1`, while exporting that variable
before pytest starts. All fresh-process isolation, accepted request hashes,
server/helper options, budgets, caps, terminal assertions, and artifact
requirements remain unchanged.

Acceptance remains exactly `2 PASS / 0 FAIL / 0 BLOCKED`. Stop after the first
failure, blocker, drift, cap breach, or missing artifact.

Build, source/helper/fixture changes, default or canonical TP-39-03, coverage,
full QA, commit, push, PR, and reviewer responses remain blocked. Fresh
Architect evidence review follows PASS.
