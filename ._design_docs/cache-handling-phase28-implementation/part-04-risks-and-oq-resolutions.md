# Stage 28 implementation plan part 4: risks and OQ resolutions

Source: [../cache-handling-phase28-implementation.md](../cache-handling-phase28-implementation.md)

This part lists per-step risks and proposes resolutions for the six
open questions OQ-28-01..06 from design part-05. Each OQ resolution
records the Developer's proposed answer, the rationale, and the
reopen condition.

## OQ-28-01 resolution: defer R28-BUG-02 if root cause is refactor?

Question (verbatim): Should R28-BUG-02 fix be deferred to a separate
Stage 29 if the diagnosis step shows the root cause is a fundamental
refactor (not a one-line tweak)?

Developer proposal: DEFER-NO. Fix in Stage 28 iter 1. Iterate diagnosis
if root cause is more involved than the 3 candidates.

Rationale: User direction 2026-06-26 is "remove all technical debt and
fix all known open bugs". A fundamental refactor is the same scope as
a one-line tweak from a deliverable perspective. The user can choose
to commit Stage 28 partial work between iterations if the refactor
spans multiple commits.

Reopen condition: If Step 3 (diagnosis) reveals the orphan-file path
is none of the 3 candidates AND the fix requires > 200 lines of
production code change OR a new module OR a new metric, file
OQ-28-07 with the new path and reopen.

## OQ-28-02 resolution: iter 2 (MEDIUM) in scope?

Question (verbatim): Should iteration 2 (MEDIUM) be in scope for
Stage 28, or deferred to Stage 29 to keep this stage focused on HIGH?

Developer proposal: IN-SCOPE. User direction "remove all technical
debt" includes MEDIUM items per design part-01 inventory.

Rationale: HIGH items (4) + MEDIUM items (7) total 11 deliverables
across 2 iterations. Splitting to Stage 29 would leave Stage 28 with
just 4 fixes and Stage 29 with the remaining 7, which is unbalanced.
Two iterations in Stage 28 with a single test-execution gate between
them keeps the consolidation goal tight.

Reopen condition: If iter 2 wall-time exceeds 3 hours (planned: ~2
hours), defer the runner fixes (R28-TD-04, R28-TD-07) and the doc
updates (R28-TD-01, R28-TD-06) to Stage 29, keeping only R28-TD-02,
R28-TD-03, R28-TD-05 in iter 2.

## OQ-28-03 resolution: runner fixes iter 1 vs iter 2?

Question (verbatim): Should the runner script fixes (R28-TD-04,
R28-TD-07) be combined with iteration 1, or stay in iteration 2?

Developer proposal: ITER-2. Runner fixes do not unblock HIGH fixes.

Rationale: HIGH fix verification (Steps 1-7 + Step 8) does not depend
on the runner exiting 0. The Stage 24 -08 rerun in Step 8 captures
all the runner's per-leg summary.json files even when the runner
itself raises the `leak_scan` property error. The error is a
post-completion aggregation bug, not a per-leg execution bug.
Fixing it in iter 1 would mix scopes; fixing it in iter 2 isolates
the change to the runner contract only.

Reopen condition: If a future rerun during iter 1 (e.g., Step 3
diagnosis rerun or Step 8 rerun) depends on the runner exit code
being 0 for downstream tooling (e.g., a chained follow-up script),
promote R28-TD-04 to iter 1.

## OQ-28-04 resolution: bundle LOW prose typos?

Question (verbatim): Should iteration 3 (LOW cosmetic) be entirely
out-of-scope, or should the prose-typo items (R28-TD-08, R28-TD-09,
R28-TD-11) be bundled with the doc updates in iteration 2?

Developer proposal: BUNDLE-NO. LOW out-of-scope per design part-03.

Rationale: The 11 LOW items are all cosmetic and none affect
behavior or readability. The "11 test rows" prose typos (R28-TD-08,
R28-TD-09, R28-TD-11) are not user-facing in the durable reports
(the per-row verdict table is authoritative per developer improvement
memory "Reconcile test report prose summary count against per-row
sums"). Including the typo fixes in iter 2 mixes scopes and adds
review burden.

Reopen condition: If the user explicitly requests the typo fixes,
promote R28-TD-08, R28-TD-09, R28-TD-11 to iter 2 as a single doc
edit (3 line edits).

## OQ-28-05 resolution: R28-TD-05 in scope?

Question (verbatim): Should R28-TD-05 (dead `enqueue_demotion` /
`enqueue_promotion`) be in-scope given that the methods are dead code
on the production path?

Developer proposal: YES-CONDITIONAL. R28-TD-05 worker thread deletion
in iter 2, conditional on R28-BUG-04 Phase B compile-clean.

Rationale: Per design part-01 HIGH R28-BUG-04 inventory, the worker
thread infrastructure (worker_thread_, queue_cv_, work_queue_,
result_queue_, queue_mutex_, result_mutex_) is dead in production
because the thread is never started (per D25-DESIGN-01 Option B).
The 41+ test refs to debug_*_io_worker_for_tests keep the worker
thread nominally alive but execute_inline is the actual production
path. Deletion requires the test refs to be migrated first (R28-BUG-04
Phase B Steps 6-7), otherwise the build fails. Sequencing Phase B
(iter 1) before R28-TD-05 (iter 2) makes the deletion safe.

Reopen condition: If iter 1 R28-BUG-04 Phase B produces
deprecation warnings that cannot be resolved (e.g., 5+ tests
genuinely need the worker thread's race timing), skip R28-TD-05
and document the skipped tests as R28-TD-19+ items for a future
async-worker-revival stage.

## OQ-28-06 resolution: R28-BUG-04 Phase A sync vs rebuild async?

Question (verbatim): Should R28-BUG-04 Phase A use `tx_promote_payload`
(synchronous under the cache-state mutex) or rebuild a minimal async
path (e.g., `std::async`) for the 2 production callers?

Developer proposal: SYNC. tx_promote_payload synchronous under
cache_state_mutex_.

Rationale: Stage 25 design intent (D25-DESIGN-01 Option B) was
"replace with stateless helper". The `tx_` variant is the stateless
helper. The 2 affected production paths (load_slot cold payload
restore and stage23_admit_checkpoint_store) are not latency-critical
enough to justify re-introducing async I/O. Synchronous promotion
matches the existing Stage 25/26/27 synchronous path pattern and
removes the broken worker thread entirely.

Reopen condition: If Stage 24 -08 rerun shows restore latency
regression > 2x current (e.g., S02 hybrid cold payload restore
latency jumps from < 50 ms to > 100 ms, OR S03 hybrid cold
checkpoint restore latency jumps from < 50 ms to > 500 ms),
reopen OQ-28-06 with the latency numbers and consider an
`std::async` fallback that returns a future from `tx_promote_payload`.

## Per-step risks

### Step 1 risk (R28-BUG-01)

Severity: LOW. Likelihood: LOW. Mitigation: replace one assert at
a time; run full test pack after each replacement; verify pre-fix
regression aborts as expected. Contingency: if a replacement breaks
a prior test that was relying on the assert, restore that specific
assert and add a comment marking it as known-assert.

### Step 2 risk (R28-BUG-03)

Severity: LOW. Likelihood: LOW. Mitigation: Option A is well-known
CMake pattern. The generator expression `$<COMPILE_LANGUAGE:CXX>`
keeps the flag out of nvcc. Contingency: if Option A fails (CUDA
toolchain rejects the flag), fall back to Option B (--whole-archive
for ggml-cuda) or Option C (separate asan-llama-server target).

### Step 3 risk (R28-BUG-02 diagnosis)

Severity: MEDIUM. Likelihood: MEDIUM. Mitigation: add diagnostic
logging only; no behavior change; rerun is idempotent. Contingency:
if none of the 3 candidates match the diagnostic log, file OQ-28-07
with the new orphan-file path and stop iter 1.

### Step 4 risk (R28-BUG-02 fix)

Severity: HIGH. Likelihood: MEDIUM. Mitigation: add new TP-28-UT-01
unit test that drives the diagnosed path deterministically. Run the
test pre-fix (must abort) and post-fix (must PASS). Contingency: if
fix breaks S03 hybrid cold-store budget (was within 485 MiB of 512
MiB in -07), revert and reconsider Candidate B.

### Step 5 risk (R28-BUG-04 Phase A)

Severity: HIGH. Likelihood: MEDIUM. Mitigation: tx_promote_payload
already exists (Stage 25 design) and is verified by TP-27-UT-01.
Replace one caller at a time; rebuild; run test pack. Contingency:
if tx_promote_payload raises recursive-mutex reentrancy assertion
at load_slot or stage23 line, add `tx_assert_mutex_held()` call site
assertion to confirm lock state, fix caller to acquire mutex
explicitly before tx_ call.

### Step 6 + 7 risk (R28-BUG-04 Phase B)

Severity: MEDIUM. Likelihood: HIGH for partial migration gaps.
Mitigation: deprecate one symbol at a time; fix compile errors; run
test pack; repeat. Build incrementally. Per R28-RISK-05 worst case,
5-10 of 41+ tests may need re-architecting. Contingency: leave the
most complex tests as documented exceptions (with deprecation
warnings) and re-architect them in a future stage.

### Step 8 risk (iter 1 verification)

Severity: LOW. Likelihood: LOW. Mitigation: per design part-04
verification contract, all V1..V3 checks are pre-validated.
Contingency: if Stage 24 -08 rerun fails any leg, revert the
Step 4/5 fix and re-run to isolate the regression source.

### Step 9 risk (MEDIUM items)

Severity: LOW. Likelihood: LOW. Mitigation: each MEDIUM item is
independent; per-item stop condition. Contingency: skip an item
that surfaces unexpected complications; document as R28-TD-19+
for future stage.

### Step 10 risk (R28-TD-05 conditional deletion)

Severity: MEDIUM. Likelihood: LOW. Mitigation: only proceed after
Step 7 deprecation warnings are zero. Deletion is mechanical
(remove worker internals; remove debug accessors). Contingency:
if deletion breaks an unexpected test ref that was missed in
Step 7, restore that specific symbol and re-run.

## Cross-step risks (recap from design part-05)

- R28-RISK-01 (re-introducing uncommitted churn): mitigated by
  using function names not line numbers; line numbers verified
  against current HEAD before commit.
- R28-RISK-02 (test pack size creep): 3 new tests add ~1 sec
  each; total runtime stays under 10 sec.
- R28-RISK-03 (cold-store fix perturbs S03 hybrid): Stage 24 -08
  rerun is mandatory; S03 hybrid 687 reqs threshold is the canary.
- R28-RISK-04 (ASan breaks CUDA build): generator expression
  `$<COMPILE_LANGUAGE:CXX>` scopes the flag to host only.
- R28-RISK-05 (Phase B breaks 41+ tests): incremental migration;
  deprecate one symbol at a time.
- R28-RISK-06 (Phase A restore latency): reopen OQ-28-06 if > 2x.
- R28-RISK-07 (stage23 wait loop removal changes semantics):
  TP-23 stage23_admit_checkpoint test verifies the new synchronous
  behavior; same expected timing.

This file uses LF line endings, plain ASCII status labels, no
BOM, no trailing whitespace, and stays under the 300-line
durable-doc cap.
