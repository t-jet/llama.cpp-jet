# Part 13: independent live pressure correction re-review

Date: 2026-07-13
Verdict: REWORK
Scope: design Part 11, implementation Parts 39-40, and test-plan Part 43

## Review basis

Reviewed against D39-EXEC-01, design review Part 12 findings F39-LPCR-01
through F39-LPCR-04, current production residency and cold-victim selection,
and the canonical coverage runner.

F39-LPCR-01 and F39-LPCR-03 are closed. The correction now holds one admission
latch from idle validation through cleanup, consumes the attempt before the
first mutation, keeps later failures terminal, and makes the corrected TP-39-04
admit-measure-lower order authoritative.

F39-LPCR-02 and F39-LPCR-04 remain open for the reasons below.

## Blocking findings

| ID | Finding | Required correction |
| --- | --- | --- |
| F39-LPCR-RR-01 | Part 11 lines 66-70 permits only hot descriptors and requires their IDs to equal the full hot-eligible set, with no extras. TP-39-02 line 126 uses the same request to assign equal `cold_rank` to prospective cold victims. Production selects cold victims only from descriptors whose residency is `cold` (`server-cache-hybrid.cpp` line 4980), and residency is a single state (`server-cache-hybrid.h` lines 83-88). A cold victim therefore cannot be one of the required hot IDs, while adding it violates the no-extra rule. TP-39-02 cannot establish its equal-rank precondition. | Split request controls into a complete hot-candidate set and an explicit complete eligible cold-victim set, or define another setup-only schema that can rank cold descriptors. Give each set its own eligibility, ownership, uniqueness, no-omission, and no-extra validation. Preserve exclusive residency and production ordering. Update Parts 11, 39, 40, and 43 plus controller, route, and `Assert-Tp3902` mappings. |
| F39-LPCR-RR-02 | Part 39 still gives no executable OFF/ON build commands, named route-test cases with fixed exits/artifacts, or exact Windows PowerShell 5 and PowerShell 7 commands. Its coverage success and failure checks name `coverage.xml` (lines 61 and 67), but the runner writes `coverage-merged.xml` (`run_coverage.ps1` line 284). The forced-exit check can therefore pass without testing absence of the real XML artifact. Fixture behavior is prose rather than executable fixture text or a named generator. | Record exact OFF and ON configure/build/test commands, named pytest selectors or assertion map, exact PowerShell 5/7 commands, fresh output directories, expected exits, and preserved artifacts. Provide literal fixture text or a named generator for exit 23. Check `coverage-merged.xml` and `coverage-report.md`, and give the exact canonical success and forced-failure invocations. Update Parts 39, 40, and 43. |

## Closed checks

- Admission latch serialization and lock order close the idle-snapshot race.
- `ready` becomes irreversibly `consumed` before rank or budget mutation.
  Pre-pressure restoration and post-pressure production recovery ownership are
  explicit.
- Owner IDs, payload IDs, and hot ranks are unique; owner LRU reindexing is once
  per owner. This is sound for the hot set but does not solve RR-01.
- TP-39-03 and TP-39-04 flows and named controller/live assertion maps are
  exact. TP-39-02 remains unreachable because its cold rank setup is invalid.
- Compile/runtime isolation, loopback-only startup, strict token and schema
  checks, redaction, one-shot use, positive budgets, and no direct outcome
  injection preserve the prior security and production-path boundaries.
- Phase 3 remains limited to absolute no-argument `whoami.exe` and immediate
  nonzero merge failure. Denominator, phase order, server probe, and 80 percent
  threshold remain unchanged.

## Handoff

Next owner: Developer. Correct the two findings in documentation only. Code,
script, test implementation, and QA execution remain blocked pending fresh
independent Architect PASS.
