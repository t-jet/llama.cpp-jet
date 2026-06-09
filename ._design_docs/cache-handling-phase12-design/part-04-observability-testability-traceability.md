# Stage 12 design: observability, testability, evidence, traceability, risks, and handoff -- Part 4

Source: [../cache-handling-phase12-design.md](../cache-handling-phase12-design.md)

## Observability

Stage 12 uses the Stage 10 public observability contract. It does not
rename or add public metrics.

Required observable groups:

| Group | Evidence |
| --- | --- |
| Cache outcomes | public hit, miss, exact restore, checkpoint, fallback, and diagnostic rows where exposed |
| Payload residency | hot payload bytes, cold payload bytes, hot/cold counts, demotion, promotion, cold restore latency |
| Eviction and protection | payload eviction counters, protected-root decision counters, budget diagnostics |
| Branch graph | branch lookup, namespace validation, metadata budget, metadata-only retention, rematerialization, mismatch, deduplication, pruning, cleanup ownership rows where exposed |
| Checkpoint behavior | checkpoint hit, restore, admission, and admission failure rows for capable fixtures |
| Security and leakage | bounded diagnostic labels and logs without prompt text, marker text, local paths, checksums, payload bytes, model paths, or serialized state |
| Resource stability | working set, handle or file descriptor count, CPU, disk I/O, cold-store file count, server liveness |

If a required row is internal-only or not publicly exposed, the report
must say which focused source proves the precondition and which public
row proves the operator-visible result. Do not cite controller stats as
public Prometheus evidence.

## Testability

Stage 12 relies on existing test seams and tools:

- clean build and focused ctest preflight
- public HTTP requests against `llama-server`
- public `/metrics` snapshots
- structured server logs
- deterministic prompt generators and fixed seeds
- fake stores or fault injection only for preconditions public HTTP
  cannot create
- coverage script output for T114, T114a, and T115
- MTP or checkpoint-capable public probe for T121 when fixture exists
- load-tool output for throughput and latency
- resource sampler output for long-run stability

The QA plan must map each stress and benchmark row to an evidence
source before execution opens. A row that cannot create its precondition
is `BLOCKED`, not `PASS`.

The QA plan cannot open while Stage 11 cap-fix T-MTP-FIX-01 plus
T114/T114a remain open, unless Manager narrows Stage 12 before execution
opens. Any narrowing must remove affected draft/MTP/cap-fix/coverage rows
from required closure scope and update the report shape before evidence
collection starts.

## Required report shape

Stage 12 execution uses a fresh report in
`._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`. The report
must include:

- stage number, design baseline, implementation baseline, and date
- owner, reviewer, and Manager gate state
- commit SHA and dirty working-tree state
- build commands, targets, binary timestamp, and tool versions
- model fixture table with capabilities and exclusions
- configuration matrix actually run
- stress scenario table with verdicts and artifacts
- benchmark scenario table with verdicts and artifacts
- legacy comparison table
- long-run resource table
- baseline numbers for future regression detection
- bottleneck and tuning report
- T114, T114a, T115, and T121 status when applicable
- cap-fix T-MTP-FIX-01 plus T114/T114a closure status, or the
  Manager-approved narrowing record that excludes those rows
- final `PASS`, `FAIL`, `SKIP`, and `BLOCKED` counts
- bug-fix or rerun handoff when any row fails or blocks closure

The report records run results. This design does not.

## Acceptance criteria

Stage 12 passes only when:

- Required stress rows show no crash, hang, leak, unbounded resource
  growth, unsafe restore, data corruption, unbounded log growth, or
  unbounded metric label growth.
- Required benchmark rows prove correctness before performance claims.
- Hybrid mode shows measurable gain on at least one configured target
  workload.
- Legacy mode correctness, public surface, and performance remain within
  recorded variance or have a Manager-approved explanation.
- Baseline numbers are recorded with enough environment detail for
  later regression comparison.
- The tuning report names observed bottlenecks and safe operator
  settings.
- Missing tools or fixtures are resolved, or the Manager narrows scope
  before execution opens.
- Stage 11 cap-fix T-MTP-FIX-01 plus T114/T114a are resolved, or Manager
  narrows Stage 12 before execution opens to exclude affected
  draft/MTP/cap-fix/coverage rows.
- Any product bug has a fix loop and re-review before closure.

## Risks

| Risk | Impact | Mitigation before closure |
| --- | --- | --- |
| Long-run host is noisy or power-throttled | Baselines cannot be trusted | Record hardware, power mode, competing load, and rerun if variance exceeds threshold. |
| Model fixture lacks checkpoint or draft capability | Mixed-profile rows cannot execute | Mark the row `BLOCKED` and require Manager scope decision before closure. |
| Stage 11 cap-fix cycle remains open | Draft/MTP stress, benchmark, and coverage carry-forward would use unsettled baseline evidence | Block implementation planning, QA planning, stress execution, benchmark execution, and closure until T-MTP-FIX-01 plus T114/T114a are resolved, unless Manager narrows scope before execution opens. |
| Public metrics cannot expose an internal precondition | Operator claim may be over-claimed | Split focused precondition evidence from public metric evidence. |
| Stress run passes but benchmark correctness is weak | Performance claim may hide unsafe reuse | Block benchmark verdict until correctness gate passes. |
| Legacy path regresses during hybrid validation | Default behavior risk | Treat as closure blocker unless Manager accepts a documented external cause. |
| Multi-hour artifacts grow too large | Evidence becomes hard to review | Sample metrics at fixed intervals and keep raw logs as artifacts, not pasted report bodies. |
| Benchmark gain appears only after unstable tuning | Operators cannot reproduce it | Record flags, budgets, prompt mix, and variance; avoid claims for unrepeatable gains. |

## Exclusions

Stage 12 excludes:

- new cache algorithms
- new public cache inspection endpoints
- new CLI flags
- public metric or diagnostic schema changes
- upstream merge work
- security redesign beyond observing Stage 10 mitigations under load
- durable behavior changes recorded only in reports
- broad documentation rewrites outside the Stage 12 design and index

If execution uncovers a design gap that requires behavior change, the
Architect opens a correction or a new stage. The test report alone does
not change durable behavior.

## Requirement traceability

| Requirement range or contract | Stage 12 disposition |
| --- | --- |
| Activation and compatibility (R1-R4) | Covered by hybrid opt-in and legacy control rows in Part 1 and Part 3. |
| Hybrid model and model-family awareness (R5-R14, R84-R86) | Covered by mixed workload, draft presence, and namespace checks in Part 2. |
| Non-destructive hits, reuse-aware eviction, protected roots (R15-R26) | Covered by exact-hit benchmarks, budget exhaustion stress, and protected-root pressure rows. |
| Prepared-prompt boundaries (R27-R33) | Covered through checkpoint and workload profile benchmark rows where fixture supports boundary metadata. |
| Correctness and fallback (R34-R36, R36a-R36d, R90-R92, R120-R124) | Covered by correctness gates, integrity failure stress, and fallback diagnostics. |
| Payload separation, cold layer, hot/cold residency (R37-R60, R93-R98) | Covered by cold transition benchmark, cold queue pressure stress, and resource stability checks. |
| Observability (R61-R68) | Covered by required public metric snapshots and leakage checks in this part. |
| Shared branch graph and slot-independent reuse (R69-R83, R83a) | Covered by large branch forest, concurrent multi-slot access, and mixed namespace rows. |
| Metadata-only branch nodes and payload/pruning lifecycle (R38a-R38c, R71a-R71e, R76a, R79a-R79b, R55a) | Covered by large-forest stress and branch graph observability rows. |
| Validation mismatch and mismatch-parent selection (R36a-R36d, R39a-R39c, R71e, R123a) | Covered by large-forest and integrity/fallback stress where focused preconditions are needed. |
| Budget accounting and pruning preference (R8a, R8b, R21a, R57a-R57e) | Covered by budget exhaustion, branch metadata pressure, and protected-root pressure rows. |
| Eviction policy evolution (R20a, R20b) | Covered by eviction churn and tuning report rows without adding a new policy. |
| Code quality and best practices (R130, R131) | Covered by clean build, reproducible evidence, and no behavior change in this design. |
| Multimodal safety (R87-R89) | Covered by fixture capability checks and explicit unsupported-shape fallback for mixed-profile rows. |
| Testability and verification (R99-R106, R125-R129) | Covered by evidence-source mapping, deterministic seeds, coverage rows, and report shape. |
| Security review and abuse handling (R121-R123, R132-R133) | Covered by leakage checks, bounded diagnostics, cold-store resource checks, and integrity failure rows. |
| T114 and T114a coverage floors | Kept as current closure contracts when Stage 12 changes code or tests; cited from coverage report combined and product-only blocks. |
| Stage 11 cap-fix T-MTP-FIX-01 | Blocks Stage 12 draft/MTP planning and execution until public repro evidence is resolved or Manager narrows scope before execution opens. |
| T115 per-file aggregation rule | Kept as a closure contract for coverage evidence. |
| T121 public checkpoint admission row | Kept as a public checkpoint probe contract where fixture support exists. |

## Handoff

Architect design re-review PASS is recorded in
[part-07-design-re-review-gate-01.md](part-07-design-re-review-gate-01.md).
The Manager decides whether to open any later gate. Implementation
planning, QA planning, stress execution, benchmark execution, and closure
stay blocked by Stage 11 cap-fix T-MTP-FIX-01 plus T114/T114a unless
Manager narrows Stage 12 before execution opens.

The next owner after Manager approval records:

- concrete stress and benchmark command family
- concrete configuration matrix values
- concrete thresholds before execution starts
- artifact directory layout
- evidence-source mapping per row
- ownership for any blocked fixture or tooling prerequisite

No stress run, benchmark run, test report, code change, commit, or PR
work is authorized by this design.
