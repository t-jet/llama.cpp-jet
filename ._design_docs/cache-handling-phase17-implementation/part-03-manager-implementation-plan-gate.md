# Stage 17 manager implementation-plan gate

Source: [../cache-handling-phase17-implementation.md](../cache-handling-phase17-implementation.md)
Date: 2026-06-17
Reviewer: Manager agent
Verdict: PASS

## Plan review evidence

The independent implementation-plan review is recorded in
[part-02-implementation-plan-review-gate-01.md](part-02-implementation-plan-review-gate-01.md).
Verdict: PASS. No blocking findings were raised.

Non-blocking finding:

- N17-IP-01: prompt evidence CLI/config names were still left to
  implementation choice.

## Manager decisions

| ID | Decision | Reason |
| --- | --- | --- |
| D17-IP-01 | Use `--cache-prompt-evidence MODE` for prompt evidence mode. Valid modes: `off`, `redacted`, `raw`. Default: `off`. | This keeps the option in the cache namespace and matches the design's evidence-mode contract. |
| D17-IP-02 | Use `--cache-prompt-evidence-dir PATH` for JSONL evidence output. | This avoids overloading `--log-prompts-dir`, which controls raw prompt files. |
| D17-IP-03 | Raw mode may reference raw prompt files only when `--log-prompts-dir PATH` is also explicitly configured. | This preserves the design privacy rule that raw prompt capture is opt-in and separate from redacted evidence. |

## Manager gate checks

| Check | Result | Notes |
| --- | --- | --- |
| Approved design baseline is explicit | PASS | Part 1 links the Stage 17 design entry, parts 1-6, and Manager decisions D17-01 through D17-03. |
| Ordered steps are executable | PASS | Steps 1-12 cover config, diagnostics, evidence, prefix classification, cold budget, checkpoint policy, metrics, and tests in dependency order. |
| Affected files and modules are named | PASS | Plan names common args, server context, task metadata, hybrid cache, cold store, I/O worker, LRU policy, and focused tests. |
| Evidence and test plan are explicit | PASS | Plan lists focused C++ tests, integration/QA hooks, expected logs, metrics, JSONL samples, and prefix-restore exclusion evidence. |
| Risks and follow-ups are handled | PASS | N17-IP-01 is resolved by D17-IP-01 through D17-IP-03. Other risks have plan handling. |
| Review is recorded with a pass verdict | PASS | Part 2 records PASS with no blocking findings. |

## Advisory carry-forward

The implementation must:

- use `--cache-cold-max-mib`, `--cache-prompt-evidence`, and
  `--cache-prompt-evidence-dir`
- keep prompt evidence JSONL records separate from raw prompt files
- reject or warn on invalid evidence modes before request handling
- keep prefix restore disabled, except for bounded `unsafe_prefix_rejected`
  classification
- update implementation evidence with the final option wiring and tests

## Decision

The Stage 17 implementation plan is approved. The Manager
implementation-plan gate is PASS.

## Handoff

Next gate: implementation (Developer).

The Developer may start code and test work against the approved plan.
Implementation review remains closed until code, tests, and implementation
evidence are complete.
