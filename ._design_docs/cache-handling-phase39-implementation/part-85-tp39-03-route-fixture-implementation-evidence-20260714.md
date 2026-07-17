# Part 85: TP-39-03 route fixture implementation evidence

Date: 2026-07-14
Status: HISTORICAL BLOCKED; REVIEWED IN PART 86
Authority: D39-EXEC-19

## Implementation

`tools/server/tests/unit/test_stage39_live_pressure.py` now has a dedicated
`Stage39MTPServer` used only by these nodes:

- `test_live_pressure_prepared_proof_midpoint_fault_coherent_terminal`
- `test_live_pressure_prepared_proof_step2_fault_coherent_terminal`

The existing `Stage39Server` and its default fixture remain unchanged for all
other tests. The new helper uses the Part 45 model, template, literal request,
startup budgets, route, and guarded schema. Each node creates a fresh server,
port, token, cold root, artifact directory, and one-shot session. It checks the
20-minute wall, 16 GiB RSS, and 4 GiB cold-root caps before each operation.

The helper records the command, environment variable names without values,
model metadata, literal request bytes and hash, response, startup log, resource
samples, and fixed preflight result. Discovery, proof, apply, retrieval, and
final artifacts are written only when the preceding gate passes. Tokens and
HMAC values are redacted from durable JSON.

No product code, guarded route schema, production policy, cold format, metric,
or unguarded path changed.

## Exact execution

Environment:

```text
LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1
LLAMA_SERVER_BIN_PATH=build-stage39-seam-on/bin/Release/llama-server.exe
```

Command:

```text
python -m pytest -q \
  tools/server/tests/unit/test_stage39_live_pressure.py::test_live_pressure_prepared_proof_midpoint_fault_coherent_terminal \
  tools/server/tests/unit/test_stage39_live_pressure.py::test_live_pressure_prepared_proof_step2_fault_coherent_terminal
```

Result:

```text
2 failed, 0 passed, 0 skipped in 395.85s
```

Both nodes stopped before `apply` with:

```text
BLOCKED-route-fixture-capability:
creating MTP draft context, bounded partial sequence removal, draft-mtp
```

## Preflight evidence

Both processes proved:

- model size: 2,834,975,040 bytes;
- architecture: `qwen35`;
- context length: 262144;
- NextN layers: 1;
- literal request bytes: 5,687;
- request SHA-256:
  `d34dee12bb4b0c0782975f853f25a9a063f1a01d76d1552de1202e7457379a49`;
- chat response: HTTP 200;
- idle discovery: reached;
- cold-root bytes: 0;
- checkpoint maximum: 32;
- checkpoint spacing: 0;
- three real context checkpoints created.

Midpoint resource maximums were 197.766 seconds, 5,330,247,680 RSS bytes,
and 0 cold bytes. Step-2 maximums were 197.282 seconds, 5,330,849,792 RSS
bytes, and 0 cold bytes. Neither node approached a cap.

## Blocker

The exact Part 45 startup flags do not select `draft-mtp`. Current
`common_params_speculative` defaults to `COMMON_SPECULATIVE_TYPE_NONE`, and
`tools/server/server-context.cpp` creates the MTP draft context only when the
configured type list contains `COMMON_SPECULATIVE_TYPE_DRAFT_MTP`.

The logs therefore contain `speculative decoding will use checkpoints` and
real checkpoint creation, but they do not contain the three required MTP
capability records. The source save also reports `dft: 0.000`, which confirms
that the process did not create a draft payload.

Adding `--spec-type draft-mtp`, weakening the Part 45 startup preflight, or
continuing to discovery/proof would change the approved fixture contract.
D39-EXEC-19 does not authorize any of those actions. No apply, fallback,
synthetic pair, owner reassignment, canonical TP-39-03 run, coverage run, full
route suite, or full QA run occurred.

## Artifacts

- `._test_output/stage39-route-fixture/midpoint-fault-1783978932045684300-13344`
- `._test_output/stage39-route-fixture/step2-fault-1783979130282124200-13344`

Each directory contains `command.json`, `model-metadata.json`,
`source-request.json`, `source-request-sha256.json`, `source-response.json`,
`server.log`, `resource-capture.json`, and `preflight-result.json`. No apply
artifact exists because both preflights failed closed.

## Verdict and next gate

D39-EXEC-19 is BLOCKED at fixture capability preflight. Part 86 completes the
fresh Architect review: current evidence is narrow REWORK, while design Part 46
passes with the exact selector and coupled preflight correction. Manager now
owns authorization for a fresh two-node rerun. The nodes must reach
`2 passed, 0 failed, 0 skipped` before QA or coverage can resume.
