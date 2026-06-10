# Developer review: test-report-20260610-03

Date: 2026-06-10
Owner: Developer review
Input report: [test-report-20260610-03.md](test-report-20260610-03.md)
Evidence root: [test-report-20260610-03-artifacts/](test-report-20260610-03-artifacts/)

## Verdict

FAIL. Stage 13 endpoint execution cannot close.

One non-PASS row was present in report 03. E13-14 is a product bug: the native
and chat degraded probes completed on a fresh CUDA Release server, but the
required bounded `cache metadata:` diagnostic line was not emitted. The bug-fix
loop continues.

## Rows reviewed

| Row | QA verdict | Developer classification | Owner | Retest scope |
| --- | --- | --- | --- | --- |
| E13-14 | FAIL | Product bug | Developer | Native `/completion` and `/v1/chat/completions` degraded fallback probes must emit the bounded `cache metadata:` diagnostic line, keep leakage scan clean, and run under a fresh E13-16 build/report gate. |

## Failure classification and evidence

E13-14 requires degraded fallback requests to emit bounded existing diagnostics.
The test plan says prompt text, marker text, tool args, paths, checksums,
payload bytes, or raw media in logs/metrics are failures, and requires a
degraded request, log excerpt, `/metrics`, and leakage scan. See
[part-23-stage13-endpoint-compatibility.md](../cache-handling-test-plan/part-23-stage13-endpoint-compatibility.md).

Report 03 met the rerun preconditions. The rerun used a clean CUDA Release build
with `llama-server` and `test-cache-controller` exit 0 evidence in
[cuda-clean-release-build.log](test-report-20260610-03-artifacts/cuda-clean-release-build.log)
and
[cuda-build-release-targets.log](test-report-20260610-03-artifacts/cuda-build-release-targets.log).
The E13-14 server command used the CUDA `llama-server.exe`, Qwen3 model,
`--cache-mode hybrid`, `--cache-ram 100`, `--metrics`, `--slots`,
`--log-verbosity 5`, and CUDA GPU layers in
[e13-14-qwen-degraded-server-command.txt](test-report-20260610-03-artifacts/e13-14-qwen-degraded-server-command.txt).

The endpoint probes completed rather than failing in the harness or environment.
[E13-14-native-degraded-status.txt](test-report-20260610-03-artifacts/E13-14-native-degraded-status.txt)
and
[E13-14-chat-degraded-status.txt](test-report-20260610-03-artifacts/E13-14-chat-degraded-status.txt)
both report `status=OK`. The responses show normal native and OpenAI chat
response shapes with `timings.cache_n=0` in
[E13-14-native-degraded-response.json](test-report-20260610-03-artifacts/E13-14-native-degraded-response.json)
and
[E13-14-chat-degraded-response.json](test-report-20260610-03-artifacts/E13-14-chat-degraded-response.json).
The metrics endpoint also reported hybrid cache activity, including two
entries, two misses, and two namespace records, in
[e13-14-qwen-degraded-metrics-end.txt](test-report-20260610-03-artifacts/e13-14-qwen-degraded-metrics-end.txt).

The failure is the missing required diagnostic. The request fixtures included
degraded/leakage sentinel content in
[E13-14-native-degraded-request.json](test-report-20260610-03-artifacts/E13-14-native-degraded-request.json)
and
[E13-14-chat-degraded-request.json](test-report-20260610-03-artifacts/E13-14-chat-degraded-request.json).
The leak scan passed for checked secrets, but only because no diagnostic line was
present:
[E13-14-log-scan.txt](test-report-20260610-03-artifacts/E13-14-log-scan.txt)
states `diagnostic-line leak scan clean for checked secrets; no diagnostic line
present`. The direct diagnostic capture says
`no cache metadata diagnostic line emitted` in
[E13-14-diagnostic-lines.txt](test-report-20260610-03-artifacts/E13-14-diagnostic-lines.txt).

This is not a test defect. QA supplied requests, responses, server command,
server logs, metrics, and a focused diagnostic-line scan. It is not an
environment issue because the server started, accepted both endpoint requests,
returned OK statuses, and exposed hybrid metrics. It is product behavior because
the implementation no longer satisfies the Stage 13 degraded diagnostic
contract after the prior bug-fix loop.

## Product bug list

| Bug ID | Rows | Product failure |
| --- | --- | --- |
| S13-BUG-20260610-03-01 | E13-14 | Degraded fallback requests complete without the required bounded `cache metadata:` diagnostic line. |

Product bug count: 1.

## Retest scope

After Developer fixes and review, QA should rerun:

- E13-14 native `/completion` degraded probe and OpenAI `/v1/chat/completions`
  degraded probe.
- E13-14 diagnostic capture, proving at least one bounded `cache metadata:`
  line is emitted for each degraded route family under the accepted contract.
- E13-14 leakage scan, proving the emitted diagnostic does not contain prompt
  text, marker text, tool args, paths, checksums, payload bytes, raw media, or
  sentinel secrets from the request fixtures.
- E13-16 clean build and fresh report gate for the rerun session.

E13-01c, E13-07, E13-08, and E13-16 passed in report 03. They do not need rerun
unless the fix touches shared endpoint routing, multimodal/audio handling,
hybrid cache admission/lookup, CUDA build setup, or report freshness evidence.

## Next owner/gate

Next owner: Developer bug-fix loop.

Next gate: fix and review S13-BUG-20260610-03-01, then QA focused rerun of
E13-14 and E13-16. Stage 13 closure remains blocked until E13-14 passes or
Manager/Architect changes the degraded diagnostic acceptance contract with
explicit design evidence.
