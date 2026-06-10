VERDICT: PASS

# Stage 13 bug-fix review 2026-06-10-3

- Date: 2026-06-10
- Reviewer: Architect
- Scope: S13-BUG-20260610-03-01 from [test-report-20260610-03.md](../../.test_reports/test-report-20260610-03.md)
- Source: [../cache-handling-phase13-implementation.md](../cache-handling-phase13-implementation.md)
- Fix record: [../../.test_reports/test-report-20260610-03-fixes.md](../../.test_reports/test-report-20260610-03-fixes.md)

## Verdict

PASS. S13-BUG-20260610-03-01 is closed. The fix moves the bounded
`cache metadata:` info line to the task launch path so E13-14 degraded
probes emit the line, keeps the line format bounded, and proves
`diagnostic_source` does not enter cache namespace computation.

## Findings

| ID | Severity | Finding | Status |
| --- | --- | --- | --- |
| S13-BUG-20260610-03-01 | Blocker | E13-14 degraded probes produced no `cache metadata:` diagnostic line because emission lived in request-side metadata construction. | Closed. |
| S13-ARCH-20260610-3-01 | None | New `diagnostic_source` is internal to `prepared_prompt_metadata`, stored only for the launch log, and absent from `compute_namespace_id`, `preparation_id`, and the `cache_metadata_build_input` namespace fields. | Non-blocking observation. |
| S13-ARCH-20260610-3-02 | None | `handle_completions_impl` gains a private `cache_diagnostic_source` parameter. Public routes still pass only data and files; no public schema or marker change. | Non-blocking observation. |

Zero open findings.

## Evidence list

- `tools/server/server-task.h:182` adds `std::string diagnostic_source` to `prepared_prompt_metadata`.
- `tools/server/server-task.h:226-228` adds `degraded_diagnostic_required()` returning `degraded() && !diagnostic_source.empty()`.
- `tools/server/server-task.h:235` clears `diagnostic_source` in `clear()`.
- `tools/server/server-context.cpp:1981-1990` emits the bounded `cache metadata:` info line inside slot launch, after `slot.prompt_metadata = task.prompt_metadata` and before `slot.task = std::make_unique<...>`. Emission runs only when `degraded_diagnostic_required()` is true.
- `tools/server/server-context.cpp:4350-4357` introduces `cache_metadata_build_input` with `vocab`, `request_data`, `tokens`, `chat_messages`, and `diagnostic_source` fields. `diagnostic_source` is the only field not consumed by namespace computation.
- `tools/server/server-context.cpp:4491-4493` stores `diagnostic_source` on the metadata when the caller passes a non-null label.
- `tools/server/server-context.cpp:5402-5582` wires a route-family label into each `handle_completions_impl` call site. Embedding, control, token-count, and rerank handlers do not call this path and are unaffected.
- `tools/server/server-context.cpp:6044-6046` documents the embedding cache-exclusion rationale without attaching metadata.
- `tools/server/server-cache-hybrid.cpp:3218-3247` `compute_namespace_id(metadata)` reads `compatibility_key`, `preparation_id`, `degraded_reason`, and `boundaries`. `diagnostic_source` is not referenced.
- `tests/test-cache-controller.cpp:1117-1184` `test_stage13_route_neutral_preparation_identity` proves the diagnostic decision is independent of cache namespace: an entry admitted with `native-completion` matches a lookup whose `diagnostic_source` is `openai-completion`, but a lookup whose `preparation_id` differs does not match.
- `tests/test-cache-controller.cpp:1204-1208` confirms `embedding.prompt_metadata.has_boundaries()` is false and `preparation_id` is empty.

## Five-check verification

| Check | Outcome |
| --- | --- |
| (a) Diagnostic emit at task launch path, not request-side | PASS. `server-context.cpp:1984` runs after `slot.prompt_metadata = task.prompt_metadata` inside the launch path, not in `cache_metadata_for_request`. |
| (b) Bounded line format kept | PASS. `SRV_INF` call uses `source=`, `method=`, `degraded=`, `tokens=`, `boundaries=` with `%s` and `%zu` only. |
| (c) No prompt text, marker text, tool args, paths, checksums, payload bytes, raw media, or body in line | PASS. Format string references five fields; none of them carries body content. |
| (d) `diagnostic_source` not in namespace inputs or `preparation_id` | PASS. `compute_namespace_id` does not read `diagnostic_source`; `cache_metadata_build_input` keeps it as a separate field. |
| (e) No public schema change | PASS. `handle_completions_impl` is private to the server. No route handler, request field, response field, marker, or `/slots` behavior changed. |

## Whitespace check

`git diff --check -- tools/server/server-task.h tools/server/server-context.cpp tests/test-cache-controller.cpp` exit 0. No whitespace errors on touched code paths.

## Assessment

The fix follows the report 03 root cause: the diagnostic moved from
metadata construction to the slot launch path, so the line ties to a
real completion task and survives request handler return. The bounded
line format and the route-family labels match the E13-14 contract from
[part-23-stage13-endpoint-compatibility.md](../../cache-handling-test-plan/part-23-stage13-endpoint-compatibility.md).
The route-neutral helper, the embedding exclusion, and the namespace
isolation are unchanged from the prior implementation review PASS.

`prepare_prompt_metadata` is internal. The new field cannot leak into
public request or response schemas. The focused unit test
`test_stage13_route_neutral_preparation_identity` is the smallest
production-faithful check that the diagnostic decision does not perturb
namespace matching, and it complements the existing route-neutral
helper tests in the same file.

The fix does not prove the CUDA endpoint log capture. That remains the
E13-14 rerun under
[test-report-20260610-03-fixes.md](../../.test_reports/test-report-20260610-03-fixes.md).

## Required corrections

None.

## Next owner and gate

Next owner: QA.

Next gate: rerun E13-14 native `/completion` and `/v1/chat/completions`
degraded probes plus E13-16 clean build and fresh report gate, per the
retest scope in
[test-report-20260610-03-fixes.md](../../.test_reports/test-report-20260610-03-fixes.md).
Stage 13 closure remains not started.
