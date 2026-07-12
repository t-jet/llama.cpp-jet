VERDICT: REWORK

# Stage 38 implementation review

Date: 2026-07-11
Reviewer: Architect
Scope: fresh independent implementation review

## Inputs reviewed

- `AGENTS.md`
- `.agents/skills/architect/SKILL.md`
- `.agents/skills/humanizer/SKILL.md`
- `.agents/skills/caveman/SKILL.md`
- `._design_docs/document-index.md`
- `._design_docs/cache-handling-architecture.md`
- `._design_docs/cache-handling-requirements.md`
- `._design_docs/cache-handling-phase38-design.md`
- `._design_docs/cache-handling-phase38-design/part-01-prefix-checkpoint-partial-restore.md`
- `._design_docs/cache-handling-phase38-design/part-02-cold-budget-gauge-fix.md`
- `._design_docs/cache-handling-phase38-design/part-03-observability-and-tests.md`
- `._design_docs/cache-handling-phase38-design/part-04-design-review-20260711.md`
- `._design_docs/cache-handling-phase38-design/part-05-design-correction-20260711.md`
- `._design_docs/cache-handling-phase38-design/part-06-design-re-review-20260711.md`
- `._design_docs/cache-handling-phase38-design/part-07-manager-design-gate-20260711.md`
- `._design_docs/cache-handling-phase38-implementation.md`
- `._design_docs/cache-handling-phase38-implementation/part-01-implementation-plan-review-20260711.md`
- `._design_docs/cache-handling-phase38-implementation/part-02-manager-implementation-plan-gate-20260711.md`
- `._design_docs/cache-handling-phase38-implementation/part-03-implementation-evidence-20260711.md`
- Diffs for `tools/server/server-cache-hybrid.h`,
  `tools/server/server-cache-hybrid.cpp`,
  `tools/server/server-context.cpp`, and
  `tests/test-cache-controller.cpp`

## Scope and gate status

The implementation touches the approved Stage 38 surfaces only: hybrid cache
restore planning, Prometheus cold-budget extraction, and focused controller
tests. It does not change legacy cache behavior or public response schema code.

Implementation review is REWORK. The cold-budget code change is narrow and
looks correct, but prefix restore is not yet safe for every Manager-approved
constraint, and the tests leave too much of the design unproved.

## Blocking findings

### F38-IMPL-01: Target-plus-draft/MTP prefix restore can accept arbitrary chat prefixes

The design gate requires checkpoint-dependent, SWA, recurrent, RS-limited,
target-plus-draft, and MTP paths to restore only from checkpoint-safe points.

Current code only applies the checkpoint-only prefix rule when
`profile == cache_workload_profile::checkpoint_dependent`:

- `tools/server/server-cache-hybrid.cpp:2116-2119`
- `tools/server/server-cache-hybrid.cpp:5365-5376`

The runtime target/draft state is computed in `tx_restore`:

- `tools/server/server-cache-hybrid.cpp:5312-5316`

but `validate_strict_prefix_candidate(...)` does not receive `pair_state` or
`runtime_has_draft`. `detect_workload_profile()` maps SWA, recurrent, and
hybrid models to `checkpoint_dependent`, but it does not classify draft/MTP
runtime by itself:

- `tools/server/server-cache-hybrid.cpp:4402-4415`

That leaves this path open: plain-transformer target-plus-draft runtime,
matching target-and-draft descriptor, `openai-chat` metadata, strict token
prefix, and matching `[0, prefix)` boundary. The validator accepts it as a plain
strict-prefix restore even though the Manager gate required target-plus-draft
and MTP restores to be checkpoint-safe.

Required correction: prefix validation must reject or checkpoint-gate any
runtime target-plus-draft/MTP prefix restore, not only
`checkpoint_dependent` model profiles. Add a focused test where target and
draft pair state matches but the prefix candidate is an exact blob rather than
a checkpoint-safe payload. It must recompute.

### F38-IMPL-02: Stage 38 test coverage proves only a narrow happy path

The implementation adds five Stage 38 controller tests:

- chat strict-prefix restore acceptance;
- `/completion` recompute;
- boundary checksum rejection;
- target/draft pair mismatch rejection;
- cold-budget JSON and typed extraction boundary math.

Those tests are useful, but they do not cover the approved TP-38 set well
enough for implementation sign-off. Missing or weak rows:

- TP-38-PR-01 exact repeat still wins over prefix logic.
- TP-38-PR-04 namespace, template, or tool drift rejects before apply.
- TP-38-PR-06 checkpoint-dependent/MTP arbitrary prefix rejects unless
  checkpoint-safe.
- TP-38-PR-07 cold prefix payload promotes inline or falls back safely.
- TP-38-PR-08 protected prefix metadata survives pressure while budgets hold.
- TP-38-PR-09 generated output is not replayed.
- Public response evidence for full `usage.prompt_tokens`,
  `usage.prompt_tokens_details.cached_tokens`, and `timings.cache_n`.
- Public Prometheus evidence that `llamacpp:cache_cold_budget_bytes` prints
  `2147483648`.

The current pair-state test only checks mismatch rejection. It does not prove
the more dangerous target-plus-draft match case from F38-IMPL-01. The cold
budget test checks stats and `json_value(...)`, but not the actual Prometheus
writer line in `server-context.cpp`.

Required correction: add focused tests for the missing gate-critical cases, or
record a Manager-approved narrowing before implementation review is asked to
pass. At minimum, cover exact-vs-prefix ordering, namespace/tool drift,
checkpoint/MTP or target-plus-draft arbitrary-prefix rejection, cold-payload
prefix behavior, and public metric/output evidence before QA handoff.

## Non-blocking observations

- `/completion` prefix restore remains rejected in the new test and in code via
  `diagnostic_source != "openai-chat"` returning
  `unsafe_prefix_rejected`.
- Public prompt-token totals are not changed in `server-task.cpp`; restored
  prefix reporting still flows through `slot.n_prompt_tokens_cache`,
  `timings.cache_n`, and `prompt_tokens_details.cached_tokens`.
- Pair-state, descriptor checksum, payload ownership, residency, and target or
  draft byte validation still run through `validate_payload_for_restore(...)`
  before apply.
- The cold-budget gauge fix is isolated to using an `int64_t(-1)` default in
  the Prometheus extraction path. The controller already stores
  `cold_budget_bytes` as `int64_t`.
- The implementation evidence correctly says live model-backed chat evidence
  was not run. That gap must stay visible for the next gate.

## Test summary string decision

The footer still prints `Total: 152 tests` after adding five Stage 38 tests.
A direct count of `test_*();` calls in `main()` found 163 calls, so the footer
was already historically inaccurate before Stage 38 and remains inaccurate now.

This is not a product behavior blocker and it did not hide a failing test in
the focused run. It is still a documentation/test-harness cleanup item: either
fix the count or replace the hard-coded total with wording that does not claim
an exact number.

## Evidence run during review

```powershell
git diff --check -- tools/server/server-cache-hybrid.h tools/server/server-cache-hybrid.cpp tools/server/server-context.cpp tests/test-cache-controller.cpp
```

Result: PASS, no output.

```powershell
.\build-cuda\bin\Release\test-cache-controller.exe
```

Result: PASS. The binary prints all listed tests passed and the stale
`Total: 152 tests` footer.

```powershell
ctest --test-dir build-cuda -C Release -R cache --output-on-failure
```

Result: PASS. `test-cache-controller` passed in 0.27 seconds.

## Handoff

Handoff state: correction loop required.

Next owner: Developer.

Do not hand Stage 38 to QA yet. Close F38-IMPL-01 and F38-IMPL-02, then request
Architect implementation re-review.
