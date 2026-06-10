# Stage 13 bug-fix loop for test-report-20260610-03

Date: 2026-06-10
Owner: Developer bug-fix loop
Input reports:

- [test-report-20260610-03.md](test-report-20260610-03.md)
- [test-report-20260610-03-developer-review.md](test-report-20260610-03-developer-review.md)

Evidence root: [test-report-20260610-03-artifacts/](test-report-20260610-03-artifacts/)

## Scope

This fixes one product bug from the Developer review:

| Bug ID | Rows | Status |
| --- | --- | --- |
| S13-BUG-20260610-03-01 | E13-14 | Fixed in code; ready for Architect review, then CUDA endpoint rerun. |

No full QA rerun was performed in this session.

## Root cause

The degraded metadata helper built the right internal state, and the native
and chat adapters passed safe route labels. The only diagnostic emission lived
inside request-side metadata construction. Report 03 proved that was not a
reliable endpoint diagnostic point for the E13-14 probes: both requests finished,
hybrid metrics recorded misses and namespace rows, but the captured server log
had no `cache metadata:` line.

The worker still received degraded `prompt_metadata`, but it did not carry the
route label into the slot state. There was no second log point after task launch,
where the server can prove the request produced cache metadata without logging
the request body.

## Fix scope

| File | Change |
| --- | --- |
| `tools/server/server-task.h` | Added internal `diagnostic_source` to `prepared_prompt_metadata` and a `degraded_diagnostic_required()` helper. |
| `tools/server/server-context.cpp` | Stored the bounded route label in metadata and moved the `cache metadata:` info log to slot launch, after degraded metadata is attached to a completion task. |
| `tests/test-cache-controller.cpp` | Extended Stage 13 route-neutral regression coverage to prove diagnostic source drives the log decision and does not affect cache namespace matching. |
| `._design_docs/cache-handling-phase13-implementation.md` | Updated current gate and handoff for Architect review of this fix. |
| `._design_docs/cache-handling-phase13-implementation/part-08-implementation-evidence.md` | Added this durable behavior change and focused evidence. |
| `._design_docs/document-index.md` | Added this fix report to the Stage 13 report index. |

The emitted line remains bounded:

```text
cache metadata: source=<route-family> method=<method> degraded=<reason> tokens=<n> boundaries=<n>
```

It does not include prompt text, marker text, tool arguments, paths, checksums,
payload bytes, raw media, request bodies, or response bodies.

## Focused evidence

| Command | Result |
| --- | --- |
| `cmake --build build --config Release --target test-cache-controller` | PASS, exit 0. |
| `build\bin\Release\test-cache-controller.exe` | PASS, exit 0. Output includes `Stage 13 route-neutral preparation identity... PASSED` and total `89 tests`. |
| `ctest --test-dir build -C Release -R test-cache-controller --output-on-failure` | PASS, exit 0. `1/1 Test #28: test-cache-controller ............ Passed`. |
| `cmake --build build --config Release --target llama-server` | PASS, exit 0. Built `build\bin\Release\llama-server.exe`. |
| `git diff --check -- tools/server/server-task.h tools/server/server-context.cpp tests/test-cache-controller.cpp ._design_docs/.test_reports/test-report-20260610-03-fixes.md ._design_docs/cache-handling-phase13-implementation.md ._design_docs/cache-handling-phase13-implementation/part-08-implementation-evidence.md ._design_docs/document-index.md` | PASS, exit 0. |

## Test coverage note

Direct endpoint log capture remains QA-only because it needs a running
`llama-server`, model fixture, HTTP request pair, log files, and leakage scan.
The focused unit coverage verifies the state that now controls the product log
decision: degraded metadata plus an internal diagnostic source requires a
diagnostic, and changing only that source does not alter cache namespace
matching.

## Remaining risk

The focused unit test covers internal metadata state and namespace behavior. It
does not prove that a CUDA model-backed server run flushes the line into QA's
captured log files. That remains the E13-14 endpoint rerun.

## Retest scope

QA should rerun:

- E13-14 native `/completion` degraded probe.
- E13-14 OpenAI `/v1/chat/completions` degraded probe.
- E13-14 diagnostic capture and leakage scan.
- E13-16 clean build and fresh report gate for the rerun.

Next owner: Architect review of this fix, then QA focused rerun.
