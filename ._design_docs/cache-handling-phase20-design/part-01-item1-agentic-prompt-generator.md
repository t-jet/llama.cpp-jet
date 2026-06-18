# Stage 20 design Part 1: Item 1 - Agentic prompt generator

Source: [../cache-handling-phase20-design.md](../cache-handling-phase20-design.md)

## Overview

Item 1 closes the `BLOCKED-prompt-generator-missing` classification on
Stage 17 test plan rows TP-17-SY1..SY5 by providing a deterministic
chat-prompt generator that emits prompts of specified token sizes
(12k, 24k, 60k). The generator is a test infrastructure tool, not
production code. It lives under
`._design_docs/cache-handling-test-scripts/lib/` next to the existing
test helpers and reuses the same evidence-path conventions.

## Why a new generator is needed

Stage 17 synthetic-tier rows need:

- TP-17-SY1, TP-17-SY2, TP-17-SY3: exact repeat at 12k, 24k, 60k token
  sizes to exercise save/restore on agentic-sized prompts.
- TP-17-SY4: four prompt classes (exact repeat, near-duplicate,
  different agent same prefix, same branch continuation) at one of the
  three sizes.
- TP-17-SY5: 60k prompt plus cold budget pressure to verify bounded
  eviction under agentic workloads.

The existing test inputs use either short deterministic prompts
(< 200 tokens) from the V2 baseline or 60k raw token streams for
benchmarks. Neither is a chat prompt. A dedicated generator is the
minimum surface that produces a real `messages` array with system,
user, and assistant turns, sized to the requested token count, and
deterministic across runs.

## Design choice: PowerShell or Python

The generator is implemented in PowerShell 7. Rationale:

- The repo's test scripts are PowerShell-first per
  `._design_docs/cache-handling-test-scripts/IMPLEMENTATION_GUIDE.md`
  and `qa.md` (`Use pwsh.exe for runner scripts; per-row launch via
  Start-Process with -ArgumentList array`).
- PowerShell can call `Invoke-WebRequest` against the running
  `llama-server` `/tokenize` endpoint without extra dependencies.
- A Python alternative would require a new runtime dependency and
  diverge from the runner conventions.
- The generator is consumed by PowerShell drivers, so a PowerShell
  implementation avoids a language boundary.

## Generator name and location

Script: `._design_docs/cache-handling-test-scripts/lib/agentic-prompt-generator.ps1`.

Public entry point: `New-AgenticChatPrompt` function with parameters:

- `-TargetTokens` (required, int): desired prompt token count.
- `-SizeClass` (required, enum `12k | 24k | 60k`): named size class
  for evidence tagging.
- `-PromptClass` (required, enum `exact-repeat | near-duplicate |
  different-agent-same-prefix | same-branch-continuation`).
- `-OutPath` (required, string): path to write the JSON file.
- `-ServerUrl` (required, string): base URL of the running
  `llama-server` for `/tokenize` calls (e.g., `http://127.0.0.1:18206`).
- `-Seed` (optional, int): deterministic seed (default `42`).
- `-MaxIterations` (optional, int): safety cap on expansion rounds
  (default `50`).

## Output format

The generator writes one JSON file per call:

```json
{
  "version": "stage20-agentic-prompt-v1",
  "size_class": "12k",
  "prompt_class": "exact-repeat",
  "target_tokens": 12000,
  "actual_tokens": 12034,
  "token_measurement": {
    "endpoint": "/tokenize",
    "server_url": "http://127.0.0.1:18206",
    "measured_at_unix": 1739846400,
    "iterations": 3
  },
  "messages": [
    {"role": "system", "content": "You are an agentic assistant ..."},
    {"role": "user", "content": "Section 1: ..."},
    {"role": "assistant", "content": "Acknowledged. ..."},
    {"role": "user", "content": "Section N: ..."}
  ],
  "checksum": "<sha256-of-concatenated-content>",
  "seed": 42
}
```

Fields are bounded; no prompt text leaks to a label, log line, or
metric. The `actual_tokens` value is the server's `/tokenize` response
for the joined messages. The `checksum` is over content only, not
over token ids or model state.

## Token measurement protocol

The generator expands the prompt in rounds. Each round:

1. Appends a templated paragraph (about 200-400 tokens) to the last
   `user` turn's `content` field. The paragraph template is selected
   by `seed` to ensure deterministic content.
2. Calls `POST /tokenize` against the running server with the
   joined messages array as the `content` field of a synthetic
   `/completion` request.
3. Reads the returned `tokens_evaluated` value.
4. Stops when `tokens_evaluated >= TargetTokens` or
   `iterations >= MaxIterations`.

The server must be started with the same model the test plan uses
(Qwen3.5-4B-MTP for synthetic-tier rows per Manager decision
default) and with hybrid mode so `/tokenize` reflects the production
tokenizer. The `actual_tokens` is recorded within `+/- 5%` of
`target_tokens`. Overshoot beyond `+5%` is a generator failure and
the row returns `FAIL` per test plan part-27 Pass/fail criteria.

## Prompt class definitions

Four prompt classes map to TP-17-SY4. The generator produces each
class from a shared content template and the class-specific seed
offset.

- `exact-repeat`: the second call sends the identical messages array;
  expected `cache_n > 0` on the second call.
- `near-duplicate`: the second call differs by one user-turn suffix
  (one word appended); expected bounded miss reason
  (e.g., `checksum_mismatch`) and `unsafe_prefix_rejected` if the
  prefix path is exercised.
- `different-agent-same-prefix`: the second call uses a different
  `system` content but identical `user` content; expected
  `unsafe_prefix_rejected` because the namespace hash differs.
- `same-branch-continuation`: the second call extends the assistant
  turn; expected new save (different boundary) and `cache_n = 0` on
  the second call, `cache_n > 0` on a third identical call.

## Test plan rows proposed

Five synthetic-tier rows reopen TP-17-SY1..SY5 by replacing the
`BLOCKED-prompt-generator-missing` classification with the actual
generator output. Each row records the generator output path under
`._test_output/stage20-syn-YYYYMMDD-NN/<row>/prompt.json` plus the
joined chat-completion request body, response body, and `/metrics`
snapshot.

| ID | Type | Fixture | Preconditions | Command or call | Expected outcome | Evidence | Pass/fail criteria |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TP-20-SY1 | synthetic | generated 12k prompt | Qwen3.5-4B-MTP, hybrid mode, redacted evidence | call generator with `-TargetTokens 12000 -SizeClass 12k -PromptClass exact-repeat`; send two identical chat completions | second request returns `cache_n > 0`; redacted JSONL records one hit and one exact-miss-then-hit | prompt.json + per-request response + JSONL | exact repeat restores at 12k; mirrors TP-17-SY1 |
| TP-20-SY2 | synthetic | generated 24k prompt | same as SY1 | call generator with `-TargetTokens 24000 -SizeClass 24k -PromptClass exact-repeat`; same two-call flow | second request returns `cache_n > 0`; JSONL record present | prompt.json + per-request response + JSONL | exact repeat restores at 24k; mirrors TP-17-SY2 |
| TP-20-SY3 | synthetic | generated 60k prompt | same as SY1 | call generator with `-TargetTokens 60000 -SizeClass 60k -PromptClass exact-repeat`; same flow | second request returns `cache_n > 0`; JSONL record; first-user boundary and boundary count recorded | prompt.json + per-request response + JSONL | exact repeat restores at 60k; mirrors TP-17-SY3 |
| TP-20-SY4 | synthetic | generated prompts in four classes | same as SY1 | run generator four times for each prompt class; send the second call per class | exact-repeat: `cache_n > 0`; near-duplicate: bounded miss reason + `unsafe_prefix_rejected` if prefix path hit; different-agent: namespace hash differs; same-branch: new save then `cache_n > 0` on third identical | four prompt.json files + per-class per-request response + JSONL | four prompt classes produce bounded outcomes; mirrors TP-17-SY4 |
| TP-20-SY5 | synthetic | generated 60k prompt | cold budget 50 MiB; cold path configured | call generator with `-TargetTokens 60000 -PromptClass exact-repeat`; send pressure to exceed budget | bounded eviction OR `cold_demotions_skipped_total` increment; no filesystem write failure | prompt.json + server logs + counter | cold pressure bounded, no write failure; mirrors TP-17-SY5 |

The five rows are direct reopenings of TP-17-SY1..SY5 with the
generator as the prompt source. The test plan at Stage 20 test-plan
authoring renames them to TP-20-SY1..SY5 (or keeps TP-17-SY1..SY5 if
the test plan author prefers minimal renumbering) and reclassifies
them from `BLOCKED-prompt-generator-missing` to PASS or BLOCKED with
a documented harness/setup reason.

## Evidence capture

Each row's evidence path is:

- `._test_output/stage20-syn-YYYYMMDD-NN/<row>/prompt.json`
  (generator output, durable in the sense of being cited in the QA
  test report; not committed to git).
- `._test_output/stage20-syn-YYYYMMDD-NN/<row>/chat-1-request.json`
  and `chat-1-response.json` (first call).
- `._test_output/stage20-syn-YYYYMMDD-NN/<row>/chat-2-request.json`
  and `chat-2-response.json` (second call).
- `._test_output/stage20-syn-YYYYMMDD-NN/<row>/chat-3-request.json`
  and `chat-3-response.json` (third call for TP-20-SY4
  same-branch-continuation).
- `._test_output/stage20-syn-YYYYMMDD-NN/<row>/server.out.log` and
  `server.err.log`.
- `._test_output/stage20-syn-YYYYMMDD-NN/<row>/metrics-before.txt`
  and `metrics-after.txt`.
- The redacted JSONL tail at the
  `--cache-prompt-evidence-dir` path (when redacted evidence is
  enabled).

The QA test report cites the prompt.json path per row plus the actual
token count vs target token count.

## Generator implementation constraints

The generator script must:

- Use LF line endings (no CRLF).
- Use plain ASCII status labels (`PASS`, `FAIL`, `BLOCKED`).
- Avoid `prompt` text in any thrown exception message; the
  `tokenization_failed` error path uses the iteration count and the
  last measured token delta, not the prompt content.
- Stop after `MaxIterations` to bound runtime; a row that exceeds
  `MaxIterations` returns `FAIL` (not `BLOCKED`) because the
  generator contract was unmet.
- Use `Invoke-WebRequest` with `-TimeoutSec 30` per request to avoid
  hangs.
- Use `ConvertTo-Json -Depth 10` to keep nested messages round-trip
  clean.
- Record the actual token count within `+/- 5%` of `target_tokens`;
  overshoot beyond `+5%` is a row failure.

## Generator reuse beyond synthetic tier

The same generator is reused by Item 3 (S/L framework re-invocation)
for stress and long-run rows that need agentic-sized prompts. The
generator is invoked once per size class per row, with the output
written to the row's evidence directory. Stress and long-run rows
do not depend on a live chat-completion per request; they replay the
joined prompt across many iterations.

## Open questions

- OQ-20-01: should the generator emit a Joriginal or Jmarked chat
  template variant to match the Stage 12/15 S/L framework's
  Joriginal/Jmarked split? The default is `chat_template_new.jinja`
  from the Qwen3.5-4B-MTP fixture; S/L rows may need a second
  parameter `-JinjaVariant` with values `original | marked`. The
  parameter is deferred to the implementation plan; the design leaves
  it open so the Developer can decide based on framework contracts.

## Handoff for Item 1

Implementation plan and implementation are NOT STARTED. The Manager
design gate does not block Item 1; only Item 2 requires
R-20-DESIGN-MGR-01. Implementation planning for Item 1 can proceed
in parallel with the Manager decision on Item 2.

This file uses LF line endings, plain ASCII status labels, and stays
under the 300-line durable-doc cap.
