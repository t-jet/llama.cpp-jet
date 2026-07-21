# Stage 39 design: two-layer payload retention

Date: 2026-07-12
Status: CLOSED PASS 2026-07-17; see implementation Part 205

## Goal

Under hybrid-cache payload pressure, discard reusable payload bytes only after
both hot and cold layers cannot retain them because their enabled capacities are
filled. Preserve metadata and correctness contracts from earlier stages.

## Parts

- [Part 1: contract and invariants](cache-handling-phase39-design/part-01-contract-and-invariants.md)
- [Part 2: transaction and failure design](cache-handling-phase39-design/part-02-transaction-and-failure-design.md)
- [Part 3: observability, tests, and acceptance](cache-handling-phase39-design/part-03-observability-tests-acceptance.md)
- [Part 4: Architect design review](cache-handling-phase39-design/part-04-architect-design-review-20260712.md)
- [Part 5: independent Architect design review](cache-handling-phase39-design/part-05-independent-architect-design-review-20260712.md) - historical verdict: REWORK REQUIRED
- [Part 6: design correction record](cache-handling-phase39-design/part-06-design-corrections-20260712.md) - resolves F39-AR2-01 through F39-AR2-04 and advisories
- [Part 7: independent Architect design re-review](cache-handling-phase39-design/part-07-independent-architect-re-review-20260712.md) - current verdict: REWORK REQUIRED
- [Part 8: mode label correction](cache-handling-phase39-design/part-08-mode-label-correction-20260712.md) - addresses F39-AR3-01; closed by Part 9 PASS
- [Part 9: independent Architect design re-review](cache-handling-phase39-design/part-09-independent-architect-re-review-20260712.md) - current verdict: PASS
- [Part 10: Manager design gate](cache-handling-phase39-design/part-10-manager-design-gate-20260712.md) - current verdict: PASS
- [Part 11: live pressure testability correction](cache-handling-phase39-design/part-11-live-pressure-testability-correction-20260713.md) - F39-LPCR-RR-01 corrected; Part 14 review PASS
- [Part 12: independent live pressure correction review](cache-handling-phase39-design/part-12-independent-live-pressure-correction-review-20260713.md) - REWORK; Developer documentation correction required
- [Part 13: independent live pressure correction re-review](cache-handling-phase39-design/part-13-independent-live-pressure-correction-rereview-20260713.md) - REWORK; cold-victim ranking and executable coverage probes remain open
- [Part 14: independent live pressure correction re-review](cache-handling-phase39-design/part-14-independent-live-pressure-correction-rereview-20260713.md) - PASS; Parts 13 findings closed
- [Part 15: guarded discovery correction](cache-handling-phase39-design/part-15-guarded-discovery-correction-20260713.md) - accepted by Part 18 PASS
- [Part 16: independent guarded discovery review](cache-handling-phase39-design/part-16-independent-guarded-discovery-review-20260713.md) - historical REWORK corrected by implementation Part 46
- [Part 17: independent guarded discovery re-review](cache-handling-phase39-design/part-17-independent-guarded-discovery-rereview-20260713.md) - REWORK; test-plan Part 43 still carries the superseded seam contract
- [Part 18: independent guarded discovery re-review](cache-handling-phase39-design/part-18-independent-guarded-discovery-rereview-20260713.md) - PASS; F39-GDR-RR-01 closed and Manager correction gate ready
- [Part 19: TP-39-03 owner-reassignment correction](cache-handling-phase39-design/part-19-tp39-03-owner-reassignment-correction-20260713.md) - corrected for checkpoint compatibility and executable workload reachability
- [Part 20: independent TP-39-03 owner-reassignment review](cache-handling-phase39-design/part-20-independent-tp39-03-owner-reassignment-review-20260713.md) - REWORK; checkpoint compatibility and executable workload reachability remain open
- [Part 21: independent TP-39-03 owner-reassignment re-review](cache-handling-phase39-design/part-21-independent-tp39-03-owner-reassignment-rereview-20260713.md) - REWORK; checkpoint compatibility closes, but the Qwen3-0.6B fixture cannot produce the required runtime checkpoint
- [Part 22: independent TP-39-03 MTP workload re-review](cache-handling-phase39-design/part-22-independent-tp39-03-mtp-workload-rereview-20260713.md) - PASS; F39-ORR-02 closes and Manager correction-plan gate is ready
- [Part 23: TP-39-03 context-capacity correction](cache-handling-phase39-design/part-23-tp39-03-context-capacity-correction-20260713.md) - D39-EXEC-06 correction to context 8192; accepted by Part 24 PASS
- [Part 24: independent TP-39-03 context-capacity review](cache-handling-phase39-design/part-24-independent-tp39-03-context-capacity-review-20260713.md) - PASS; D39-EXEC-06 Manager correction gate ready
- [Part 25: TP-39-03 measured startup-budget correction](cache-handling-phase39-design/part-25-tp39-03-measured-budget-correction-20260713.md) - D39-EXEC-07 correction; reviewed REWORK in Part 26
- [Part 26: independent TP-39-03 measured-budget review](cache-handling-phase39-design/part-26-independent-tp39-03-measured-budget-review-20260713.md) - REWORK; complete-pair resident provenance and executable serialized-size measurement remain open
- [Part 27: TP-39-03 complete-pair size provenance correction](cache-handling-phase39-design/part-27-tp39-03-complete-pair-size-provenance-correction-20260713.md) - D39-EXEC-08 correction; reviewed REWORK in Part 28
- [Part 28: independent complete-pair size provenance review](cache-handling-phase39-design/part-28-independent-complete-pair-size-provenance-review-20260713.md) - REWORK; proof surface, formula unit, and canonical reachability remain open
- [Part 29: TP-39-03 reachable production proof correction](cache-handling-phase39-design/part-29-tp39-03-reachable-production-proof-correction-20260713.md) - D39-EXEC-09 proof surface and smallest valid live contract correction; reviewed REWORK in Part 30
- [Part 30: independent reachable production proof review](cache-handling-phase39-design/part-30-independent-reachable-production-proof-review-20260713.md) - REWORK; canonical serialized provenance and exact proof-test mapping remain open
- [Part 31: TP-39-03 prepared-size proof correction](cache-handling-phase39-design/part-31-tp39-03-prepared-size-proof-correction-20260713.md) - D39-EXEC-10 production-boundary size proof and exact test map; reviewed REWORK in Part 32
- [Part 32: independent prepared-size proof review](cache-handling-phase39-design/part-32-independent-prepared-size-proof-review-20260713.md) - REWORK; generation lifecycle, boundary abort, and compile guard need correction
- [Part 33: TP-39-03 session, generation, and abort correction](cache-handling-phase39-design/part-33-tp39-03-session-generation-abort-correction-20260713.md) - D39-EXEC-11 correction; reviewed REWORK in Part 34
- [Part 34: independent session, generation, and abort review](cache-handling-phase39-design/part-34-independent-session-generation-abort-review-20260713.md) - REWORK; finalization, pressure return, and exact-sync ordering remain open
- [Part 35: TP-39-03 terminal ordering correction](cache-handling-phase39-design/part-35-tp39-03-terminal-ordering-correction-20260713.md) - D39-EXEC-12 correction; historical REWORK in Part 36
- [Part 36: independent terminal ordering review](cache-handling-phase39-design/part-36-independent-terminal-ordering-review-20260713.md) - REWORK; exact phase-boundary generation ownership remains open
- [Part 37: TP-39-03 generation-boundary correction](cache-handling-phase39-design/part-37-tp39-03-generation-boundary-correction-20260713.md) - D39-EXEC-13 correction; reviewed REWORK in Part 38
- [Part 38: independent generation-boundary review](cache-handling-phase39-design/part-38-independent-generation-boundary-review-20260713.md) - REWORK; planned refresh and sync cause extra generation advances
- [Part 39: TP-39-03 read-only generation-boundary correction](cache-handling-phase39-design/part-39-tp39-03-read-only-generation-boundary-correction-20260713.md) - D39-EXEC-14 correction; Part 40 review PASS
- [Part 40: independent read-only generation-boundary review](cache-handling-phase39-design/part-40-independent-read-only-generation-boundary-review-20260713.md) - historical PASS; superseded by Part 41
- [Part 41: TP-39-03 both-kind batch-boundary correction](cache-handling-phase39-design/part-41-tp39-03-both-kind-batch-boundary-correction-20260713.md) - D39-EXEC-16 correction; reviewed REWORK in Part 42
- [Part 42: independent both-kind batch-boundary review](cache-handling-phase39-design/part-42-independent-both-kind-batch-boundary-review-20260713.md) - REWORK; midpoint-fault cleanup and actual fault-generation ordering remain open
- [Part 43: TP-39-03 fault common-epilogue correction](cache-handling-phase39-design/part-43-tp39-03-fault-common-epilogue-correction-20260713.md) - D39-EXEC-17 correction; reviewed PASS in Part 44
- [Part 44: independent fault common-epilogue review](cache-handling-phase39-design/part-44-independent-fault-common-epilogue-review-20260713.md) - PASS; F39-BBR-01 and F39-BBR-02 closed, Manager gate next
- [Part 45: TP-39-03 route fixture correction](cache-handling-phase39-design/part-45-tp39-03-route-fixture-correction-20260714.md) - Architect PASS; bounded Part 62 MTP source admission resolves the D39-EXEC-18 route fixture blocker at design level
- [Part 46: TP-39-03 draft-MTP startup correction](cache-handling-phase39-design/part-46-tp39-03-draft-mtp-startup-correction-20260714.md) - Architect PASS; adds the omitted `--spec-type draft-mtp` selector and complete fail-closed preflight delta
- [Part 47: TP-39-03 trace preflight correction](cache-handling-phase39-design/part-47-tp39-03-trace-preflight-correction-20260714.md) - Architect PASS; binds the two trace literals to explicit level 4 and caps the test log
- [Part 48: TP-39-03 Prometheus parser correction](cache-handling-phase39-design/part-48-tp39-03-prometheus-parser-correction-20260714.md) - Architect PASS; replaces invalid brace slicing with strict Stage 39 Prometheus parsing and pure pre-rerun tests
- [Part 49: TP-39-03 pre-validation capture correction](cache-handling-phase39-design/part-49-tp39-03-prevalidation-capture-correction-20260714.md) - Architect PASS; requires raw discovery and parsed metrics before validation, then one capture-only midpoint diagnostic
- [Part 50: TP-39-03 slot-release workload correction](cache-handling-phase39-design/part-50-tp39-03-slot-release-workload-correction-20260714.md) - Architect PASS; classifies the empty inventory as active-slot state and adds the approved second request needed to release the source node
- [Part 51: TP-39-03 proof-only midpoint correction](cache-handling-phase39-design/part-51-tp39-03-proof-only-midpoint-correction-20260714.md) - Architect PASS; corrects cold-set key semantics and defines one fixed-stop proof-only midpoint smoke
- [Part 52: TP-39-03 terminal route evidence correction](cache-handling-phase39-design/part-52-tp39-03-terminal-route-evidence-correction-20260714.md) - Architect correction; complete terminal state and forbidden-effect proof required before fault rerun
- [Part 53: TP-39-03 observed forbidden-effect correction](cache-handling-phase39-design/part-53-tp39-03-observed-forbidden-effect-correction-20260714.md) - Architect correction; replace literal zero claims with production observations before fault rerun

## Scope

Stage 39 changes hybrid mode only. It covers exact-blob and checkpoint payloads,
including atomic target/draft pairs. It does not change restore ranking, branch
topology, metadata budget policy, public API schemas, or legacy cache behavior.

Prerequisites: Stage 38 closure PASS; Stage 25 transaction invariants; ADR-009
payload-eviction versus branch-pruning distinction.

## Handoff

Part 10 remains the approved runtime design gate. Part 18 closes
F39-GDR-RR-01. Part 22 is historical PASS for the 4096 workload contract, which
Part 64 proved unable to retain both required owners. Part 23 corrects only that
capacity contract under D39-EXEC-06. Part 24 records historical review PASS.
Part 25 applies D39-EXEC-07. Part 26 records REWORK. Part 27 addresses it under
D39-EXEC-08. Part 28 records fresh REWORK. Part 29 applies D39-EXEC-09: it adds
the missing locked proof contract, binds every size input, proves the old live
precursor impossible, and proposes the smallest valid natural same-owner live
transition. Part 30 records historical REWORK. Part 31 applies D39-EXEC-10: the
canonical process captures immutable exact sizes at the real preparation
boundary and names every proof test. Part 32 records historical REWORK. Part 33
binds immutable session IDs, per-step generations, abort plumbing, and the real
seam guard. Part 34 records historical REWORK. Part 35 applies D39-EXEC-12: it
places exact accounting and branch sync before step 2, returns immediately from
pressure on abort, and freezes terminal generation and HMAC only after the full
`tx_update()` returns. Part 36 records REWORK because the compound exact
accounting and branch-sync mutation does not yet own a generation advance before
step 2 is armed. Part 37 attempts D39-EXEC-13 with one guarded
post-verification advance and binds the record/HMAC chain to it. Part 38 finds
F39-GBR-01: the planned refresh and branch sync already advance generation.
Part 39 applies D39-EXEC-14 and Part 40 records historical PASS. Part 77 then
proves that exact demotion has not synchronized branch aggregate at that point.
Part 41 applies D39-EXEC-16 at the both-kind batch boundary. Part 42 records
historical REWORK for midpoint-fault cleanup and fault-generation ordering.
Part 43 applies D39-EXEC-17: midpoint and step-2 faults preserve exact
`changed`, skip forbidden checkpoint work, reach the outer accounting and
branch-sync epilogue, then freeze coherent terminal failure proof. A stale
branch exact commit requires observed production sync generation strictly
greater than exact return, with no fixed delta or seam-only advance. Fresh
independent review PASS is recorded in Part 44. Part 45 approves an isolated
Part 62 MTP source-admission fixture for the two blocked route nodes. It keeps
the natural same-owner pair, exact preflight, fixed caps, and fail-closed gate.
Part 85 proved Part 45's copied startup list omitted the selector required to
create an MTP draft context. Part 46 supersedes only that list with
`--spec-type draft-mtp`. Part 88 proves that selector works, then stops because
two binding capability literals are trace-only. Part 47 adds explicit trace
level 4 and a bounded test log. Part 91 proves those trace checks, then exposes
an invalid JSON assumption in the test helper's Prometheus parser. Part 48
defines the parser correction and pure tests. Part 94 proves the parser but
loses discovery and metric values before its inventory blocker. Part 49
requires pre-validation capture and one midpoint diagnostic that must stop
before proof or apply. Part 97 captures one branch node and empty inventory.
Part 50 traces that result to the source slot reference retained after
completion and corrects the fixture with Part 62's approved incoming request.
Part 100 then records the successful lifecycle and a helper stop before proof.
Part 51 confirms that each cold-set key copies its hot row. D39-EXEC-25 proves
the natural pair. Part 52 defines the terminal matrix; Part 53 corrects seven
literal zero claims that do not observe their named effects. Manager correction
gate is next; fault execution and QA remain blocked.
