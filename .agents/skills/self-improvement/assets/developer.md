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

- Do verify the changed lines, status text, and line counts directly with file reads or searches, then report the path as changed; don't rely on plain `git diff`, because it does not show untracked file content.

## Improvement: Windows server pytest path

Condition:

- When running `tools/server/tests` pytest modules on Windows from the repository root and the harness tries to launch a relative `../../../build/bin/.../llama-server.exe`

Action:

- Do rerun focused tests with `LLAMA_SERVER_BIN_PATH` set to the absolute built server executable; use `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` when the module preload fixture is unrelated to the behavior under test.

## Improvement: Mandatory startup memory order

Condition:

- When task instructions require reading self-improvement memory before any other task action

Action:

- Do make the first assistant action a tool read of the self-improvement skill and agent memory before any acknowledgement, commentary update, skill-use announcement, plan, analysis, or non-memory tool use; don't send even a brief "I'll load memory first" note until that read is complete, including when the note only says memory will be loaded.

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

## Improvement: Extract GGUF templates directly

Condition:

- When adding or refreshing `._test_models/*/chat_template.jinja` fixtures from a GGUF model

Action:

- Do extract `tokenizer.chat_template` from the GGUF metadata first and validate the paired `chat_template_new.jinja` by rendering both files and confirming the marked render strips back to the original output; don't copy the baseline template from a nearby model and assume it matches.

## Improvement: Windows server repro ports

Condition:

- When reproducing llama-server startup behavior on Windows with manually chosen ports

Action:

- Do check `netsh interface ipv4 show excludedportrange protocol=tcp` or use a known unreserved port range before treating bind failures as product behavior.

## Improvement: Hybrid restore timing triage

Condition:

- When hybrid cache metrics report a hit but public completion timing still reports `cache_n=0`

Action:

- Do trace the full handoff from controller restore through slot launch and prompt processing; check request `cache_prompt`, explicit `id_slot` routing, and checkpoint/SWA replay guards before treating the mismatch as response serialization only.

## Improvement: Split near-limit planning docs early

Condition:

- When creating durable implementation or planning documentation that is likely to approach the 300-line document limit

Action:

- Do split the entry into a short TOC/status file and part files before drafting the full content; don't leave an over-limit draft in the worktree while reviewing.

## Improvement: Cache metric defaults across modes

Condition:

- When adding cache metrics that are sourced from hybrid-only stats but emitted through the shared server `/metrics` path

Action:

- Do verify the metric shape for both hybrid and legacy cache modes, and use safe default values for stats fields that legacy controllers do not report.

## Improvement: Preserve local line endings in patch edits

Condition:

- When applying manual patches to files that may use CRLF or mixed line endings

Action:

- Do inspect the resulting diff for unnecessary line-ending churn and, if the patch changed unrelated lines only because of newline normalization, correct that before handoff.

## Improvement: Update indexes before mutable keys

Condition:

- When changing cache entries that are indexed by mutable fields such as use sequence, insertion sequence, namespace, token prefix, or payload residency

Action:

- Do capture the old index key and remove or update the existing index entry before mutating the field; don't add the refreshed entry without first proving the old index entry was removed.

## Improvement: Avoid parallel MSBuild targets sharing objects

Condition:

- When building multiple CMake/MSBuild targets on Windows that share generated projects or object files, especially `server-context.cpp`

Action:

- Do build those targets sequentially or use one combined build command; don't launch parallel tool calls for separate MSBuild targets that can race on `ZERO_CHECK` state or shared object outputs.
