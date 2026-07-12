VERDICT: PASS

# Stage 38 implementation-plan review

Date: 2026-07-11
Reviewer: Architect
Scope: independent implementation-plan review only

## Inputs reviewed

- `AGENTS.md`
- `.agents/skills/architect/SKILL.md`
- `.agents/skills/humanizer/SKILL.md`
- `.agents/skills/caveman/SKILL.md`
- `._design_docs/document-index.md`
- `._design_docs/cache-handling-stage-tracker.md`
- `._design_docs/cache-handling-phase38-design.md`
- `._design_docs/cache-handling-phase38-design/part-01-prefix-checkpoint-partial-restore.md`
- `._design_docs/cache-handling-phase38-design/part-02-cold-budget-gauge-fix.md`
- `._design_docs/cache-handling-phase38-design/part-03-observability-and-tests.md`
- `._design_docs/cache-handling-phase38-design/part-04-design-review-20260711.md`
- `._design_docs/cache-handling-phase38-design/part-05-design-correction-20260711.md`
- `._design_docs/cache-handling-phase38-design/part-06-design-re-review-20260711.md`
- `._design_docs/cache-handling-phase38-design/part-07-manager-design-gate-20260711.md`
- `._design_docs/cache-handling-phase38-implementation.md`
- Source anchors in `tools/server/server-cache-hybrid.{h,cpp}`,
  `tools/server/server-context.cpp`, `tools/server/server-slot.h`,
  `tools/server/server-task.cpp`, and `tests/test-cache-controller.cpp`

## Scope and gate status

The plan is in scope for Stage 38 and covers the two Manager-approved fixes:

- safe strict-prefix/checkpoint partial restore for `/v1/chat/completions` and
  shared hybrid cache-controller paths used by that route;
- the D36-FU-01 cold-budget gauge fix for `--cache-cold-max-mib 2048`.

Implementation-plan review PASS. This review does not approve production code,
tests, scripts, builds, commits, pushes, staging, reverts, or QA execution.

## Decisions

- The plan preserves the Manager design gate constraints. `/completion` prefix
  restore remains excluded, public prompt-token totals remain full request
  length, cache-specific restored-prefix fields report the prefix length, and
  checkpoint-profile paths stay limited to checkpoint-safe restore points.
- The ordered steps are implementable from current source anchors. Existing
  `cache_response.restored_token_count`, `tx_restore`, `tx_apply_restore`,
  `find_prefix_candidate`, `select_restore_candidate`, `try_restore_from_cache`,
  the prompt loop, and metric writers give Developer clear integration points.
- The cold-budget path is correctly scoped to constructor/storage, JSON stats,
  `json_value(...)`, and Prometheus output. The plan keeps `-1` unlimited, `0`
  disabled, and avoids unrelated cold demotion or eviction behavior changes.
- The suffix-processing step matches the approved design: restore prefix state,
  let the normal prompt loop process only the suffix, and never replay generated
  output, logits, or sampled tokens.
- Observability keeps bounded labels and counts accepted prefix restores as hits
  only after live slot apply succeeds.
- Rollback controls are explicit: exact restore stays first, validation gaps
  recompute, legacy cache is untouched, and metric changes are isolated.

## Required corrections

None.

## Evidence and test coverage checks

The plan covers all TP-38 rows:

- TP-38-PR-01 through TP-38-PR-10 for exact repeat, strict-prefix accept,
  checksum mismatch, namespace/template/tool drift, pair-state mismatch,
  checkpoint/MTP safety, cold payload, protected branch pressure, no generated
  output replay, and `/completion` recompute.
- TP-38-MET-01 and TP-38-MET-02 for the 2048 MiB gauge and boundary values
  `0`, `1`, `2047`, `2048`, `4096`, and `-1`.

The plan also requires model-backed `/v1/chat/completions` evidence for:

- nonzero `usage.prompt_tokens_details.cached_tokens`;
- full public `usage.prompt_tokens`;
- `timings.cache_n` matching restored prefix length;
- positive `llamacpp:cache_hits_total{mode="hybrid"}` delta;
- prefix rows in `/metrics`;
- internal JSON stats and Prometheus output agreeing at `2147483648`.

The clean build rule is present before QA handoff unless Manager narrows the
evidence. The no-code, no-test, no-script, no-build, no-commit, no-push,
no-stage, and no-revert restrictions are also recorded.

## Documentation hygiene

This report is under 300 lines and ASCII-only. The Stage 38 implementation log,
document index, and tracker were updated only to point at this PASS handoff.

## Handoff

Handoff state: ready for Manager implementation-plan gate.

Next owner: Manager.
