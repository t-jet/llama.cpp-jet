# Developer improvement memory

## Improvement: Dirty documentation handoff

Condition:
- When adding or updating durable planning documents in a worktree that already has uncommitted documentation changes

Action:
- Do capture the pre-existing dirty state before edits and distinguish newly changed paths from existing user or prior-agent changes in the handoff.

## Improvement: Verify untracked documentation edits

Condition:
- When editing a documentation file that is untracked in git

Action:
- Do verify the changed lines directly and report the path as changed; don't rely on plain `git diff`, because it does not show untracked file content.

## Improvement: Windows server pytest path

Condition:
- When running `tools/server/tests` pytest modules on Windows from the repository root and the harness tries to launch a relative `../../../build/bin/.../llama-server.exe`

Action:
- Do rerun focused tests with `LLAMA_SERVER_BIN_PATH` set to the absolute built server executable; use `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` when the module preload fixture is unrelated to the behavior under test.

## Improvement: Mandatory startup memory order

Condition:
- When task instructions require reading self-improvement memory before any other task action

Action:
- Do read the self-improvement skill and agent memory before any acknowledgement, progress update, plan, analysis, or other tool use; don't announce skill use, describe the next step, or begin task context gathering until that read is complete.

## Improvement: Test-results review gate classification

Condition:
- When reviewing QA execution reports for a staged gate with FAIL, SKIP, BLOCKED, or misleading runner output

Action:
- Do classify each non-pass item as product bug, QA harness gap, environment/configuration limitation, design/test-plan mismatch, or acceptable deferred coverage, and update the stage implementation status with the exact next gate action.

## Improvement: Replace stale test-report references

Condition:
- When updating an existing test-results review for a newer or corrected QA report

Action:
- Do replace stale report IDs, row statuses, blocker counts, and owner assignments throughout the durable review and parent implementation status before handoff.
