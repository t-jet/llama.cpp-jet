# Stage 7 test-plan review - 2026-05-31

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

Reviewer: QA agent
Verdict: PASS

## Scope reviewed

This was an independent review of the Stage 7 branch graph foundation test plan and automation guidance. QA execution is not open.

Documents reviewed:

- [document-index.md](../document-index.md)
- [cache-handling-test-plan.md](../cache-handling-test-plan.md)
- [Part 9: Stage 7 branch graph foundation](part-09-stage7-branch-graph-foundation.md)
- [cache-handling-test-scripts README](../cache-handling-test-scripts/README.md)
- [Stage 7 design Parts 4-6](../cache-handling-phase7-design.md)
- [Stage 7 implementation entry and Parts 5, 7, 9, 10](../cache-handling-phase7-implementation.md)

Code and automation references checked:

- `tests/test-step12-branch-graph.cpp`
- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`
- `._design_docs/cache-handling-test-scripts/execute_tests.ps1`

## Verdict

PASS. The Stage 7 plan is ready for manager review before QA execution opens.

The plan covers the implemented Stage 7 behavior: branch node lifecycle, strict namespace validation, slot refs, checksum-assisted lookup, branch metadata RAM accounting, metadata soft-limit diagnostics, global hot-payload LRU selection across namespaces, metrics, and Stage 1-6 regression. It also keeps Stage 8+ work out of acceptance, including metadata-only nodes, equivalent-branch deduplication, checkpoint-first restore, branch pruning, public metadata-budget flags, and public `/cache/stats` success.

## Findings

No blocking findings.

Non-blocking cleanup completed during this review:

- The shared plan overview and Part 2 still described focused C++ tests as outside plan acceptance. That conflicted with Stage 7, where focused graph and controller evidence is required for internal branch graph preconditions that public HTTP cannot create. The wording now says focused C++ and Python metric-shape evidence may be used when the evidence source is labeled correctly.
- The review report list in the test-plan entry was missing the Stage 6 review and the new Stage 7 review. Both links are now present.
- The document index did not know about this Stage 7 review report. It now has a Stage 7 review entry.

## Checklist result

| Check | Result |
| --- | --- |
| Scope is current for implemented Stage 7 behavior | PASS |
| Stage 8+ deferrals are excluded from acceptance | PASS |
| Positive, negative, observability, clean-build, evidence-format, and blocked-precondition rules are clear | PASS |
| Evidence sources are classified as public HTTP, focused graph/controller, Python metric shape, or missing harness | PASS |
| Stage 4, Stage 5, and Stage 6 regression coverage remains in scope | PASS |
| Plan is generic and does not depend on a future test report | PASS |
| Script README guidance is aligned and does not overclaim automation coverage | PASS |
| Markdown files are ASCII and under 300 lines | PASS |

## Evidence classification review

The plan correctly separates evidence sources:

- Public HTTP evidence can cover model-backed save/load regression, `/health`, `/metrics`, missing `/cache/stats`, and Stage 1-6 public regression behavior.
- `test-step12-branch-graph` covers branch graph internals such as node defaults, namespace hashing, lifecycle, traversal, lookup, slot refs, concurrent ref acquire/release, and eviction candidate ordering.
- `test-cache-controller` covers controller stats, metadata soft-limit diagnostics, slot refs blocking production eviction, global cross-namespace eviction ordering, and checksum-assisted candidate selection.
- `tools/server/tests/unit/test_cache_modes.py` covers public metric shape and missing `/cache/stats`; it does not prove every branch policy precondition.
- Rows that require unavailable stats, draft, or fault-injection support must be `BLOCKED`, not converted to `PASS` from public request completion.

## Automation guidance review

The script README is aligned with Part 9. It states that the main PowerShell runner has no dedicated Stage 7 matrix and must not be used to pass graph-internal rows. It points execution to the focused graph target, focused controller target, and Python metric-shape test for Stage 7 evidence.

Clean-build guidance is also acceptable. Stage 7 sessions require a fresh build of `llama-server`, `test-cache-controller`, and `test-step12-branch-graph`, followed by focused checks and Python metric-shape checks as applicable.

## Handoff

Status: READY for manager review of the Stage 7 QA plan gate.

QA execution remains closed until the manager opens it.
