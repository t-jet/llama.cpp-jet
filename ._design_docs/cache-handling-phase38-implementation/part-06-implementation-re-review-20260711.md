VERDICT: PASS

# Stage 38 implementation re-review

Date: 2026-07-11
Reviewer: Architect
Scope: fresh independent implementation re-review of rework evidence after part-04 REWORK verdict

## Inputs reviewed

- `AGENTS.md`
- `.agents/skills/architect/SKILL.md`
- `.agents/skills/self-improvement/SKILL.md` and `assets/architect.md`
- `.agents/skills/humanizer/SKILL.md`
- `.agents/skills/caveman/SKILL.md`
- `._design_docs/cache-handling-phase38-implementation/part-04-implementation-review-20260711.md`
- `._design_docs/cache-handling-phase38-implementation/part-05-implementation-rework-evidence-20260711.md`
- Live worktree diff: `git -C d:\source\llama.cpp-jet diff -w -- tools/server/ tests/test-cache-controller.cpp`
- Live source:
  - `tools/server/server-cache-hybrid.h`
  - `tools/server/server-cache-hybrid.cpp`
  - `tools/server/server-context.cpp`
  - `tools/server/server-task.cpp`
  - `tests/test-cache-controller.cpp`

## Scope and gate status

Fresh re-review of the rework evidence only. This review does not redo the
design review, plan review, or QA work, and it edits no code, tests, part-04,
or part-05. It verifies that F38-IMPL-01, F38-IMPL-02, and the non-blocking
test-footer cleanup are now closed in the live tree, and that the binding gate
constraints still hold.

Both blocking findings are closed. Constraints held. Evidence clean. The stage
is cleared for a Manager gate decision on the QA handoff.

## F38-IMPL-01: target-plus-draft/MTP prefix restore checkpoint gate — CLOSED

### Fix mechanism verified in live code

The validator now takes the runtime pair state and the selected payload kind
and checkpoint-gates any target-plus-draft or checkpoint-dependent prefix:

- `tools/server/server-cache-hybrid.h:1038-1045` declares
  `validate_strict_prefix_candidate` with a `payload_pair_state pair_state`
  parameter and a `payload_kind selected_payload_kind` parameter.
- `tools/server/server-cache-hybrid.cpp:2093-2155` implements the validator.
  The checkpoint-or-recompute gate at lines 2147-2151 reads:

  ```cpp
  const bool checkpoint_safe = selected_payload_kind == payload_kind::checkpoint;
  if ((profile == cache_workload_profile::checkpoint_dependent ||
       pair_state == payload_pair_state::target_and_draft) &&
      !checkpoint_safe) {
      return cache_restore_miss_reason::unsafe_prefix_rejected;
  }
  ```

- The production restore call site at
  `tools/server/server-cache-hybrid.cpp:5393-5402` computes
  `selected_payload_kind` via `select_restore_payload_kind(*it_best, profile)`
  at line 5393 before calling the validator at lines 5396-5397, passing the
  production `pair_state`. `select_restore_payload_kind` at lines 1891-1914
  resolves the payload kind from the live payload descriptors, so the gate
  keys off production-selected data, not a debug default.
- `pair_state` is threaded from runtime context at
  `tools/server/server-cache-hybrid.cpp:5340-5341`:

  ```cpp
  const bool runtime_has_draft = ctx_dft != nullptr;
  const payload_pair_state pair_state = runtime_has_draft ?
      payload_pair_state::target_and_draft :
      payload_pair_state::target_only;
  ```

- `ctx_dft` is the controller's member draft context
  (`tools/server/server-cache-hybrid.h:762`). `tools/server/server-context.cpp`
  at lines 620-638 shows that target-model MTP also allocates a draft context
  under the `has_draft || spec_mtp` branch, so `ctx_dft != nullptr` covers
  separate-draft speculative decoding, target-model MTP, and separate-model
  MTP. The single `pair_state` check closes F38-IMPL-01 for all three paths.
- Before the fix, the production path rejected any partial-prefix restore with
  a hard-coded `unsafe_prefix_rejected` and never invoked a validator. The
  rework diff replaces that with a real validation call that accepts only
  checkpoint-safe prefixes for the gated runtimes.
- The test-only entry point `debug_validate_strict_prefix_for_tests` at
  `tools/server/server-cache-hybrid.cpp:1476-1501` forces the pair state so
  the gate can be exercised without a live draft context. It calls the same
  production validator, so it is a thin hook over the production branch, not
  a parallel reimplementation.

### Test evidence

`test_stage38_target_draft_prefix_requires_checkpoint_safe` at
`tests/test-cache-controller.cpp:3572-3621` exercises four gate cases through
`debug_validate_strict_prefix_for_tests`:

1. plain-transformer profile, target-plus-draft pair state, exact-blob payload
   → asserts `unsafe_prefix_rejected` (must recompute).
2. plain-transformer profile, target-plus-draft pair state, checkpoint payload
   → asserts `exact_entry_absent` (accepted).
3. checkpoint-dependent profile, target-only pair state, exact-blob payload
   → asserts `unsafe_prefix_rejected` (must recompute).
4. plain-transformer profile, target-only pair state, exact-blob payload
   → asserts `exact_entry_absent` (accepted, no regression).

All four cases are independent and cover the previously open
target-plus-draft match path.

F38-IMPL-01 is CLOSED.

## F38-IMPL-02: focused controller tests for the missing gate-critical rows — CLOSED

Seven focused tests added to `tests/test-cache-controller.cpp`. All use
`require_or_abort` (explicit `if (!cond) { fprintf(stderr,...); std::abort(); }`),
so they hold in Release builds where `NDEBUG` may be defined. Each test was
read in full and its assertions match the declared coverage gap:

| TP-38 row | Test function | Evidence | Gap closed |
| --- | --- | --- | --- |
| TP-38-PR-01 | `test_stage38_exact_repeat_wins_over_prefix` (`:3502-3537`) | Exact repeat match restores full token count, finalizes as `n_hits==1`, and asserts the `accepted_strict_prefix` counter is absent from the prefix-candidate stats shape. | Exact path wins over prefix logic; no stray prefix counter. |
| TP-38-PR-04 | `test_stage38_namespace_template_tool_drift_rejects` (`:3539-3570`) | Divergent compatibility key splits the namespace; restore plan asserts `!plan.found` and `n_hits==0`. | Template/tool drift rejects before apply. |
| TP-38-PR-06 | `test_stage38_target_draft_prefix_requires_checkpoint_safe` (`:3572-3621`) | Four-case gate check (see F38-IMPL-01). | Target-plus-draft and checkpoint-dependent arbitrary-prefix rejection unless checkpoint-safe. |
| TP-38-PR-07 | `test_stage38_cold_prefix_payload_promotes_or_falls_back` (`:3623-3661`) | Cold exact payload, cold store wired; restore plan resolves through a bounded path and `n_restore_failures < 2`. | Cold prefix payload promotes inline or falls back safely. |
| TP-38-PR-08 | `test_stage38_protected_prefix_metadata_survives_pressure` (`:3663-3702`) | Protected entry survives 16 churn payloads under a 16-entry budget and matches the strict-prefix request. | Protected prefix metadata survives pressure. |
| TP-38-PR-09 | `test_stage38_generated_output_never_replayed` (`:3704-3730`) | A generated-output-only entry is added; a fresh prompt request asserts `!plan.found`. | Generated output never replayed as a prefix restore. |
| TP-38-MET-01 | `test_stage38_cold_budget_prometheus_gauge_output` (`:3732-3756`) | Cold budget source is `2147483648` for 2048 MiB, exceeds `INT_MAX`, and the streamed int64 line shape contains `2147483648`. Exercises the exact value-feeding expression used by `server-context.cpp` (`json_value(stats, "cache_cold_budget_bytes", int64_t(-1))`). | No `int` narrowing regression on the gauge. |

All seven functions are wired into `main()` at
`tests/test-cache-controller.cpp:7182-7188`.

F38-IMPL-02 is CLOSED.

## Non-blocking cleanup: test footer — CLOSED

`tests/test-cache-controller.cpp:7246-7248` now prints:

```text
Note: the per-stage breakdown above undercounts; this footer no longer claims an exact total.
```

The hard-coded `Total: 152 tests` string is gone. No product behavior is
affected and the success message and separator lines are unchanged. Test run
confirmed the new wording is printed and `152` no longer appears in the
footer.

Non-blocking test-footer cleanup is CLOSED.

## New findings

No new blocking findings.

Non-blocking observations retained from part-04 and part-05 that do not block
implementation sign-off:

- Live model-backed `/v1/chat/completions` evidence was not run in the
  implementation or rework session. Public response evidence for
  `usage.prompt_tokens_details.cached_tokens`, full `usage.prompt_tokens`,
  `timings.cache_n`, positive hybrid hit delta, prefix metric rows, and public
  Prometheus output for `2147483648` against a running server remain a QA
  responsibility. The rework evidence correctly leaves this gap open.
- The Prometheus gauge test exercises the exact value-feeding expression used
  by `server-context.cpp`, not the streaming Prometheus lambda directly
  (which is a server-internal callable not reachable from the controller test
  binary). This is an acceptable narrowing because the int64 source and the
  int64 streamed output are the narrowing risk the test targets.

## Constraints-held check

| Binding constraint | Status | Evidence |
| --- | --- | --- |
| `/completion` prefix restore out of scope, must recompute | HELD | `tools/server/server-cache-hybrid.cpp:2105-2107` rejects any prefix candidate whose `task.prompt_metadata.diagnostic_source != "openai-chat"` with `unsafe_prefix_rejected`. `/completion` requests do not set `openai-chat` and recompute. Existing `test_stage38_completion_strict_prefix_recomputes` still covers this. |
| Public prompt-token totals stay full request length | HELD | `tools/server/server-task.cpp` has zero content diff (`git diff -w` reports 0 lines). `usage.prompt_tokens` and timings `cache_n`/`cache_read_input_tokens` continue to use `n_prompt_tokens` minus `n_prompt_tokens_cache`; only cache-specific fields report the restored prefix length. |
| Only cache-specific fields report restored prefix length | HELD | Restored prefix flows only through `slot.n_prompt_tokens_cache`, `timings.cache_n`, and `usage.prompt_tokens_details.cached_tokens`. No production schema field was changed. |
| Checkpoint-dependent, SWA, recurrent, RS-limited, target-plus-draft, and MTP restore checkpoint-safe only | HELD | `detect_workload_profile` maps SWA, recurrent, and hybrid models to `checkpoint_dependent`; the validator gate at `server-cache-hybrid.cpp:2147-2151` covers both `checkpoint_dependent` profiles and runtime `pair_state == target_and_draft` (which covers target-model MTP, separate-model MTP, and separate-draft speculative decoding). Non-checkpoint exact-blob prefixes for those runtimes recompute. |
| Correctness wins over hit rate | HELD | The validator mutex deletes any ambiguity: a candidate that fails any boundary, checksum, profile, pair-state, or payload-kind check returns a miss reason and recomputes. No validation gap silently accepts a prefix. |

## Evidence run during re-review

### Whitespace check (content-only via `-w`)

```powershell
git -C d:\source\llama.cpp-jet diff -w --check -- tools/ tests/
```

Result by file (trailing-whitespace line counts via `-w --check`):

- `tools/server/server-cache-hybrid.cpp`: 1000 lines flagged.
- `tools/server/server-cache-hybrid.h`: 0.
- `tools/server/server-context.cpp`: 0.
- `tests/test-cache-controller.cpp`: 0.

Raw byte verification of `server-cache-hybrid.cpp`: CR count == 5704, LF count
== 5704, no BOM. Whole-file CRLF is pre-existing from the prior implementation
session (documented in part-05) and not introduced by the rework. Per the
architect improvement memory on CRLF noise in `git diff --check` on Windows cpp
inserts, this is CRLF diff noise, not a code defect, lint failure, or repeated
finding. The rework constraint forbids legacy/production line-touching edits,
so normalization was intentionally not performed. Tests are LF-only, no BOM.

### Whitespace-ignoring content stat

```powershell
git -C d:\source\llama.cpp-jet diff -w --stat -- tools/server/ tests/test-cache-controller.cpp
```

Result:

```text
 tests/test-cache-controller.cpp      | 433 ++++++++++++++++++++++++++++++++++-
 tools/server/server-cache-hybrid.cpp |  90 +++++++-
 tools/server/server-cache-hybrid.h   |  20 ++
 tools/server/server-context.cpp      |   2 +-
 4 files changed, 541 insertions(+), 4 deletions(-)
```

Confirms the ~90 content lines in `server-cache-hybrid.cpp` cited in the
brief, not the ~914 from the non-`-w` stat. The rest is CRLF conversion noise.

### Focused test binary

```powershell
.\build-cuda\bin\Release\test-cache-controller.exe
```

Result: PASS. Exit code 0. 12 Stage 38 test lines printed (5 original + 7
rework), no FAIL lines, footer prints the new non-exact-total wording.

### ctest

```powershell
ctest --test-dir build-cuda -C Release -R cache --output-on-failure
```

Result: PASS. `test-cache-controller` passed in 0.29 seconds. 1/1 tests
passed, 0 failed.

## Files reviewed

- `._design_docs/cache-handling-phase38-implementation/part-04-implementation-review-20260711.md`
- `._design_docs/cache-handling-phase38-implementation/part-05-implementation-rework-evidence-20260711.md`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tools/server/server-task.cpp`
- `tests/test-cache-controller.cpp`

## Verdict

PASS.

- F38-IMPL-01: CLOSED (checkpoint-or-recompute gate verified in production
  code; pair state threaded from live `ctx_dft`; four-case test exercises the
  previously open path).
- F38-IMPL-02: CLOSED (seven focused tests verified in source and at runtime;
  each closes a named coverage gap).
- Test-footer cleanup: CLOSED (hard-coded exact total removed; new wording
  printed).
- Binding gate constraints: all five HELD.
- Evidence: focused binary PASS, ctest PASS, content-only whitespace noise
  limited to pre-existing whole-file CRLF.

No new blocking findings.

Next owner: Manager, for the Stage 38 QA handoff gate decision.
