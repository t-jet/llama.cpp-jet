# Stage 29 implementation plan part 4: risks and OQ resolutions

Source: [../cache-handling-phase29-implementation.md](../cache-handling-phase29-implementation.md)
Companion: [part-01a-steps-1-5.md](./part-01a-steps-1-5.md), [part-01b-steps-6-10.md](./part-01b-steps-6-10.md), [part-02-affected-files.md](./part-02-affected-files.md), [part-03-evidence-plan.md](./part-03-evidence-plan.md)

This part lists all 12 design risks from
[part-09](../cache-handling-phase29-design/part-09-risk-register.md),
the 2 implementation-specific risks from the Stage 29 implementation
brief, and the resolutions for the 3 re-reviewer INFO observations
(C-01..C-03) plus the 1 open question that needs Manager attention
(OQ-29-01). Each risk records the trigger, the impact, the
mitigation, and the step in part-01 that operationalizes the
mitigation.

## Design risks (R29-01..R29-12, cited from part-09)

The full register is at
[part-09](../cache-handling-phase29-design/part-09-risk-register.md).
The implementation plan operationalizes the mitigations as follows:

| Risk | Trigger | Mitigation step | Mitigation before approval |
| --- | --- | --- | --- |
| R29-01 | Synthetic workload may not represent real agentic behavior | S29-IMPL-04 emits per-cache_class counts in workload.jsonl; S29-IMPL-08 records per-mode, per-cache-class per-request metrics; S29-IMPL-09 surfaces per-cache-class columns in Layer 2 | Driver records cache_class field in requests.jsonl; report includes workload shape summary table |
| R29-02 | VRAM release delay between legs | S29-IMPL-07 VRAM cooldown gate (180s cap) | Driver checks VRAM after every cooldown; report records cooldown durations |
| R29-03 | Output equivalence diff caused by model nondeterminism, not cache | S29-IMPL-05 byte-comparison; diff.txt preserved for post-mortem | Driver writes decoded text per prompt per mode; diff file is durable |
| R29-04 | Cold-store drift still observed after Stage 28 R28-BUG-02 reconcile | S29-IMPL-08 records drift ratio per leg; classifies OK-with-drift-warning (>1.10) or BLOCKED-cold-store-drift (>5.0) | Driver writes cold_store_drift_ratio per leg; Layer 3 includes drift summary |
| R29-05 | 4 cycles x 2 modes x 10 min exceeds session budget | Per-cycle leg cap is 10 min; total execution budget is 80 min (Manager may approve 40 min) | Driver tracks elapsed time per phase and exits early if total exceeds 90 min (10-min buffer) |
| R29-06 | Stage 29 scope creep into product code | This plan explicitly excludes product code changes; part-01 step actions only author the driver and lib helpers | Entry doc lists exclusions; part-01 lists no production file modifications |
| R29-07 | Port collision between proxy capture (optional) and main legs | S29-IMPL-03 preflight port check; optional proxy uses port 8910 if enabled (default OFF) | Driver checks port 8900 and 8910 are free at preflight |
| R29-08 | Metric format regression (underscore form reappears) | S29-IMPL-08 metrics-format grep on each metrics-after.txt; FAIL-metric-format-regression on any match | Driver runs the grep per leg; report records the grep result |
| R29-09 | Hot cache state contamination between cycles | S29-IMPL-06 wipes cold dir and resets hot budget between cycles by default | Driver records hot-budget reset in summary.json per cycle |
| R29-10 | Qwen3.5-4B-MTP fixture cannot load under --parallel 2 | S29-IMPL-03 preflight fixture check; BLOCKED-host-capacity on load failure | Driver records parallel and ctx_size in summary.json per leg |
| R29-11 | Cold-path write fails during a hybrid leg | S29-IMPL-08 wraps cold-write calls in try/catch and logs exceptions; FAIL-cold-write on unhandled failure | Driver wraps cold-write calls in try/catch; report classifies as FAIL-cold-write if no bounded handling |
| R29-12 | Driver invocation does not match the lib API (rework list B-01..B-05) | S29-IMPL-01 wrapper smoke test verifies the actual New-ComparisonWorkload signature; S29-IMPL-02 driver skeleton dot-sources the wrapper | Corrected invocation verified against the actual lib by the implementation plan before code is written |

## Implementation-specific risks (R29-IMPL-01..02)

The Stage 29 implementation brief names two implementation-specific
risks that the design did not enumerate.

### R29-IMPL-01: PowerShell version on the runner

Trigger: the runner has PowerShell < 5 installed and the wrapper
script (`#requires -Version 5` directive at L1) refuses to load.

Impact: Step 01 smoke test fails; the driver cannot run on the
runner; the comparison cannot start.

Mitigation: S29-IMPL-01 first sub-check is
`$PSVersionTable.PSVersion.Major -ge 5`. If the check fails, the
smoke test classifies as `BLOCKED-powershell-version` with a clear
FAIL message naming the required version. The driver surfaces the
same check at the start of Phase 0 preflight so the QA execution
gate catches the same condition before booting the server.

### R29-IMPL-02: VRAM cooldown may need longer on heavily loaded hosts

Trigger: the runner is heavily loaded (other GPU workloads
concurrent) and the 120-second cooldown cap (per design part-03
line 107) is too short. VRAM does not return to baseline within 120s
and the run is classified as `BLOCKED-vram-release` even though
the runner is functional.

Impact: false BLOCKED classification; the runner is functional but
the cooldown cap is too short; the QA execution gate has to
re-run with a longer cap.

Mitigation: the implementation session extends the cooldown polling
timeout from 120 seconds to 180 seconds in S29-IMPL-07
(implementation-specific, justified per R29-IMPL-02). The
cooldown_duration_seconds field in summary.json records the actual
cooldown duration per leg so the QA execution gate can see whether
the cap was reached. Manager can later authorize a longer cap if
180 seconds is still too short on a particular host.

## Re-reviewer INFO observation resolutions (C-01..C-03)

The Architect re-review
([part-13](../cache-handling-phase29-design/part-13-design-re-review-20260628.md))
section 9 lists three INFO observations. The implementation plan
resolves each in the part-01 step that operationalizes the
resolution.

### C-01: wrapper enforces cumulative distribution via nextDouble() only

The wrapper applies the 40/30/30 distribution per request using
`$rng.NextDouble()` (wrapper L121-124). With 200 requests the
expected counts are 80/60/60. Empirical deviation depends on the
seed.

Resolution: S29-IMPL-04 records the empirical cache_class counts
in workload.jsonl. S29-IMPL-08 records the per-cycle cache_class
counts in summary.json. The QA execution gate inspects the
empirical distribution and reports any unexpected skew in
Layer 2 per-cache-class columns. Tolerance: +/- 5 of the 80/60/60
expected split per cycle (typical $rng.NextDouble() distribution).

### C-02: Stage 20 lib TimeoutSec default is 30s, wrapper passes through

The Stage 20 lib `New-AgenticChatPrompt` default for `TimeoutSec`
is 30 seconds (lib L96). The wrapper accepts
`-TokenizeTimeoutSec` (default 60, L65) and passes it to
`-TimeoutSec` on `New-AgenticChatPrompt` (wrapper L113, L149).

Resolution: the driver calls `New-ComparisonWorkload` with
`TokenizeTimeoutSec = 60` (the wrapper's default; double the
Stage 20 lib default) in S29-IMPL-04. The 60-second timeout is
sufficient for a single 12k-tokenize call under normal load.
The driver records the actual tokenize duration in
phase-0-5-workload-build.log; the QA execution gate can extend
the timeout if any single call exceeds 30 seconds.

### C-03: summary.json per-cycle cache-class counts not in design

The part-02 workload shape document does not mandate that the
driver record the empirical cache_class counts per cycle.

Resolution: S29-IMPL-08 adds a `cache_class_counts` field to
`summary.json` (one entry per cycle, one count per cache_class).
The QA report Layer 2 surfaces any distribution drift across
cycles. The implementation session records the cache_class
counts at the end of each leg, before the cooldown.

## Open questions for Manager attention (OQ-29-01)

One open question is forwarded to Manager for resolution before
the QA execution gate opens.

### OQ-29-01: optional one-shot proxy capture approval

The design part-02 allows an optional one-shot logging HTTP proxy
capture as supplementary ground truth, but only if Manager
approves. The proxy captures real agentic traffic for one run
against `--cache-mode legacy` and the resulting JSONL is replayed
against both modes.

Options:

(a) DEFER. The synthetic-but-representative workload is
sufficient; the optional proxy is deferred to a future stage
that combines proxy capture plus synthetic (per part-09 deferred
risks).

(b) APPROVE for one Manager-approved run. The QA session adds
`workload-classify.ps1` to the driver invocation, runs the proxy
once, captures the JSONL, and replays it against both modes. The
proxy is NOT run inside the main A/B loop.

(c) REJECT. The optional proxy is out of scope for Stage 29.

The implementation session does NOT exercise the optional proxy
path in S29-IMPL-02..10. The `workload-classify.ps1` helper is
authored (per part-08 new-artefacts table) so the path is
available, but the driver does not invoke the proxy without
Manager approval.

Manager resolves OQ-29-01 at the implementation-plan gate or the
execution gate.

## Risk summary

The 12 design risks plus 2 implementation-specific risks plus 3
re-review INFO resolutions plus 1 OQ for Manager are all
operationalized in part-01 step actions. No risk is left as a
guideline; each risk has a concrete step that detects, mitigates,
or reports the risk condition.

The implementation session does not start a step whose preconditions
include risk mitigations until those mitigations are in place. The
QA execution gate consumes the per-step evidence and the
summary.json fields to verify that the risk mitigations held for
the actual run.
