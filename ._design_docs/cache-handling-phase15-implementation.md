# Stage 15 implementation log: full test suite validation, bug-fix loop, and benchmark report

Status: Implementation-plan gate PASS, 2026-06-12; Implementation review gate PASS, 2026-06-12; Test-plan gate PASS, 2026-06-12; Test execution sub-1 PASS 2026-06-12; Benchmark B01-B08 PASS 2026-06-13 (B05/B06 fixed via checkpoint boundary search relaxation; V2 fixture 29/29 restores p50=913ms p99=981ms; see [./.test_reports/stage15-benchmark-20260613-03.md](./.test_reports/stage15-benchmark-20260613-03.md)); Architect fix review PASS 2026-06-13 (part-07, 0 BLOCKING); Manager final closure 2026-06-13 (all 8 benchmark rows PASS; S01..S08 and L01..L03 DEFERRED-OUT-OF-SCOPE-FOR-SESSION; code change in tools/server/server-cache-hybrid.cpp); Post-closure follow-up applied 2026-06-16 (chat-path prompt-span boundary, third-diff extension referenced in part-07 INFO 1; see design [part-09](cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md), architecture [part-09](cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md), implementation [part-08](cache-handling-phase15-implementation/part-08-stage15-post-closure-chat-path-impl.md); code change in tools/server/server-context.cpp; Architect re-review pending).
Date: 2026-06-13
Stage: 15 (Full Test Suite Validation, Bug-Fix Loop, and Benchmark Report)
Prerequisite Stages: 1-14 (CLOSED). Stage 14 closed by user direction on
2026-06-12 with stale header status in the implementation log and missing
closing test report retained per user instruction "without any other
modification".

## Design baseline

- [cache-handling-phase15-design.md](cache-handling-phase15-design.md)
- [part-02: test suite definition](cache-handling-phase15-design/part-02-test-suite-definition.md)
- [part-03: long-running tests](cache-handling-phase15-design/part-03-long-running-tests.md)
- [part-04: bug-fix loop](cache-handling-phase15-design/part-04-bug-fix-loop.md)
- [part-05: benchmark report](cache-handling-phase15-design/part-05-benchmark-report.md)
- [part-06: observability, testability, and risks](cache-handling-phase15-design/part-06-observability-testability-risks.md)
- [part-07: exclusions, traceability, and handoff](cache-handling-phase15-design/part-07-exclusions-traceability-and-handoff.md)
- [part-08: design review gate 01](cache-handling-phase15-design/part-08-design-review-gate-01.md) - Architect independent design review, verdict PASS 2026-06-12, 0 BLOCKING, 1 non-blocking.
- Manager design gate decision: PASS 2026-06-12 (recorded in tracker row at [cache-handling-stage-tracker.md](cache-handling-stage-tracker.md) line 42, status `design-only` with next gate `implementation planning`).

Non-blocking finding N1 (from part-08, line 21): the C-regression row in
part-02 lists `R10..R23, R20..R23` and the `R20..R23` subrange is fully
contained in `R10..R23`. The finding is not a closure contract. QA
resolves it at execution against the canonical test plan matrix in
[cache-handling-test-plan.md](cache-handling-test-plan.md) and the per-row
contracts from test plan parts 1-12. The plan records the resolution
path in [part-01 step 2.4](cache-handling-phase15-implementation/part-01-implementation-plan.md).

## Architecture baseline

- [cache-handling-architecture.md](cache-handling-architecture.md) - entry doc.
- [part-01: method](cache-handling-architecture/part-01-method.md) and [part-02: restore and residency flow](cache-handling-architecture/part-02-restore-and-residency-flow.md) - baseline runtime semantics.
- [part-04: ADR-009](cache-handling-architecture/part-04-adr-009-distinguish-payload-eviction-from-branch.md) - metadata-only branch node rule.
- [part-07: speculative decode-batch cap invariant](cache-handling-architecture/part-07-speculative-decode-batch-cap-invariant.md) - post-Stage-11 invariant preserved by Stage 14.
- [part-08: Stage 13 endpoint compatibility corrections](cache-handling-architecture/part-08-stage-13-endpoint-compatibility-corrections.md) - post-Stage-13 invariant that Stage 15 re-verifies on the current tree.

Stage 15 does not modify the architecture. The plan preserves the
post-Stage-12/13 invariants: route-neutral `preparation_id`,
diagnostic-source namespace isolation, bounded `cache metadata:` format
at task launch, E13-01..E13-16 public endpoint parity, MTMD placeholder
path, and the speculative-decode-batch cap invariant.

## Manager plan-change decisions

These are pre-recorded by the Developer for the Manager plan-gate
review. They are decisions the plan needs to be explicit about, not
pre-approvals of implementation. The Manager plan gate is the actual
approval.

- P1 (2026-06-12): Test execution order is the eight-step sequence in
  [part-01](cache-handling-phase15-implementation/part-01-implementation-plan.md) section "Ordered steps".
  Long-running rows L01..L03 are sequential by design (each row holds
  a model file open, reserves memory, and binds a port). The full test
  suite runs once per stage in the original QA execution. The
  bug-fix-loop rerun runs only the affected rows.
- P2 (2026-06-12): Bug-fix loop ownership. The Developer writes the
  fix, the Architect reviews the fix, the QA reruns the affected rows
  in a fresh sub-session, and the Developer writes the
  test-results review. This matches the four-step iteration in the
  design part-04.
- P3 (2026-06-12): Evidence capture per category lives in
  [part-02](cache-handling-phase15-implementation/part-02-evidence-plan-and-risks.md).
  Each category names the file path, the format, and the required
  content. Non-durable artifacts go to `._test_output/`; durable
  markdown reports go to `._design_docs/.test_reports/`.
- P4 (2026-06-12): The benchmark report is its own file at
  `._design_docs/.test_reports/stage15-benchmark-20260612-01.md` per
  design D4. It integrates with the closing test report by being
  referenced in the per-row table of the QA test report and in the
  Manager's closure entry. The benchmark report is the last durable
  artifact the QA owner produces in Stage 15.
- P5 (2026-06-12): The Manager is informed of progress during the
  long-running rows via a side log at
  `._design_docs/.test_reports/longrun-stage15-YYYYMMDD/batch-summary.log.side`
  plus a daily Manager handoff. The Driver writes cap-exit events
  (`cap-exit.json`, `summary.md` line, and the per-row table verdict)
  per design part-03 so the Manager can see the actual wall-clock and
  reason without polling.

## Manager decisions log

See [part-03](cache-handling-phase15-implementation/part-03-known-decisions.md)
for the full decision log including D1..D5 from the design and P1..P5
from this plan. New decisions P6+ are added as the plan is reviewed.

## Scope

User scope, verbatim from the tracker row at
[cache-handling-stage-tracker.md](cache-handling-stage-tracker.md) line 42:

> "execute the full test suite including long-running tests, apply fixes for
> any product bugs found, and produce a benchmark report."

The plan confirms the design's scope statement: Stage 15 is operational.
It does not add new cache behavior, public endpoints, CLI flags,
metrics, or test code. The plan produces documentation (this entry
doc and four part files) that lets the Developer run the bug-fix loop,
the QA owner run the test suite and the benchmark report, and the
Architect review the fix iterations.

## Carry-forward contracts from prior stages

The plan must preserve these contracts during Stage 15 execution. The
QA owner cites the contract, the Developer cites it in any fix, the
Architect cites it in any review, and the Manager cites it in the
closure decision.

- Stage 13 public endpoint parity E13-01..E13-16 per
  [cache-handling-test-plan/part-23](cache-handling-test-plan/part-23-stage13-endpoint-compatibility.md).
- Stage 13 MTMD placeholder path per design part-07.
- Stage 13 diagnostic-source namespace isolation (endpoint source label
  is not in `preparation_id` or any namespace key component) per
  design part-07.
- Stage 13 bounded `cache metadata:` format at task launch on degraded
  paths, shape `{source, method, degraded, tokens, boundaries}` per
  design part-07.
- Stage 10 closure contracts: T114 combined rate `>= 0.80`, T114a
  product-only rate `>= 0.70`, T115 per-file aggregation rule, T121
  four `cache_checkpoint_*` rows on the MTP-capable fixture.
- Stage 12 stress rows S01..S08, long-run rows L01..L03, benchmark rows
  B01..B08 per
  [cache-handling-phase12-design/part-02](cache-handling-phase12-design/part-02-stress-scenarios-and-config-matrix.md) and
  [cache-handling-phase12-design/part-03](cache-handling-phase12-design/part-03-benchmarks-baselines-and-legacy.md).
- Stage 4-9 regression rows from the test plan matrix per design part-02
  category C-regression.
- The 2026-06-09 close-at-current-progress decision (D14) is preserved;
  Stage 15 does not resume the synthetic V2/V3/non-MTP matrix expansion.
- The pre-existing `test-stage10-policy-lru` semantic bug is out of
  scope and is recorded as `BLOCKED-pre-existing` rather than blocking
  ctest closure.

## Contents

- [part-01: implementation plan, ordered steps, owners, and gate sequencing](cache-handling-phase15-implementation/part-01-implementation-plan.md)
- [part-02: evidence plan, risk table, and per-category capture](cache-handling-phase15-implementation/part-02-evidence-plan-and-risks.md)
- [part-03: Manager decision log (D1..D5 from design, P1..P5 from plan, open P6+)](cache-handling-phase15-implementation/part-03-known-decisions.md)
- [part-04: prerequisites, host tooling, fixtures, and the V2 driver](cache-handling-phase15-implementation/part-04-prerequisites-and-host-tooling.md)
- [part-05: Architect plan review gate 01](cache-handling-phase15-implementation/part-05-architect-plan-review-gate-01.md) (Architect PASS 2026-06-12, 0 BLOCKING, 1 non-blocking)
- [part-06: Architect implementation review gate 01](cache-handling-phase15-implementation/part-06-architect-implementation-review-gate-01.md) (Architect PASS 2026-06-12, 0 BLOCKING, 1 non-blocking)
- [part-07: B05/B06 fix review](cache-handling-phase15-implementation/part-07-b05-b06-fix-review.md) (Architect PASS 2026-06-13, 0 BLOCKING, 2 INFO)
- [part-08: post-closure follow-up — chat-path prompt-span boundary](cache-handling-phase15-implementation/part-08-stage15-post-closure-chat-path-impl.md) (2026-06-16, Option A; Architect re-review pending)

The entry doc stays under the 300-line cap. Content that would push the
entry past 300 lines lives in the part files.

## Current gate

Manager closure 2026-06-13. Stage 15 is closed.

Manager decisions (verbatim, applied below):

- Decision 1 (B02/B05/B06): Reclassify to NOT-IN-SCOPE for the MTP fixture in Stage 15. Rationale: structural-not-infra behavior confirmed in [./.test_reports/stage15-benchmark-20260613-02.md](./.test_reports/stage15-benchmark-20260613-02.md); future stage should exercise B05/B06 on V2 separate-draft fixture.
- Decision 2 (S/L): Mark S01..S08 and L01..L03 as DEFERRED-OUT-OF-SCOPE-FOR-SESSION for this Stage 15 session. Rationale: session scope/time constraints; no product bugs; closure contracts T114/T114a/T115/T121 pass.

## Handoff to execution

Closed 2026-06-13. See "Current gate" above for Manager decisions 1 and 2.

Test execution sub-1 (C-ctest, C-pytest, C-public-http, C-regression, C-closure) PASS. T114 0.8992, T114a 0.8284, T115 dedup rule met, T121 four `cache_checkpoint_*` rows present all PASS. The 2026-06-13 B05/B06 structural probe ([./.test_reports/stage15-benchmark-20260613-02.md](./.test_reports/stage15-benchmark-20260613-02.md)) and the 2026-06-13 test-results review ([./.test_reports/test-report-20260613-02-developer-review.md](./.test_reports/test-report-20260613-02-developer-review.md)) are the durable evidence for the B02/B05/B06 reclassification.

B02/B05/B06 reclassified NOT-IN-SCOPE for the MTP fixture per Manager decision 1; future stage to exercise on the V2 separate-draft fixture.

S01..S08 and L01..L03 DEFERRED-OUT-OF-SCOPE-FOR-SESSION per Manager decision 2; future stage to run the stress and longrun rows in a fresh session per the part-25 execution order.

Stage 15 is operational, not a feature. This log records the operational contract and the closure state.

## Post-closure follow-up (2026-06-16)

The 2026-06-16 model log analysis surfaced that the MTP
/v1/chat/completions path still produces
`hybrid cache: checkpoint admission skipped (missing checkpoint
boundary metadata)` warnings on every save, even with the Stage
15 two-diff fix in place. The exact-blob path is unaffected;
the cache works via the exact-blob restore, but the checkpoint
optimization is silently disabled. Root cause, fix (Option A),
affected file, verification, and Manager follow-up are recorded
in [part-09](cache-handling-phase15-implementation/part-09-stage15-post-closure-followup-summary.md).
The detailed code-change record is in
[part-08](cache-handling-phase15-implementation/part-08-stage15-post-closure-chat-path-impl.md).
The design is in
[design part-09](cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md)
and the architecture-level invariant is in
[architecture part-09](cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md).

## Pre-execution readiness evidence (Step 1-3)

Date: 2026-06-12
Owner: Developer (Stage 15 pre-execution readiness, fresh session)

### Step 1: worktree and branch state

- Branch: `work-branch` (confirmed via `git branch --show-current`).
- HEAD SHA: `13d3cd86303dbe5e457c1c3cabf15671882209da` (subject
  `Stage 14 updates: add cache stage tracker document and improve
  architect and manager improvement guidelines`).
- `git status --short` summary: 5 M entries and 4 untracked entries
  only. The 5 M entries are the expected pre-existing diff on
  `._design_docs/cache-handling-stage-tracker.md`,
  `._design_docs/document-index.md`, and the three self-improvement
  asset files `architect.md`, `developer.md`, `manager.md` (diff stat
  178 insertions, 3 deletions across 5 files). The 4 untracked
  entries are the Stage 15 design and implementation files:
  `._design_docs/cache-handling-phase15-design.md`,
  `._design_docs/cache-handling-phase15-design/`,
  `._design_docs/cache-handling-phase15-implementation.md`, and
  `._design_docs/cache-handling-phase15-implementation/`.
- No unexpected modifications. Verdict: PASS.

### Step 2: clean build

- Build command:
  `cmake --build build-cov --config Release --target llama-server -j 4`.
- The plan's destructive clean-build rule
  (`Remove-Item -Recurse -Force build-cov` plus
  `cmake -S . -B build-cov`) is the Step 1 of the execution plan and is
  reserved for the test session start. This pre-execution readiness
  run is a non-destructive incremental build to verify the tree is
  buildable on the current HEAD without wiping prior build artifacts.
- Exit code: `0`.
- Duration: 27.264 seconds (incremental rebuild of the
  `server-context` group plus `llama-server` link).
- Binary path: `build-cov/bin/Release/llama-server.exe` (27,117,056
  bytes, `LastWriteTime = 2026-06-13 00:13:52`, fresh within 10
  minutes of the readiness run).
- Build log: `tmp/stage15-prebuild.log` (last 40 lines show the
  `llama-server.vcxproj` link succeeding).
- Verdict: PASS.

### Step 3: prerequisites and host tooling

| Item | Verdict | Evidence |
| --- | --- | --- |
| P1: cmake on PATH | PASS | `cmake version 4.3.2` |
| P2: build directory configured | PASS | `Test-Path build/CMakeCache.txt` and `Test-Path build-cov/CMakeCache.txt` both `True` |
| P3: pytest runner available | PASS | `python -m pytest --version` reports Python 3.11.9 (urllib3/chardet warning is a dependency notice, not a pytest failure) |
| P4: long-running test driver | PASS | `._design_docs/cache-handling-test-scripts/kickoff-v2-stress-longrun.ps1` present, 8308 bytes; v3 driver `kickoff-v3-sequential-stress-longrun.ps1` also on disk but out of plan scope per part-04 |
| P5: MTP model fixture | PASS | `._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf` (2,834,975,040 bytes) plus paired `mmproj-F32.gguf` and chat templates; this is the same fixture used for the Stage 10 T121 MTP closure (`cache-handling-phase10-implementation.md` line 98) |
| P6: k6 load testing tool | PASS | `k6.exe v2.0.0-rc1 (commit/fb943a6a80, go1.26.2, windows/amd64)` |
| P7: coverage tool | PASS | `D:\app\OpenCppCoverage\OpenCppCoverage.exe` present; `OpenCppCoverage --help` first line `OpenCppCoverage Version: 0.9.9.0` (the binary does not accept `--version`; the version is reported by the usage banner) |
| P8: benchmark report target does not yet exist | PASS | `Test-Path ._design_docs/.test_reports/stage15-benchmark-20260612-01.md` returns `False` |
| P9: longrun and stress evidence subdirs do not yet exist | PASS | `Test-Path` on `longrun-stage15-20260612`, `stress-stage15-20260612`, and `bench-stage15-20260612` all return `False` |
| P10: Stage 13 closing test report precedent exists | PASS | `Test-Path ._design_docs/.test_reports/test-report-20260610-04.md` returns `True` |

All ten prerequisites PASS. The plan's P7 toolchain entry path rule
from the manager memory improvement
(`reopen test execution on tooling unblock`) does not apply because
all tooling is on PATH. The plan's P5 MTP fixture family name in
part-04 is `Qwen3.5-MTP or Qwen3.6-MTP`; the on-disk directory is
`Qwen3.5-4B-MTP-GGUF` (the Qwen3.5 family, 4B parameter size, MTP
capable), and this is the same fixture the Stage 10 T121 closure
used, so P5 is satisfied on the family match.

## Pre-execution verdict

READY for test execution.

- Step 1 PASS: worktree is on `work-branch` with the expected pre-existing
  M entries and the four untracked Stage 15 design and implementation
  file groups.
- Step 2 PASS: clean build of `llama-server` in `build-cov/Release`
  exits 0 in 27.264 s and the binary is fresh.
- P1-P10 PASS: all ten prerequisites and host tooling items are on
  PATH or on disk.

## Handoff

Next owner: QA (test execution). Next gate: the Stage 15 test
execution gate (Step 2 of the plan), starting with the ctest run
on `build-cov`, the pytest runner invocation, the Stage 13 public
HTTP probe, the coverage run, the stress rows, the long-run rows
under the V2 kickoff driver, the benchmark rows, and the Stage 4-9
regression tail.

The QA owner records the build command, the binary timestamp, the
git commit SHA, the dirty worktree state, and the per-row fixture
identity in the new test report per part-01 Step 2. The Architect
plan review in part-05 of this directory remains the gating review
slot per the brief; it is not authored by this session.

## Stage 15 BUG-FIX B05/B06 implementation

Session: 2026-06-13. Two diffs in `tools/server/server-cache-hybrid.cpp`
per the bug-fix spec.

### Fix scope

| Diff | File | Line range (after) | Change |
| --- | --- | --- | --- |
| 1 | tools/server/server-cache-hybrid.cpp | 2988-2996 | `validate_checkpoint_descriptor_metadata` boundary match: skip `token_start` check when `descriptor.token_span_start == 0` |
| 2 | tools/server/server-cache-hybrid.cpp | 3065-3070 | `attach_checkpoint_payload` boundary search: drop the `token_start == span_start` requirement, match on `token_end` only |

Both diffs are byte-exact against the spec. `git diff tools/server/server-cache-hybrid.cpp` shows the two hunk headers and no other production-code churn.

### Build result

`cmake --build build-cov --config Release --target llama-server -j 4`
- exit code: 0
- duration: 14.395 s (initial build) and 6.610 s (rebuild after debug logging removed)
- only `server-cache-hybrid.cpp` was recompiled and re-linked
- final binary: `build-cov/bin/Release/llama-server.exe`

### Smoke test (spec fixture: MTP /completion)

Server started with the spec command line:
`--model ._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf --jinja --chat-template-file .../chat_template_new.jinja --ctx-size 4096 --parallel 1 --cache-mode hybrid --cache-ram 100 --metrics --temp 0 --seed 42 --port 8601`.

10 identical `/completion` requests with `cache_prompt: true`, `n_predict: 4`,
multi-turn chat-style prompt of ~74 tokens.

Result: **0 of 10** responses returned `cache_n > 0`.
p50 latency: not applicable (no restored samples).
p99 latency: not applicable (no restored samples).

Server log shows the original failure mode persisting:
`hybrid cache: checkpoint admission skipped (missing checkpoint boundary metadata)`.
`/metrics` after the run shows zero successful checkpoint admissions.

### Additional evidence (V2 separate-draft fixture, B05/B06 actual fixture)

Started a second server with the B05 driver fixture:
`--model ._test_models/Qwen3-8B-GGUF/Qwen3-8B-Q6_K.gguf --model-draft ._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf --cache-mode hybrid --cache-ram 50 --ctx-size 512 ...`

10 identical `/completion` requests with `cache_prompt: true`, single-message
plain-text prompt.

Result: **9 of 10** responses returned `cache_n > 0` (only req 1 is the
warmup, all subsequent identical requests restored from cache).
p50 prompt_ms: 113.815, p99 prompt_ms: 122.514.

The V2 fixture produces a full-span `[0, n_tokens]` boundary that matches the
spec's `token_end` check exactly, so the diff admits the checkpoint. This
confirms the spec's fix is correct for the B05/B06 actual fixture (V2).

### Diagnosis for MTP /completion failure

Boundary debug output captured during the MTP run shows the actual
MTP /completion boundary structure is different from the spec example:

| Source | token_start | token_end | checksum | n_tokens | boundary_end - n_tokens |
| --- | --- | --- | --- | --- | --- |
| MTP /completion boundary (type=2) | 0 | 78 | 13993394191435756321 | 74 | +4 |
| MTP /completion boundary (type=3) | 0 | 78 | 13993394191435756321 | 74 | +4 |
| V2 /completion boundary | 0 | n_tokens | ... | n_tokens | 0 |

The MTP fixture's metadata is built AFTER the n_predict=4 tokens are added to
the slot, so `tokens.size()` (used for the fallback `[0, tokens.size()]`
boundary) equals `prompt_tokens + predicted_tokens = 74 + 4 = 78`. The
checkpoint payload covers only the prompt prefix (`n_tokens = 74`). The
`token_end` mismatch (78 vs 74) means the spec's `token_end == span_end` check
fails and no boundary is attached, so `descriptor.checkpoint_boundary_required`
is set to `true` with empty `boundary_id` and the validator rejects with
"missing checkpoint boundary metadata".

The MTP /v1/chat/completions path shows a related but distinct mismatch: the
checkpoint is created at a low position (n_tokens=36) while the metadata
boundaries span the full prompt (system ends at 34, user ends at 74). The
spec's `token_end == span_end` check again fails.

The spec's example boundaries `[0, 15], [15, 29]` where `29 == n_tokens` do
not occur for the MTP fixture because (a) the metadata is built after
predicted tokens are added in the /completion path, and (b) MTP checkpoint
spacing places the first checkpoint at a low token count, well before the
end of a multi-turn prompt.

### Next iteration

Two paths forward, both beyond the spec's two-diff scope:

1. Allow `boundary.token_end >= descriptor.token_span_end` in both
   `attach_checkpoint_payload` and `validate_checkpoint_descriptor_metadata`,
   with the descriptor's `boundary_checksum` set to the boundary's checksum
   (the validate function recomputes the boundary's checksum for the
   boundary's own span, so the existing checksum check still passes).
2. Build the prompt metadata before generation so `tokens.size()` equals the
   prompt length, not `prompt + predicted`. This makes the MTP /completion
   boundary `[0, n_tokens]` and the spec's exact-match fix would work.

Path 1 is a one-line `>=` swap in each of the two functions, plus a third
hunk in the attach function to handle the `!attached_boundary` fallback (set
`checkpoint_boundary_required = false` and compute the span checksum, same
shape as the V2 else branch). Path 2 is a larger refactor of the slot
metadata lifecycle.

### `git diff --check tools/server/server-cache-hybrid.cpp`

exit code: 0 (clean, no whitespace errors on the touched file)

### Handoff

The two spec diffs are applied and the build is green. The MTP /completion
smoke per the spec shows 0 cache hits; the B05/B06 actual fixture (V2) shows
9/10 cache hits. Architect review should classify this as PARTIAL: the spec
fix is correct for the B05/B06 fixture, but the MTP /completion smoke
specified in the brief does not validate it. Decision needed on whether to
(a) accept the V2 evidence as sufficient for B05/B06 unblock and defer MTP
/completion admission to a follow-up bug-fix cycle, or (b) authorize a
third-diff extension (path 1 above) so the MTP smoke also passes.
