VERDICT: PASS

# Stage 35 design re-review 2026-07-07

## Scope and gate status

Reviewed:

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-phase35-design.md`
- `._design_docs/cache-handling-phase35-design/part-01-design-review-20260707.md`
- `._design_docs/.manager-inputs/manager-input-20260707-stage35-upstream-merge.md`
- `._design_docs/upstream-merge-guide.md`
- `._design_docs/upstream-merge-guide/part-01-procedure.md`
- `._design_docs/upstream-merge-guide/part-02-conflict-patterns.md`
- `._design_docs/upstream-merge-guide/part-03-coverage-and-evidence.md`
- `._design_docs/upstream-merge-guide/part-04-edge-cases.md`
- `._design_docs/cache-handling-phase34-implementation/part-21-manager-closure-20260707.md`

Review type: independent re-review after correction for
F35-DESIGN-01. This re-review checks only the corrected Stage 35 design, the
prior blocking finding, and obvious contradictions introduced by the correction.
It does not approve merge execution, conflict resolution, code changes,
regression runs, commits, pushes, PRs, or reviewer responses.

Gate status: PASS for the Stage 35 design review. Manager design gate remains
the next required gate before Developer pre-merge analysis can open.

## Prior blocking finding

### F35-DESIGN-01 - RESOLVED - `src/llama.cpp` coverage in commit filters

Prior issue: the speculative/MTP filter used hyphenated patterns such as
`src/llama-*.cpp` and `src/llama-*.h`. That could miss `src/llama.cpp`, which
can carry KV, checkpoint, MTP, SWA, draft, or slot-state behavior.

Current design now fixes the gap in both relevant rows:

- Speculative and MTP row: covers all `src/llama*` runtime files, explicitly
  including `src/llama.cpp`, `src/llama-*.cpp`, and `src/llama-*.h`, when the
  diff mentions draft, MTP, SWA, KV, checkpoint, or slot state.
- Checkpoint and KV state row: covers `common/*checkpoint*`,
  `src/*checkpoint*`, `tools/server/*checkpoint*`, `src/*kv*`,
  `tools/server/*kv*`, plus all `src/llama*` runtime files, explicitly
  including `src/llama.cpp`, `src/llama-*.cpp`, and `src/llama-*.h`, when the
  diff mentions KV, checkpoint, MTP, draft, SWA, or slot state.

Repo path sanity check: `Get-ChildItem src -File -Filter 'llama*'` confirms
`src/llama.cpp` exists alongside many `src/llama-*.cpp` and `src/llama-*.h`
runtime files. The corrected wording covers the root peer file and the
hyphenated peers for the triage cases named in the finding.

Result: resolved. Developer no longer has to invent an extra filter for a
KV/checkpoint/MTP-relevant upstream change in `src/llama.cpp`.

## Contradiction check

No new obvious contradiction found.

| Area | Re-review result |
| --- | --- |
| File-glob determinism | PASS. The design gives deterministic inclusion rules for the corrected `src/llama*` runtime-file surface. |
| Intake alignment | PASS. The corrected rows satisfy the intake target that Developer must not invent file-glob filters. |
| Upstream guide alignment | PASS. The stage-specific filters remain compatible with the guide's deterministic commit-set selection rule. |
| Scope boundary | PASS. The correction does not authorize merge execution, code changes, regression runs, commits, pushes, PRs, or reviewer responses. |
| Handoff boundary | PASS. Developer handoff stays limited to pre-merge analysis after Manager design gate PASS. |

## Finding counts

| Severity | Count |
| --- | ---: |
| Blocking | 0 |
| Non-blocking | 0 |
| Info | 0 |

## Required corrections

None.

## Handoff state

State: ready for Manager design gate.

Developer pre-merge analysis may open only after Manager design gate PASS with
the final upstream reference policy recorded. Merge execution, regression
reruns, commits, pushes, PRs, and reviewer responses remain unauthorized.
