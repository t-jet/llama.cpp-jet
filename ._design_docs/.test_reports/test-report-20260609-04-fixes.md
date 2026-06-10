# Fixes handoff for test-report-20260609-04

## Verdict

BLOCKED follow-up. No product bug is confirmed in this QA run.

## Items

| ID | Type | Evidence | Required fix |
| --- | --- | --- | --- |
| S13-QA-BUILD-01 | Build or local environment | Clean build captured `test-cache-controller.exe`, but execution could not find it. Direct rebuild then failed with `LINK : fatal error LNK1104: cannot open file 'D:\source\llama.cpp-jet\build\bin\Release\test-cache-controller.exe'`. | Stabilize focused test binary output or local file locking before rerun. Preserve binary timestamp after build and run `test-cache-controller` immediately. |
| S13-QA-HARNESS-01 | Harness | Artifact helper initially used PowerShell `$Args`; this produced null `Start-Process -ArgumentList`. | Use explicit names such as `$ServerArgs` in all PowerShell helpers. |
| S13-QA-HARNESS-02 | Harness | One-off slot rerun repeated the `$args` collision and started router mode on port 8080, so `/slots` save/restore/erase did not run. | Rerun `/slots` sequence with corrected argument variable and model server readiness proof. |
| S13-QA-EVIDENCE-01 | Missing evidence | Multimodal model, mmproj, and image fixtures exist, but E13-01c did not complete. E13-14 degraded fallback probe also did not complete. | Rerun E13-01c with Qwen2.5-VL plus `mmproj-model-f16.gguf`; add a bounded degraded fallback request and leakage scan. |
| S13-QA-FIXTURE-01 | Fixture blocker | Audio transcription routes return 501 with current text model: `The current model does not support audio input.` | Provide an audio-capable local model/mmproj fixture, or record Manager/design decision for unavailable audio fixture handling. |

## Rerun scope

Rerun only blocked rows first: E13-01c, E13-07, E13-08, E13-10, E13-13, and E13-14. Keep the passing text and embedding endpoint evidence unless code or build changes.
