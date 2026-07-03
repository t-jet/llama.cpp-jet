# Stage 34 rework evidence 2026-06-30

Status: rework complete; implementation re-review ready

## Scope

This part closes the three blockers from
[part 04](part-04-implementation-review-20260630.md) plus the F34-PATH-01
user-directive correction. No long live Qwen replay was run.

## F34-IMPL-01 event model

Changed:

- `stage34-replay-parser.ps1` now emits `main_request`, `subagent_request`,
  `subagent_return`, and `continuation` when records provide explicit generic
  `stage34_*` fields or supported event hints.
- Child branch ids are stable. If a subagent record lacks an explicit branch,
  the parser derives a child id from parent agent, child agent, and row number.
- `parent_branch_id_hash` is populated for return and continuation events when
  the record supports it.
- `synthetic-agentic.jsonl` now covers main request, two child branches,
  subagent return, parent continuation, exact duplicate burst, and model split.

Evidence (regenerated at correct path after F34-PATH-01):

- Synthetic dry-run output: `_test_output/stage34-synthetic-dry-run-rework/`
- Synthetic event shape: `main_request=1`, `subagent_request=3`,
  `subagent_return=1`, `continuation=1`, unique branches `4`,
  parent-link rows `3` (subagent_request parent, subagent_return parent,
  continuation parent).
- Real chat log dry-run output: `_test_output/stage34-chatlog-dry-run-rework/`
- Real event shape: `main_request=47`, `subagent_request=9`, unique branches
  `10`, parent-link rows `0`. The real fixture does not expose supported
  return or continuation parent records, so the parser does not invent them.

## F34-IMPL-02 expected-hit model

Changed:

- Renderer stamps each event with rendered-plan `token_count` and
  `token_checksum` before writing `events.jsonl`.
- Expected-hit rows now use model hash, token count, token checksum, branch id,
  predecessor request id, candidate source, expected class, required residency,
  and budget window.
- Exact hit candidates fail preflight if rendered token count or checksum is
  missing.

Evidence (regenerated at correct path after F34-PATH-01):

- Synthetic expected-hit rows: 1 exact hit,
  `candidate_source=cross_branch_exact_checksum`,
  `expected_class=exact_duplicate_request_burst`,
  `required_residency=hot`, `budget_window_id=hot-4-distance-1`.
  Every row has non-zero `token_count` (4 or 5) and non-empty
  `token_checksum`.
- Real chat log expected-hit rows: 23 exact hits. Hit rows with missing
  token/checksum data: `0`.
- Real candidate-source counts:
  `same_branch_exact_checksum=14`, `cross_branch_exact_checksum=9`,
  `none=33`, `parent_branch_tip=0` (real fixture exposes subagent_request
  rows but no `continuation` or `subagent_return` rows, so no parent-tip
  rows are produced).

## F34-IMPL-03 target+draft deep copy

Changed:

- Added `debug_capture_first_payload_for_tests(bool runtime_has_draft)`, a
  test-only hook that validates the first payload and returns copied plan
  bytes without requiring a live draft context.
- Updated the Stage 34 deep-copy regression to admit target+draft payload bytes
  (`64` target, `32` draft), capture both vectors, evict the source payload,
  verify source validation fails, and verify captured target and draft byte
  sizes and byte patterns remain unchanged.

Evidence:

- Direct controller run passed: `144/144`.
- Stage 34 test line passed:
  `test-cache-controller: Stage 34 restore plan deep copy survives payload eviction... PASSED`.

## F34-PATH-01 user-directive path correction

Changed:

- `replay-agentic-transcript.ps1` no longer requires `-OutputDir`. When the
  caller passes a relative path, the runner resolves it under
  `<workspace>/_test_output/`. When the caller omits `-OutputDir`, the runner
  defaults to `<workspace>/_test_output/stage34-dry-run`. When the caller
  passes an absolute path, that path is used as-is.
- `replay-agentic-transcript.ps1` also defaults `-TranscriptPath` to the
  bundled synthetic fixture
  `<scripts>/_fixtures/stage34/synthetic-agentic.jsonl` when the caller
  omits it, so a bare invocation reproduces the synthetic dry-run without
  flag sprawl.
- The wrong non-durable tree
  `._design_docs/cache-handling-test-scripts/._test_output/` was deleted.
- `Test-Path '._design_docs\cache-handling-test-scripts\._test_output'`
  returns `False` after deletion.
- `Test-Path '_test_output\stage34-synthetic-dry-run-rework'` and
  `Test-Path '_test_output\stage34-chatlog-dry-run-rework'` both return `True`.
- All other Stage 34 docs (implementation log ordered step 4, evidence plan,
  part 03 evidence table, part 04 Checks run table note) now reference the
  project-root `_test_output/` paths instead of the wrong
  `._design_docs/cache-handling-test-scripts/._test_output/` path.

Evidence:

- `Test-Path ._design_docs\cache-handling-test-scripts\._test_output`
  returns `False`.
- `Test-Path _test_output\stage34-synthetic-dry-run-rework` returns `True`.
- `Test-Path _test_output\stage34-chatlog-dry-run-rework` returns `True`.
- `git check-ignore -v _test_output/stage34-synthetic-dry-run-rework`
  reports `_test_output/.gitignore:1:**/*`, proving the new tree is
  gitignored and stays non-durable.

## Commands

| Command | Result |
| --- | --- |
| `git diff --check` | PASS, no output |
| `git diff --check -- ._design_docs/cache-handling-test-scripts/replay-agentic-transcript.ps1 ._design_docs/cache-handling-phase34-implementation.md` | PASS, no output |
| `Test-Path ._design_docs\cache-handling-test-scripts\._test_output` | `False` (PASS) |
| `Test-Path _test_output\stage34-synthetic-dry-run-rework` | `True` (PASS) |
| `Test-Path _test_output\stage34-chatlog-dry-run-rework` | `True` (PASS) |
| `pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/replay-agentic-transcript.ps1 -TranscriptPath ._design_docs/cache-handling-test-scripts/_fixtures/stage34/synthetic-agentic.jsonl -OutputDir _test_output/stage34-synthetic-dry-run-rework -Mode dry-run` | PASS, 6 events, 1 expected hit, 4 unique branches, 3 parent-link rows |
| `pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/replay-agentic-transcript.ps1 -TranscriptPath ._analysis/chat_log.jsonl -OutputDir _test_output/stage34-chatlog-dry-run-rework -Mode dry-run` | PASS, 56 events, 23 expected hits, 10 unique branches, 0 parent-link rows |
| `python -m pytest tests/test-stage34-result-analyzer.py -q` | PASS, 1 passed; warning noise from requests and pytest-asyncio |
| `cmake --build build --config Release --target test-cache-controller -j 4` | PASS; pre-existing `%zu` warnings at lines 5446, 5459, 5567 |
| `.\build\bin\Release\test-cache-controller.exe` | PASS, 144/144 |
| `ctest --test-dir build -C Release -R cache -V` | PASS, 1/1 |

## Handoff

Recommend implementation re-review. All four corrections (F34-IMPL-01,
F34-IMPL-02, F34-IMPL-03, F34-PATH-01) have code and evidence coverage.
QA should still own server-backed sequential and concurrent replay after
the review/test-plan gates. Long live Qwen replay remains not run.
