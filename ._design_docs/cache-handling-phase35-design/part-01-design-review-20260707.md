VERDICT: REWORK

# Stage 35 design review 2026-07-07

## Scope and gate status

Reviewed:

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-phase35-design.md`
- `._design_docs/.manager-inputs/manager-input-20260707-stage35-upstream-merge.md`
- `._design_docs/upstream-merge-guide.md`
- `._design_docs/upstream-merge-guide/part-01-procedure.md`
- `._design_docs/upstream-merge-guide/part-02-conflict-patterns.md`
- `._design_docs/upstream-merge-guide/part-03-coverage-and-evidence.md`
- `._design_docs/upstream-merge-guide/part-04-edge-cases.md`
- `._design_docs/cache-handling-phase34-design.md`
- `._design_docs/cache-handling-phase34-implementation/part-21-manager-closure-20260707.md`

Review type: independent design review for Stage 35. This review does not
execute a merge, approve conflict resolution, authorize code changes, or open
Developer pre-merge analysis.

Gate status: REWORK. Developer cannot proceed to pre-merge analysis after
Manager design gate until the blocking finding below is corrected and
re-reviewed.

## Findings

### F35-DESIGN-01 - BLOCKING - `src/llama.cpp` can be missed by the commit filter

Stage 35's file-glob table covers speculative/MTP source files with
`src/llama-*.cpp` and `src/llama-*.h` when a diff mentions draft, MTP, SWA, KV,
or checkpoint. The repo also has `src/llama.cpp`, and that path does not match
`src/llama-*.cpp`.

This matters because the upstream merge guide makes the stage-specific
file-glob list the deterministic input to commit-set selection. Developer must
not have to decide during pre-merge analysis whether a KV, checkpoint, MTP, or
slot-behavior change in `src/llama.cpp` is in scope. That would violate the
Manager intake acceptance target: the Stage 35 design must let Developer write
the pre-merge analysis without inventing file-glob filters.

Required correction:

- Add `src/llama.cpp` to the relevant Stage 35 filter group(s), at minimum
  speculative/MTP and checkpoint/KV state.
- If the intended rule is "all `src/llama*` runtime files when the diff names
  draft, MTP, SWA, KV, checkpoint, or slot state", state that directly.
- Re-run the design review after the filter is corrected.

## Checks that passed

| Area | Review result |
| --- | --- |
| Scope boundary | PASS. The design limits Stage 35 to upstream-merge operational planning and keeps merge execution, code changes, commits, pushes, PRs, and reviewer responses unauthorized. |
| Prerequisites | PASS. Stage 34 Manager closure PASS is cited, the working-tree clean requirement is stated for pre-merge analysis open, and Developer is blocked until independent design review and Manager design gate pass. |
| Source ref and staleness policy | PASS. `origin/upstream_master` is treated as a candidate/direct-ref path, Manager confirmation is required at design gate, `ls-remote` or REST comparison against upstream `master` is required before commit triage, stale-ref handling is a Manager decision, and regression repeats the staleness check. |
| Prior-stage contracts | PASS. The design carries Stage 25 transaction invariants, Stage 5/6/7/8/9/13/31/32/34 contracts, architecture part 9, I-34-01, and I-34-02. |
| Pre-merge report contract | PASS. Required metadata, ref verification, range counts, per-commit triage, aggregate counts, expected touched files, Manager decisions, and open questions are present. |
| Triage and conflict policy | PASS. NO-OP, INTEGRATE, REWORK-REQUIRED, DEFER, and REVERT are used with guide-compatible meanings. Local-first hybrid and upstream-first legacy/default routing is explicit. Blind `--ours`/`--theirs` and runtime no-op shortcuts are disallowed. |
| Rework routing | PASS. Contract-breaking upstream changes route to owning stage design rework parts, not only the Stage 35 merge log. QA regression is blocked while required rework remains open. |
| Regression and closure evidence | PASS. The design requires clean build, focused ctest, public HTTP probes, metrics shape, conditional coverage, cold-store proof, checkpoint/MTP rows when available, Stage 34 replay/synthetic rows when touched, and regression-time stale-ref checks. Coverage denominator wording follows the guide's combined/product-only/per-file citation rule. |
| Risk register | PASS. Risks cover stale ref, compiling semantic breakage, metric/label drift, legacy default drift, Stage 34 concurrency regression, and wrong coverage denominator. |
| Acceptance and handoff | PASS except for F35-DESIGN-01. The design keeps Developer handoff limited to pre-merge analysis after design review and Manager design gate. |

## Required corrections

1. Fix F35-DESIGN-01 in `._design_docs/cache-handling-phase35-design.md`.
2. Request Architect re-review before Manager design gate advances.

## Handoff state

State: re-review required.

Developer pre-merge analysis remains blocked. Merge execution, regression
reruns, commits, pushes, PRs, and reviewer responses remain unauthorized.
