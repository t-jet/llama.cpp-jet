# Part 2: Workload capture mechanism

Status: design in progress (Architect session)
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison - legacy vs hybrid)
Source: [../cache-handling-phase29-design.md](../cache-handling-phase29-design.md)

## Decision

D29-DESIGN-01: Workload capture mechanism is **synthetic-but-representative**
via `_design_docs/cache-handling-test-scripts/lib/agentic-prompt-generator.ps1`
(Stage 20 lib) with a deterministic seed. An optional one-shot logging HTTP
proxy capture is allowed as supplementary ground truth but is NOT required.

## Rationale

The original proposal recommended a logging HTTP proxy in front of one
llama-server instance. That approach has three drawbacks for a Stage 29
comparison:

1. Capture happens once. Any change to capture conditions (driver version,
   agent, time of day) invalidates the comparison.

2. The proxy captures raw chat traffic which may include personally
   identifying information or copyrighted content. This forces a redaction
   pass that adds risk to durable artifacts.

3. Real agentic traffic does not have the controlled branch-forest topology
   that exercises both exact-hit and near-prefix-miss cases. Stage 16 model-
   log analysis ([cache-handling-phase16-implementation/part-09-model-log-analysis.md](../cache-handling-phase16-implementation/part-09-model-log-analysis.md))
   found that real agentic chat requests still miss exact restore
   (`cache_n = 0`) on most turns, which makes the per-request KV-reuse
   comparison noisy.

The synthetic-but-representative approach has the opposite properties:

1. The workload is deterministic; replay against legacy and hybrid uses the
   same JSONL.

2. No real prompts are captured. Redaction is automatic (no raw text in the
   generator output).

3. The Stage 20 lib (`agentic-prompt-generator.ps1`) already implements the
   exact/near-prefix/new-branch class topology that Stage 24 S02/S03 used.
   The 308-line lib is verified and ready.

## Workload shape

The synthetic workload is a sequence of chat-completion requests tagged with
one of three `cache_class` values:

| cache_class | Definition | Stage 24 precedent |
| --- | --- | --- |
| `exact` | Request body identical to a prior request in the same workload. | S03 exact-repeat. |
| `near_prefix` | Request body shares a prefix of length >= 256 tokens with a prior request, but differs in the last 32-128 tokens. | S03 near-prefix. |
| `new_branch` | Request body shares no prefix of length >= 256 tokens with any prior request. | S03 new-branch. |

Distribution (per iteration): 40% exact, 30% near_prefix, 30% new_branch.
This matches Stage 24 S03 distribution intent and exercises all three hybrid
restore paths (exact blob, checkpoint, and warm-miss).

Each request uses:

- `messages`: array of `{role, content}` chat messages, 2-4 messages per
  request.

- `temperature: 0` and `seed: 42` for reproducibility.
- `max_tokens: 8` (small) so the per-request latency is dominated by prompt
  processing, not generation. Matches Stage 24 default.

- `stream: false` (server-side completion only).

Each leg runs 200 requests per cycle. 4 cycles x 2 modes x 200 requests =
1600 total requests. Per-leg cap of 10 minutes allows ~3 seconds per request
on average, with headroom for cold-store load on the first cold miss.

## Workload capture script

The Stage 20 lib (`agentic-prompt-generator.ps1`) is single-prompt per call:
it exposes `New-AgenticChatPrompt` with parameters `-TargetTokens`,
`-SizeClass`, `-PromptClass`, `-OutPath`, `-ServerUrl` and emits ONE prompt
per call into ONE JSON file. It cannot emit a multi-request JSONL with the
Stage 29 40/30/30 distribution directly.

To reconcile this with the Stage 29 design, the driver calls a NEW wrapper
script `lib/compare-legacy-vs-hybrid-workload.ps1` (Stage 29 Item 1, this
correction session). The wrapper dot-sources the Stage 20 lib and loops
`New-AgenticChatPrompt` over an anchor pool, applying the 40/30/30
distribution across the 200-request batch and aggregating per-request JSONL.

**Design correction option (a) chosen**: add the wrapper script rather than
rewriting the driver invocation in part-02 lines 78-87 (which would have
called the Stage 20 lib with parameter names that do not exist). This
option (a) is chosen because (rework list source:
`part-12-design-review-20260628.md`):

- The Stage 20 lib is closed and must not be modified. Option (b) would
  require the driver to inline the loop, duplicating the lib's anchor /
  fresh / suffix-modification logic in `compare-legacy-vs-hybrid.ps1`.
- The wrapper isolates the per-request JSONL aggregation so it is reusable
  for any future A/B test that wants the same cache_class distribution.
- The wrapper script is documented in part-08 as a NEW artefact (not as a
  Stage 20 lib modification).

The driver invokes the wrapper as part of Phase 0.5 (see part-03) once the
tokenize helper is up:

```powershell
. ._design_docs\cache-handling-test-scripts\lib\agentic-prompt-generator.ps1
. ._design_docs\cache-handling-test-scripts\lib\compare-legacy-vs-hybrid-workload.ps1
New-ComparisonWorkload `
    -RequestCount 200 `
    -Distribution @{ exact = 0.4; near_prefix = 0.3; new_branch = 0.3 } `
    -Seed 42 `
    -MaxTokens 8 `
    -ServerUrl http://127.0.0.1:8900 `
    -OutPath "$RunRoot\workload.jsonl"
```text

The wrapper emits ONE JSONL line per request. The per-request fields match
the part-04 metric list:

```json
{
  "request_id": "r-0001",
  "cache_class": "exact",
  "messages": [{"role":"system","content":"..."},{"role":"user","content":"..."}],
  "max_tokens": 8,
  "temperature": 0,
  "seed": 42
}
```text

Field semantics:

- `request_id`: driver-assigned monotonic ID `r-NNNN` (1..200).
- `cache_class`: one of `exact`, `near_prefix`, `new_branch`. Driven by the
  per-request uniform roll against the cumulative distribution
  (exact<0.4, near_prefix<0.7, new_branch otherwise).
- `messages`: array of `{role, content}` chat messages. For `exact`
  requests, an anchor prompt is reused verbatim. For `near_prefix`
  requests, an anchor is reused and the last user message gets a
  deterministic suffix token appended (still shares the prefix). For
  `new_branch` requests, a fresh `different-agent-same-prefix` prompt is
  generated.
- `max_tokens`: server-side cap, default 8 (matches Stage 24 default).
- `temperature`: 0 for determinism.
- `seed`: 42.

The 40/30/30 distribution is enforced ACROSS the 200-request batch, not
per-prompt-class iteration. This matches the Stage 24 S03 distribution
intent (per review finding B-03).

## Optional one-shot proxy capture (supplementary)

The proposal's logging HTTP proxy is allowed as a supplementary ground
truth, NOT as the primary workload source. The proxy implementation:

- Pass-through HTTP forwarding (Python or PowerShell, ~150 lines).
- JSONL log per request: timestamp, method, path, request body, response
  body, wall_clock_ms, http_status.

- 32 MiB body cap to avoid disk exhaustion.
- Graceful shutdown on SIGINT that flushes the log.

The captured JSONL is converted to the same shape as the synthetic
workload by a small adapter that adds a `cache_class` tag (heuristic:
identical request body = `exact`; shared prefix >= 256 tokens = `near_prefix`;
otherwise `new_branch`). The adapter is part of the driver, not a separate
script.

The proxy capture is run ONCE per Manager approval, against `--cache-mode
legacy` only, and the resulting JSONL is replayed against both modes. The
proxy is NOT run inside the comparison loop. This avoids contaminating the
comparison with proxy latency.

## File locations

- Synthetic workload JSONL: `._test_output/stage29-cache-modes-YYYYMMDD-NN/workload.jsonl`
- Optional proxy-captured JSONL: `._test_output/stage29-cache-modes-YYYYMMDD-NN/proxy-capture.jsonl`
- Generator script: `._design_docs/cache-handling-test-scripts/lib/agentic-prompt-generator.ps1` (unchanged)
- Driver (new): `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`

## Handoff

Part 2 reviewable. Part 3 covers the driver sequencing and contention
analysis.
