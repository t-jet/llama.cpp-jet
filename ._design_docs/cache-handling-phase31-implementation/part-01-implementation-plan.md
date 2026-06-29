# Stage 31 implementation plan

Status: ready for Architect implementation-plan review
Date: 2026-06-29
Owner: Developer

## Approved baseline

- Design baseline: `._design_docs/cache-handling-phase31-design.md`
- Design review: PASS, 2026-06-29, no open findings.
- Intake: `._design_docs/.manager-inputs/manager-input-20260629-stage31-hybrid-cache-misbehavior.md`
- Architecture anchors: namespace is runtime compatibility; prompt spans,
  checksums, and boundary labels are validation data.

Stage 31 is investigation-first. No production behavior changes until probes
P31-01 through P31-05 record root-cause evidence.

## Affected files and ownership

- `tools/server/server-cache-hybrid.cpp`: Developer owns namespace
  computation, save/lookup parity diagnostics, branch lookup counters, and
  stats JSON.
- `tools/server/server-cache-hybrid.h`: Developer owns any test-only namespace
  helper or debug accessor guarded by `LLAMA_SERVER_CACHE_TESTS`.
- `tools/server/server-cache-graph.cpp` and `.h`: Developer owns only changes
  needed to keep namespace lookup safe; no graph topology redesign is planned.
- `tools/server/server-context.cpp`: Developer owns Prometheus HELP/TYPE
  emission and bounded cache metric labels.
- `tests/test-cache-controller.cpp`: Developer owns focused controller
  regressions and metric-shape tests if no better existing test surface exists.
- `._design_docs/.test_reports/test-report-20260629-12-stage30-01.md` or this
  implementation log: Developer owns Stage 30 wording correction or linked
  follow-up note.
- `._design_docs/cache-handling-phase31-implementation.md` and this part:
  Developer owns step status, evidence, and review handoff.

## Ordered steps

1. P31-01 zero-hit reproducer.
   - Run one hybrid server with cold path enabled.
   - Send prompt A twice, then prompt B with a long shared prefix.
   - Record hits, misses, `cache_n`, restore miss reason, namespace count, and
     branch lookup stats.
   - If second A misses, classify whether save did not happen, lookup searched
     the wrong namespace, or payload residency blocked restore.

2. P31-02 namespace explosion probe.
   - Send 20 requests under one model/config: 5 exact anchors and 15
     near-prefix variants.
   - Record `cache_namespace_count`, branch forest namespace stats, and branch
     lookup labels.
   - Expected fixed shape is a small bounded count, normally 1 for this fixture.

3. P31-03 workload token equality probe.
   - Render/tokenize the Stage 29/30 `workload.jsonl` through the same server
     path used by chat completions.
   - Record token hash, token count, and first differing token by `cache_class`.
   - Exact rows must repeat token hashes after first occurrence. Near-prefix
     rows must share enough prefix tokens to exercise branch lookup.

4. P31-04 save-vs-lookup namespace parity probe.
   - Add temporary or test-only diagnostics around `tx_restore()` and
     `tx_save()`: request id, token hash, namespace id, preparation id,
     boundary count, first prompt-span checksum, and workload profile.
   - Exact repeats must show identical lookup and save namespaces.
   - Save-only or lookup-only namespace values block production fixes until
     explained.

5. P31-05 metrics cardinality and HELP/TYPE probe.
   - Parse `/metrics` from a focused run.
   - Assert one HELP and one TYPE line per metric name.
   - Assert branch lookup and namespace stats use bounded public labels.
   - Raw namespace ids may remain in debug JSON or opt-in diagnostics only.

6. Root-cause note.
   - Append evidence summary to this implementation log before production code
     changes.
   - If probes disprove the namespace hypothesis, stop and request design
     update instead of broadening scope.

7. Minimal production fix.
   - Change `hybrid_cache_controller::compute_namespace_id(metadata)` so
     namespace uses stable compatibility inputs only.
   - Keep prompt spans, checksums, boundary metadata, protected flags,
     `degraded_reason`, and diagnostic text out of namespace hashing.
   - Preserve all restore validation checks before any slot mutation.

8. Metric writer fix.
   - Refactor cache metric writing in `server-context.cpp` so each metric name
     emits one HELP line and one TYPE line.
   - Replace raw namespace-id public labels with bounded labels such as
     aggregate mode/method buckets or stable small categories.
   - Keep raw namespace detail in `get_stats()` JSON or opt-in debug output.

9. Stage 30 wording correction.
   - Correct or qualify the Stage 30 "cold start, no hits yet" wording.
   - Required wording: exact-repeat rows can produce in-cycle hits in one cold
     server process; Stage 31 investigates why they did not.

10. Regression tests and evidence.
    - Add focused tests listed below.
    - Run build and test commands, then update this implementation log with real
      evidence and remaining risk.

## `preparation_id` decision process

Use this decision before editing namespace computation:

1. Trace all current assignments. Known anchors:
   `rendered-text-boundary-inference` and `token-position-fallback`.
2. Classify each value:
   - Stable ABI: describes a durable preparation algorithm or template ABI that
     changes restore compatibility.
   - Request-local: describes how one request was mapped, degraded, inferred, or
     diagnosed.
3. Keep `preparation_id` in namespace only if every production value is stable
   ABI and not prompt-local.
4. If any production value is request-local, remove `preparation_id` from
   namespace and keep it as validation or diagnostic data.
5. Add tests proving boundary checksum changes do not change namespace, while
   model/config/template ABI changes still do.

Current planning assumption: existing values look request-local or diagnostic.
The probe and trace must confirm before production change.

## Proposed production changes

- Namespace: compute from `build_compatibility_key()` plus stable
  `metadata.compatibility_key` only if it is a runtime compatibility key.
  Exclude boundary spans, checksums, boundary metadata, `degraded_reason`, and
  request-local `preparation_id`.
- Save/lookup parity: keep same namespace function for `tx_restore()` and
  `tx_save()`; add only test-only accessors if needed.
- Metrics: make HELP/TYPE emission metric-name scoped, not sample scoped.
  Bound label values for branch lookup and namespace stats. Preserve raw IDs in
  JSON diagnostics.
- Stage 30 wording: document the exact-repeat caveat in a durable report note.
- Tests: use focused unit tests first; live probes stay small and optional after
  unit evidence.

## Test and evidence plan

- Unit: namespace ignores validation-only boundary changes.
- Unit: namespace changes for model/config/profile/template ABI changes.
- Unit: exact-repeat save then lookup reaches same namespace and records a hit.
- Unit: near-prefix lookup searches same namespace and validates/rejects safely.
- Unit: checkpoint-dependent profile keeps checkpoint validation after namespace
  broadening.
- Metric shape: parse generated `/metrics` text or extracted writer output and
  assert one HELP and TYPE per metric plus bounded labels.
- Workload evidence: token-hash probe for Stage 29/30 exact and near-prefix
  rows.
- Optional live probe: 3-request A/A/B hybrid run with metrics scrape.

Build commands:

```powershell
cmake --build build --target test-cache-controller -j 4
.\build\bin\Release\test-cache-controller.exe
ctest --test-dir build -R cache -V
```

Use the active local build directory if `build` is not present, but record the
actual path and command output.

## Risks and rollback

- Broader namespace can expose unsafe candidates. Roll back the namespace
  change if token/checksum/descriptor validation is not proven by tests.
- Metric label reduction can hide forensic detail. Keep raw namespace ids in
  stats JSON or debug output.
- Workload labels may be wrong after chat templating. Treat token-hash probe as
  authoritative over source JSON labels.
- Existing cache-controller tests may have Release `assert()` gaps. New
  regression gates must use explicit abort/fail checks, not assert-only gates.

Rollback is a small revert of namespace computation and metric writer changes.
No storage format migration is planned.

## Non-goals

- No full Stage 30 rerun before root cause is documented.
- No graph topology redesign.
- No prompt similarity cache or response cache.
- No public request schema changes.
- No commit or push from this planning session.

## Handoff

Next owner: Architect.

Requested review: implementation-plan review. Confirm probe ordering,
`preparation_id` decision process, minimal production scope, metric contract,
test plan, and Stage 30 wording correction target before Developer starts
implementation.
