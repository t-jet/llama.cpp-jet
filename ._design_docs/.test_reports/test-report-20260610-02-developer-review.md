# Developer review: test-report-20260610-02

Date: 2026-06-10
Owner: Developer review
Input report: [test-report-20260610-02.md](test-report-20260610-02.md)
Evidence root: [test-report-20260610-02-artifacts/](test-report-20260610-02-artifacts/)

## Verdict

FAIL. Stage 13 endpoint execution cannot close.

All four non-PASS rows from `test-report-20260610-02.md` are product bugs. The CUDA build and fixture prerequisites were present, the affected servers reached readiness, and the failures occurred in public endpoint paths or required bounded diagnostics. A bug-fix loop is required before QA reruns the failed endpoint rows.

## Rows reviewed

| Row | QA verdict | Developer classification | Owner | Retest scope |
| --- | --- | --- | --- | --- |
| E13-01c | FAIL | Product bug | Developer | Native multimodal completion with CUDA Qwen2.5 VL or Omni fixture, including successful miss then hit or restore evidence when fixed. |
| E13-07 | FAIL | Product bug | Developer | CUDA Omni v1 audio transcription endpoint after MTMD abort fix. |
| E13-08 | FAIL | Product bug | Developer | CUDA Omni non-v1 audio transcription alias after MTMD abort fix. |
| E13-14 | FAIL | Product bug | Developer | Native and chat degraded fallback probes with bounded cache metadata diagnostic evidence and leakage scan. |

## Failure classification and evidence

Stage 13 requires real public endpoint evidence after implementation, not synthetic substitute evidence. The design requires native completion coverage for supported multimodal prompt shapes and bounded degraded fallback observability. See [part-03-acceptance-checks-and-handoff.md](../cache-handling-phase13-design/part-03-acceptance-checks-and-handoff.md), which lists multimodal native completion in the minimum endpoint set and requires degraded diagnostics. The QA plan keeps E13-01c visible, treats missing multimodal prerequisites as BLOCKED only when prerequisites are absent, and requires E13-14 to emit bounded diagnostics. See [part-23-stage13-endpoint-compatibility.md](../cache-handling-test-plan/part-23-stage13-endpoint-compatibility.md).

E13-01c is a product bug. The CUDA VL server command used `llama-server.exe` from `build-cuda-stage13`, Qwen2.5 VL model, mmproj, hybrid cache flags, metrics, slots, and CUDA GPU layers in [e13-01c-image-marker-server-command.txt](test-report-20260610-02-artifacts/e13-01c-image-marker-server-command.txt). The server log shows Qwen2.5 VL and mmproj/MTMD startup in [e13-01c-image-marker-server.err.log](test-report-20260610-02-artifacts/e13-01c-image-marker-server.err.log). The documented image marker request then returned 400 `Failed to tokenize prompt` in [E13-01c-image-marker-1-error.txt](test-report-20260610-02-artifacts/E13-01c-image-marker-1-error.txt). A separate Omni multimodal attempt aborted at `tools/server/server-common.cpp:398` with `GGML_ASSERT(!has_mtmd)` in [omni-rerun-server.err.log](test-report-20260610-02-artifacts/omni-rerun-server.err.log). These are not missing-fixture or environment outcomes because the build, model, projector, CUDA runtime, and route attempts were present.

E13-07 is a product bug. The CUDA Omni server command includes model, mmproj, hybrid cache, metrics, slots, and CUDA GPU layers in [audio-only-server-command.txt](test-report-20260610-02-artifacts/audio-only-server-command.txt). The request reached the transcription adapter: [audio-only-server.err.log](test-report-20260610-02-artifacts/audio-only-server.err.log) records `Request converted: OpenAI Transcriptions -> OpenAI Chat Completions`, audio token processing with `audio_tokens->n_tokens = 750`, then `GGML_ASSERT(!has_mtmd)` at `server-common.cpp:398`. Curl reported connection reset in [E13-07-audio-only-v1-curl.err.txt](test-report-20260610-02-artifacts/E13-07-audio-only-v1-curl.err.txt). This is a product crash after endpoint conversion, not a QA harness defect.

E13-08 is the same product bug on the non-v1 alias. [audio-alias-first-server-command.txt](test-report-20260610-02-artifacts/audio-alias-first-server-command.txt) uses the same CUDA Omni prerequisites. [audio-alias-first-server.err.log](test-report-20260610-02-artifacts/audio-alias-first-server.err.log) records transcription conversion, audio token processing, and the same `GGML_ASSERT(!has_mtmd)` at `server-common.cpp:398`. [E13-08-audio-alias-first-curl.err.txt](test-report-20260610-02-artifacts/E13-08-audio-alias-first-curl.err.txt) shows curl exit 56 connection reset. The alias route is registered and reaches product code, so this is not blocked or environment-only.

E13-14 is a product bug. The implementation evidence says degraded diagnostics should emit a bounded debug line shaped as `cache metadata: source=<route-family> method=<method> degraded=<reason> tokens=<n> boundaries=<n>` in [part-08-implementation-evidence.md](../cache-handling-phase13-implementation/part-08-implementation-evidence.md). Architect review accepted that contract as gated on degraded metadata in [part-09-architect-implementation-review.md](../cache-handling-phase13-implementation/part-09-architect-implementation-review.md). QA artifacts show the probes completed and leakage scans found no marker, request, or response lines, but both [E13-14-diagnostic-lines.txt](test-report-20260610-02-artifacts/E13-14-diagnostic-lines.txt) and [E13-14-chat-diagnostic-lines.txt](test-report-20260610-02-artifacts/E13-14-chat-diagnostic-lines.txt) say no cache metadata diagnostic line was emitted. That misses the Stage 13 observability contract.

## Product bug list

| Bug ID | Rows | Product failure |
| --- | --- | --- |
| S13-BUG-20260610-02-01 | E13-01c, E13-07, E13-08 | MTMD multimodal/audio request paths can abort `llama-server` through `GGML_ASSERT(!has_mtmd)` after media or audio prompt handling. |
| S13-BUG-20260610-02-02 | E13-01c | Native multimodal completion with Qwen2.5 VL plus mmproj can return 400 `Failed to tokenize prompt` instead of reaching miss or hit/restore behavior. |
| S13-BUG-20260610-02-03 | E13-14 | Degraded fallback requests can complete without the required bounded `cache metadata` diagnostic line. |

Product bug count: 3.

## Retest scope

After Developer fixes and bug-fix review, QA must rerun:

- E13-01c with the CUDA multimodal fixture and hybrid cache flags, proving successful endpoint behavior and cache miss then hit or restore.
- E13-07 and E13-08 with the CUDA Omni audio fixture, proving no process abort or connection reset and checking route-neutral preparation evidence if the endpoint completes.
- E13-14 native and chat degraded probes, proving the bounded diagnostic line is present and leakage scans still pass.
- E13-16 clean build and fresh report gate for the rerun session, because any endpoint rerun needs fresh build evidence.

E13-10 and E13-13 passed in this report and do not need rerun unless a fix touches `/slots`, route-neutral helper behavior, build setup, or shared prompt metadata paths.

## Next owner/gate

Next owner: Developer bug-fix loop.

Next gate: bug-fix implementation and review for S13-BUG-20260610-02-01 through S13-BUG-20260610-02-03, followed by QA rerun of the retest scope above. Manager closure should remain blocked until the rerun report passes or Manager explicitly reclassifies a row with new design evidence.
