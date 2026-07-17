# Part 83: route fixture plan and Stage 39 process review

Date: 2026-07-14
Status: HISTORICAL ARCHITECT PASS; STARTUP LIST CORRECTED BY DESIGN PART 46
Scope: D39-EXEC-18 route fixture plan and Stage 39 delivery review

## Route fixture plan

Implement design Part 45 without changing product code or the guarded route.
Add a dedicated MTP helper used only by the midpoint and step-2 route nodes.
Keep `Stage39Server` and its Qwen3-0.6B fixture unchanged for all other route
tests. Remove the stale exact-only fallback comment in `_natural_prepared_apply`;
the Part 45 preflight is now the only contract.

The MTP helper must:

1. Require the exact Part 62 model, template, flags, literal source request, and
   environment opt-in from Part 45. Use hot 2048 MiB for the natural hot-pair
   baseline, not Part 62's measurement budget.
2. Start one fresh process and cold root per node. Enforce the wall, RSS, disk,
   request, and process caps before each operation.
3. Admit the literal source through `/v1/chat/completions`, wait for idle, then
   run discovery and proof. Do not call apply until every capability and
   baseline assertion passes.
4. Bind apply to exactly the proof's exact and checkpoint IDs, same owner,
   current generation, HMAC token, and prepared-size records. Keep exact step 1
   and checkpoint step 2.
5. Preserve command, environment names without token values, request SHA-256,
   response, startup log, preflight result, inventories, metrics, proof, failed
   apply response, retrieval, and final state in a node-specific directory.
6. Return a fixed blocked reason before apply on missing fixture, capability,
   wrong row count/order, extra inventory, drift, timeout, RSS, or disk breach.

Run the two exact node IDs sequentially. Acceptance is `2 passed`, no skips,
with both nodes proving fixture independence. Do not run canonical TP-39-03,
coverage, the full route suite, full QA, or another model workload in this gate.

## Why Stage 39 took many turns

Some complexity was unavoidable. Stage 39 changes a synchronous transactional
state machine that owns hot memory, cold files, descriptors, entry accounting,
branch projections, public metrics, crash recovery, and target/draft pairs.
TP-39-03 also depends on model-created checkpoints and exact production
ordering. Atomic faults, generation freshness, HMAC binding, and retained
topology need separate evidence. Independent review is justified for those
boundaries.

Most correction volume was avoidable. The stage repeatedly approved prose
before proving that its fixture and transition could run:

- Parts 12-18 corrected discovery, selector parity, generation ownership, and
  the active QA schema after implementation had started.
- Parts 20-22 replaced a plain-transformer assumption with the MTP fixture.
- Parts 23-30 then corrected context capacity, measured budgets, complete-pair
  provenance, and an unreachable owner-reassignment precursor.
- Parts 31-44 corrected proof capture, session and generation ownership, abort
  ordering, and the real common epilogue one boundary at a time.
- QA reports 20260712-02 through 20260713-01 repeatedly reached live blockers
  after expensive build and execution work. Part 81 finally showed that the
  approved route helper still admitted exact-only state; Part 82 confirmed the
  helper comment and assertion disagreed.

The main defect was contract timing. Fixture capability, route admission, the
production call graph, and evidence ownership were treated as later execution
details. They were design inputs.

## Root causes

| Cause | Evidence | Effect |
| --- | --- | --- |
| Executable feasibility came late | Parts 21, 24, 26, 28, and 30 each found a different workload, context, size, or reachability blocker. | Review corrected one prerequisite per turn. |
| Capability preflight was incomplete | Part 62 defined MTP checks, but Part 81's route helper still used Qwen3-0.6B and Part 82 found no natural pair. | Controller PASS could not transfer to HTTP evidence. |
| Route/controller parity was assumed | Part 81 passed both controller faults while both route nodes stopped before fault apply. | Internal state construction hid a missing transport fixture. |
| Design-to-test contracts omitted executable inputs | Early Part 43 revisions named behaviors and tests before fixing model, startup, literal body, IDs, caps, and fail-closed results together. | Tests encoded comments that no fixture satisfied. |
| Gates were too narrow | Parts 31-44 alternated correction and review around coupled generation and epilogue fields. | A single call-flow issue produced several review cycles. |
| Stop and reopen rules were weak | Repeated live calibration continued until Parts 59, 64, 67, and 77 each proved a structural blocker. | Runtime cost rose without new authority or a reachable state. |
| Evidence ownership was split | QA, Developer, Architect, and Manager records each owned pieces of fixture, schema, proof, and execution state. | Active entry and test-plan wording lagged the latest contract. |
| Expensive work ran before cheap smoke | Full builds, route suites, and QA preceded a one-request checkpoint capability probe. | Failures surfaced near the end of the pipeline. |

## Process changes

### P0: require an executable contract capsule

Before implementation authorization, every model-backed row must have one
reviewed capsule containing:

- exact model identity, startup flags, literal request bytes, endpoint, and
  resource caps;
- a capability probe with fixed PASS and BLOCKED outcomes;
- the required pre-state, one production action, expected post-state, and all
  forbidden setup mutations;
- controller and route setup parity, including which layer creates each object;
- exact test IDs, artifacts, owner for each artifact, and closure criterion.

Design review cannot pass a live row with placeholders in this capsule. A
metadata-only check is enough before code when model execution is not yet
authorized; Manager may then allow one bounded admission/discovery smoke before
the implementation gate.

### P0: add fixture capability preflight

Create one reusable, read-only preflight for the driver and model-backed route
tests. It must check model metadata, startup log capability, literal workload
hash, token/context limits, idle admission, checkpoint presence, exact owner
links, residency, pair compatibility, and resource headroom. It returns a fixed
reason and performs no apply. Tests may add assertions, but must not implement a
different capability definition.

### P0: bind an evidence matrix to owners

At stage opening, add one matrix with columns:

```text
requirement | precondition | producer | artifact | assertion | owner | gate
```

The Manager owns matrix completeness. Developer owns focused and route
artifacts, QA owns independent execution and coverage, Architect owns contract
traceability, and Manager owns state reconciliation. No gate advances while a
required cell is blank or points only to prose.

### P1: review coupled boundaries together

Batch findings by production boundary, not by document paragraph. For a
two-kind pressure transaction, one Architect review must trace preparation,
classification, commit, accounting, branch sync, generation, abort, HTTP
response, and both controller and route assertions in one pass. The reviewer
returns all known findings for that boundary. Preserve independent review at
design acceptance, implementation acceptance, QA-plan acceptance, and closure;
remove extra independent turns that only confirm wording edits.

### P1: define stop and reopen criteria

Stop calibration after the second failure with the same missing precondition,
or immediately when source trace proves the state unreachable. Reopen only with
one of: a new capability fact, a reviewed fixture change, a corrected production
trace, or a Manager scope decision. New prompt lengths or budgets alone do not
reopen a structural blocker. Record `BLOCKED-structural`, owner, required new
fact, and the last safe checkpoint.

### P1: order automation from cheap to expensive

Use this fixed order:

1. schema and pure helper self-tests;
2. model metadata and startup capability probe;
3. one literal admission plus discovery/proof smoke;
4. focused controller tests;
5. exact route nodes;
6. full route and script suites;
7. canonical model scenario;
8. coverage merge probes;
9. independent full QA.

Each step consumes artifacts from the previous step and stops on failure. The
full QA run never doubles as fixture discovery.

### P2: keep active contracts small

Use one current contract page per open row and move superseded detail to
history. Entry docs should link the current capsule, current evidence matrix,
last gate, and next owner. Historical parts remain immutable. This preserves
review evidence while reducing the chance that an implementer follows an old
budget, route schema, or handoff.

## Preserved safeguards

These changes do not relax independent review, 80 percent changed-line
coverage, clean builds, fixed artifacts, fail-closed classification, fresh
process and root requirements, security guards, transaction fault coverage, or
the ban on synthetic live PASS. They move feasibility proof earlier and group
related review work.

## Gate

Architect verdict: PASS for the Part 45 route-fixture plan. Process findings are
recommendations for Stage 40 and later; they do not rewrite Stage 39 acceptance.
Manager Part 84 authorized this plan. Part 85's execution then found the copied
startup list lacked `--spec-type draft-mtp`. Design Part 46 and implementation
Part 86 own that narrow correction. Canonical TP-39-03, coverage, full QA,
commit, and push remain blocked.
