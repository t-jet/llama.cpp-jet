# Part 16: Manager closure 2026-06-25

Status: closed; Manager gate decision D-CLOSURE-24-01 2026-06-25
Date: 2026-06-25
Stage: 24 (Chat-Completion S02/S03 Cache Comparison)
Owner: Manager (closure) and Architect (closure sweep)
Scope: closure record for Stage 24 implementation log; Stage 24 is closed with documented structural blocker per D-CLOSURE-24-01.

## Summary

Stage 24 ran four live QA executions against the
`stage24-chat-s02-s03-comparison.ps1` runner using the Qwen3.5-4B MTP
fixture and the existing `build-cuda` path. The runner, dry-run gate, route
contract, leak scan, cold budget, and CUDA build/runtime proof all stayed
green across runs.

The product side produced two distinct product bugs and one structural
runtime defect:

- The `-04` report exposed a demote cascade stall in
  `mark_payload_kind_evicted` that overran the 512 MiB hot budget.
- The `-05` report exposed a token-limit pin in `enforce_size_limits`
  that held the cache above the 4096 token limit for hundreds of cycles.
- The `-06` report exposed a silent server termination during
  chat-format processing that reproduces on the same fixture and hybrid
  flags and is not a hybrid cache code defect.

Developer fixed the first two bugs and they were verified by runs `-05`
and `-06`. The third defect is reclassified as BLOCKED-structural-not-infra
under D-EXEC-24-03 and is left for a future stage.

## Test report summary

| Report | Build proof | S02-chat | S03-chat | Note |
| --- | --- | --- | --- | --- |
| test-report-20260624-03 | PASS | FAIL (http-request) | FAIL (http-request) | blocked setup evidence only |
| test-report-20260624-04 | PASS | FAIL (http-request) | FAIL (http-request) | triggers D-EXEC-24-01 demote fix |
| test-report-20260624-05 | PASS | PASS | FAIL (http-request) | triggers D-EXEC-24-02 token fix |
| test-report-20260624-06 | PASS | PASS | FAIL (http-request) | D-EXEC-24-03 silent crash |

The runner, leak scan, cold budget, and CUDA runtime proof remained
clean across `-04`, `-05`, and `-06`. The S02 hybrid near-prefix nonzero
`cache_n` count was zero in `-05` and `-06`, satisfying R24-TP-03.

## Per-row final classification

| Row | Variant | Verdict | Evidence |
| --- | --- | --- | --- |
| S02-chat | native-legacy | PASS | test-report-20260624-06.md |
| S02-chat | hybrid-stage24 | PASS (was FAIL-http-request in -04; D-EXEC-24-01 verified) | test-report-20260624-06.md |
| S03-chat | native-legacy | PASS | test-report-20260624-06.md |
| S03-chat | hybrid-stage24 | BLOCKED-structural-not-infra (D-EXEC-24-03) | test-report-20260624-06.md |
| S03 unsafe-prefix check | hybrid-stage24 | PASS (hybrid near-prefix cache_n=0 across -04, -05, -06) | test-report-20260624-04.md, test-report-20260624-05.md, test-report-20260624-06.md |

## Manager decisions (verbatim)

### D-EXEC-24-01

Demote cascade fix verified clean. S02 hybrid 10 -> 0 demote warnings,
S03 hybrid 152 -> 0 demote warnings. Code change
`tools/server/server-cache-hybrid.cpp` (mark_payload_kind_evicted
over_hot_budget guard). Accept.

### D-EXEC-24-02

Token-limit pin fix verified. S02 hybrid max 704 tokens (was 507 MiB /
unknown tokens in -04), S03 hybrid max 4096 tokens reached on 0.7% of
cache state lines (was 9177 tokens / 72.5% over-budget in -05). Code
change `tools/server/server-cache-hybrid.cpp` (enforce_size_limits
guaranteed-progress fallback). Accept.

### D-EXEC-24-03 (NEW, structural)

S03 hybrid server dies silently at request 258 (run -05) or request 281
(run -06) during chat-format processing. No FATAL/OOM/SEGV/exception
marker in server.err.log. Cache state at death under both MiB and token
budgets. Reproducible with Qwen3.5-4B-MTP fixture, --cache-mode hybrid,
--cache-ram 512, --cache-cold-path, --cache-cold-max-mib 512,
--cache-prompt-evidence redacted. Reclassify S03-chat hybrid row to
BLOCKED-structural-not-infra (D-EXEC-24-03). Not a hybrid cache code
bug (iter 1 + iter 2 verified); appears to be silent Windows process
termination during cold-store write or memory pressure at chat-format
processing boundary. Future SEH handler + S03 crash investigation
required.

### D-CLOSURE-24-01

Close Stage 24 with code changes UNCOMMITTED per AGENTS.md. User
approval required for commit. Follow-ups:

- (a) Add Windows SEH handler + crash-dump generation to llama-server
  for future diagnosability
- (b) S03 hybrid silent crash investigation as a future stage (Stage
  25 or later)
- (c) Cold-store metric vs filesystem drift (5.78 GiB on disk vs 351.7
  MiB metric) - separate observation, persists from -05

## Code change summary

Both fixes are uncommitted per AGENTS.md and D-CLOSURE-24-01. The
modified file is:

- `tools/server/server-cache-hybrid.cpp`

The two fixes are:

- D-EXEC-24-01: `mark_payload_kind_evicted` over_hot_budget guard in
  the demote path. Demote-first still runs when at or below budget so
  cold-store semantics stay unchanged for steady-state work. When the
  cache is over the hot budget, the demote attempt is skipped and the
  eviction path runs immediately.
- D-EXEC-24-02: `enforce_size_limits` guaranteed-progress fallback in
  the token-limit loop. When `build_policy_candidates()` returns empty
  while the cache is still over the token budget, walk `entries` and
  force-evict one unprotected entry per iteration. Fall through to
  protected entries only when no unprotected entry remains. Break only
  when no entry is safe to evict.

User approval is required before commit per AGENTS.md and
D-CLOSURE-24-01.

## Follow-up tasks

- (a) Add Windows SEH handler + crash-dump generation to llama-server
  for future diagnosability. Owner: future stage. Rationale: the
  silent termination that caused D-EXEC-24-03 left no FATAL/OOM/SEGV
  marker in server.err.log and an SEH handler would have preserved a
  crash dump and exit code for diagnosis.
- (b) S03 hybrid silent crash investigation as a future stage (Stage
  25 or later). Owner: future stage. Rationale: D-EXEC-24-03 is
  classified BLOCKED-structural-not-infra and the iter 2 token-limit
  fix delays but does not eliminate the crash. The crash root cause is
  separate from the over-budget pin and needs its own design scope.
- (c) Cold-store metric vs filesystem drift (5.78 GiB on disk vs 351.7
  MiB metric in S02 hybrid -06). Owner: future observation. Rationale:
  the metric-based budget check passes and the runner classifies the
  leg as PASS. The drift persists from -05 and is recorded as a
  separate observation rather than a new defect.

## Handoff

Next owner: user.

The user owns the commit decision for the two uncommitted code changes
in `tools/server/server-cache-hybrid.cpp`. Per AGENTS.md and
D-CLOSURE-24-01, AI agents do not commit or push without explicit user
approval. Once the user commits, the follow-up tasks above (SEH
handler, S03 crash investigation, cold-store metric drift) remain open
as separate future stages or observations.

This file uses LF line endings, plain ASCII status labels, no BOM, no
trailing whitespace, and stays under the 300-line durable-doc cap.
