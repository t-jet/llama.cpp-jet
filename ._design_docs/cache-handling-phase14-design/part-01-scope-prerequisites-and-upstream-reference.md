# Stage 14 design: scope, prerequisites, and upstream reference -- Part 1

Source: [../cache-handling-phase14-design.md](../cache-handling-phase14-design.md)

## Goal

Stage 14 is the second upstream merge cycle. It re-syncs the fork with
`upstream_master` after Stage 12 stress validation and Stage 13 endpoint
compatibility corrections are merged, and reworks prior stages when
the upstream changes invalidate them. The design records the upstream
reference strategy, the prior-stage contracts the merge must preserve,
and the prerequisites the merge assumes.

## Scope carried forward from the architecture

The architecture defines Stage 14 as post-Stage-12/13 upstream
integration. The scope is fixed by the architecture and is not
redefined in this design. The design treats the architecture scope as
the baseline and writes the operational contract that lets the merge
and rework proceed.

Architecture deliverables the design must support:

- Pre-merge analysis of upstream commits since the Stage 11 merge
  that touch cache, checkpoint, speculative decoding, server context,
  slot, HTTP layer, endpoint adapters, hybrid diagnostics, MTMD
  placeholder path, and CUDA kernels
- Real two-parent merge with the local default branch as the
  integration branch and a current `origin/upstream_master`
  remote-tracking ref verified against the actual upstream `master`
- Per-commit triage table (NO-OP, INTEGRATE, DEFER, REWORK-REQUIRED)
  with the file-glob filter
- Conflict resolution per the local-first-for-hybrid /
  upstream-first-for-legacy policy from upstream-merge-guide Part 2
- Rework assessment mapping upstream changes to affected Stages 1-13,
  including the new Stage 12 stress harness and Stage 13 endpoint
  adapter regressions
- Regression test reruns for any behavior the upstream change
  touches, including public endpoint parity rows E13-01 through
  E13-16
- Coverage, evidence, and citation rules per upstream-merge-guide
  Part 3
- Edge case and post-closure follow-up handling per
  upstream-merge-guide Part 4
- Merge log: decisions, deferred upstream commits, known gaps, and
  rework cross-references
- Implementation log pointing to upstream-merge-guide for procedure
  and to affected stage designs for prior-stage contract list

Architecture exit criteria the design must support:

- Merge complete with no unresolved conflicts and recorded merge log
- All prior-stage tests pass on the merged tree (Stages 1-13)
- Hybrid mode invariants from earlier stages hold, including
  diagnostic-source namespace isolation (Stage 13) and bounded
  metadata diagnostic at task launch (Stage 13)
- Upstream cache, endpoint, MTMD, CUDA, and speculative-decoding
  changes are integrated or recorded as known gaps with a
  follow-up plan
- Legacy mode behavior is unchanged
- Public endpoint parity rows E13-01 through E13-16 continue to
  PASS on the merged tree
- Coverage closure contracts (T114, T114a) re-verified per
  upstream-merge-guide Part 3
- Manager approval of the merge cycle recorded in the implementation
  log

## Prior-stage contracts the merge must preserve

The merge and any rework must keep these contracts from the closed
stages intact. Each contract names the architecture or stage design
that owns it. Stage 12 and Stage 13 rows carry the new post-Stage-11
contracts the second merge cycle must preserve.

| Contract | Owner | What the merge must preserve |
| --- | --- | --- |
| Hybrid mode opt-in CLI flag | Architecture, Stage 1 | `--cache-mode hybrid` remains explicit and opt-in. No silent default change. |
| Legacy default path unchanged | Architecture, Stage 1 | When `--cache-mode` is not `hybrid` or the flag is absent, the legacy cache path behaves exactly as before the merge. |
| Hybrid mode gate isolation | Stage 1 | Mode dispatch in `server_context` keeps hybrid and legacy controllers separated. |
| Compatibility namespace key | Stage 2, Stage 5, Stage 7, Stage 9, Stage 13 | The namespace key continues to include target model identity, draft model identity or absence, tokenizer-compatible prompt semantics, workload profile, and material runtime modifiers. The diagnostic endpoint source label must not enter the namespace-affecting preparation identity. |
| Draft runtime mode identity | Stage 5 | The richer mode identity for separate draft model, MTP on target, and MTP on a separate draft model stays distinct in the namespace and in the runtime shape observed by the cache. |
| Target and draft pairing | Stage 5 | All save, restore, offload, eviction, and cold-layer operations preserve target and draft coupling. A branch with both payloads must not allow only one side to be restored, evicted, or demoted independently. |
| Prepared-prompt boundary metadata | Stage 2, Stage 13, ADR-004 | Boundaries captured at prompt preparation continue to flow into `server_task` and reach `server_context`. When the route cannot derive rich boundaries, the bounded token/position fallback is used and a bounded degraded diagnostic is emitted. |
| Hot and cold residency for full-state blobs and checkpoint payloads | Stage 4, Stage 6, Stage 9 | Hot and cold residency, eviction, and promotion rules apply to both payload kinds. |
| Byte-accounted LRU with protected roots | Stage 4 | Resident-byte accounting and protected-root priority remain in force. |
| Payload descriptor separation and validation | Stage 5 | Descriptors carry id, kind, pair state, version, size, checksum, store reference, and residency state. Pre-restore validation remains mandatory. |
| Atomic target and draft restore | Stage 5 | The transactional restore contract from Stage 5 remains in force. A partial paired restore is a blocking defect. |
| Cold store integrity and root containment | Stage 6, Stage 10 | Versioned descriptors, checksums, atomic write/rename, staging files, normalized root, and root-containment checks remain in force. |
| Branch forest, namespace validation, slot references | Stage 7 | The shared forest, namespace validation before restore, slot references without ownership transfer, and global LRU eviction remain in force. |
| Metadata-only nodes and re-materialization | Stage 8 | Re-materialization from the nearest retained payload-bearing ancestor, validation mismatch handling, and mismatch-parent selection with deterministic tie-breaking remain in force. |
| Equivalent-branch deduplication | Stage 8 | Convergence on the same validated prompt path joins the existing node rather than creating a duplicate. |
| Cold cleanup ownership | Stage 8 | Pruning verifies that no retained branch or descendant owns the descriptor before cold deletion. |
| Checkpoint payloads as first-class branch nodes | Stage 9 | Checkpoint payloads move, restore, evict, and demote as first-class branch node references. |
| Workload profile detection and restore strategy | Stage 9 | Plain-transformer, checkpoint-dependent, and target-plus-draft profile detection and the restore strategy order remain in force. |
| Prepared-prompt boundary checkpoint placement | Stage 9 | Checkpoint placement at prepared-prompt boundaries when metadata is available remains in force. |
| Public Prometheus metric set and label shape | Stage 10, ADR-008 | The R61-R68 metric set, the bounded labels, the absence of sensitive material in labels, and the S10-IMPL-01 corrected metric shape remain in force. |
| Bounded diagnostics for failure and fallback paths | Stage 10, Stage 13 | Structured diagnostics for unsupported configuration, marker validation, namespace or pair rejection, cold-store failure, and restore failure remain in force. The bounded `cache metadata:` line at task launch carries `{source, method, degraded, tokens, boundaries}` and is emitted only as a diagnostic, never as a namespace-affecting input. |
| OWASP review mitigations | Stage 10 | Cold-store path normalization, root containment, marker sanitization, descriptor integrity, paired atomicity, and monitoring mitigations remain in force. |
| Deterministic test seams | Stage 10 | Injected clocks, fake stores, deterministic graph lookup, and worker completion order remain in force. |
| 80% hybrid path coverage floor (T114) | Stage 10, test plan Part 12 | The combined-rate 80% floor on the hybrid-mode denominator remains a closure contract. |
| 70% product-only hybrid path coverage floor (T114a) | Test plan Part 13, Stage 11 onward | The product-only rate 70% floor on the 11 product files named in the Architect review remains a closure contract. |
| Per-file aggregation rule (T115) | Test plan Part 12, Part 13 | The `coverage-report.md` per-file table lists each hybrid-mode file exactly once, with deduplication by lowercased full path. |
| Checkpoint admission public /metrics row (T121) | Stage 10 implementation Part 9, test plan Part 12 | The four `cache_checkpoint_*` rows must remain exposed through the public /metrics endpoint when a hybrid-mode server with MTP or checkpoint-capable draft is exercised. |
| Stage 5 speculative-mode namespace isolation | Architecture Part 6 | Target-only, separate draft, MTP-on-target, and MTP-on-separate-draft descriptors must not reuse each other's entries. |
| Stage 7 multi-namespace concurrent operation with shared budgets | Architecture Part 2 | The shared hot-payload, branch-metadata, and cold-layer budget pool remains global across namespaces, with no per-namespace quota. |
| Stage 12 stress harness outputs S01..S08 and L01..L03 | Stage 12 design Part 2 | The stress scenarios S12-S01 through S12-S08 and the long-run checks S12-L01 through S12-L03 remain authoritative production-scale evidence; the merge does not weaken or delete any of them. |
| Stage 12 benchmark outputs B01..B08 | Stage 12 design Part 3 | The benchmark scenarios S12-B01 through S12-B08 remain authoritative production-scale performance evidence; the merge does not weaken or delete any of them. |
| Stage 12 configuration matrix | Stage 12 design Part 2 | The configuration matrix dimensions (cache mode, hot budget, cold path, slot count, model size, context length, draft presence, workload profile, prompt mix, run length) remain in scope for the cycle's stress and benchmark evidence. |
| Stage 12 public Prometheus metric shape | Stage 12 design Part 4, Stage 10 | The stress and benchmark evidence continues to cite the public Prometheus metric set and label shape, not internal controller stats. |
| Stage 13 endpoint parity rows E13-01..E13-16 | Stage 13 design Part 3, implementation | The public endpoint parity rows E13-01 through E13-16 continue to PASS on the merged tree; the cycle's regression rerun includes these rows. |
| Stage 13 MTMD placeholder path | Stage 13 implementation | The MTMD placeholder path remains in force across the merge; an upstream change that would remove or rename it is a rework candidate. |
| Stage 13 diagnostic-source namespace isolation | Stage 13 design Part 2, bug-fix review | The endpoint source label used in bounded diagnostic emission does not enter the namespace-affecting `preparation_id` or any other namespace key component. |
| Stage 13 bounded `cache metadata:` format at task launch | Stage 13 bug-fix loop, test report 20260610-04 | The bounded diagnostic at task launch uses the format `{source, method, degraded, tokens, boundaries}` and is emitted on the native `/completion` and OpenAI-compatible `/v1/chat/completions` degraded paths; the format and emission sites are stable across the merge. |
| Stage 13 transcript route coverage | Stage 13 implementation plan rework 2026-06-09 | Transcription routes remain in the Stage 13 route inventory; the merge does not drop transcription route coverage from the cycle's regression rerun. |
| Stage 13 embedding cache exclusion rationale | Stage 13 implementation Part 2, Part 3 | Embedding routes are excluded from hybrid cache prompt state by design; the rationale (no prompt-state reuse benefit, route shapes) is recorded and is not silently reversed by the merge. |

The merge may extend the contracts listed above, but it must not
weaken, rename, or remove any of them. Any contract that an upstream
change would weaken is a rework candidate and not a silent
integration.

The `test-stage10-policy-lru` pre-existing semantic bug is NOT a
Stage 14 contract. It is tracked separately. The merge does not
require its fix and does not let the fix gate the cycle.

## Upstream reference strategy

The upstream reference is the remote-tracking ref
`origin/upstream_master`. Per Manager decision D1 (2026-06-04,
revised 2026-06-11), the Developer operates against
`origin/upstream_master` directly, the remote ref was last fetched
2026-06-04 per the original D1 record, and no separate `upstream`
remote is required. The Developer verifies the remote ref tip is
current against the actual upstream `master` via
`git ls-remote https://github.com/ggml-org/llama.cpp.git master`
(or the GitHub REST API endpoint) before the merge opens. A stale
`origin/upstream_master` ref is a known gap recorded in the merge
log "Decisions" section, not a blocker that halts the cycle. The
local-tracking-branch alternative documented in
upstream-merge-guide.md remains available for future cycles if a
later Manager decision revises this one.

| Reference item | Design assumption | Concrete value source |
| --- | --- | --- |
| Upstream remote name | `origin` | Implementation plan |
| Upstream tracking ref | `origin/upstream_master` (remote-tracking ref, used directly) | Implementation plan |
| Local integration branch | The local default branch | Implementation plan |
| Fetch policy | `git fetch origin` followed by re-verification of `origin/upstream_master` tip | Implementation plan |
| Commit range rule | All upstream commits reachable from `origin/upstream_master` tip but not from the local fork point | Implementation plan |
| Excluded upstream refs | Upstream feature branches and PR refs are not part of the merge unless an Architect review marks them as required | Implementation plan |
| Tag handling | Tags are fetched for traceability but are not part of the merge range unless the Developer records a reason in the merge log | Implementation plan |
| Last-known fetch date | 2026-06-04 (per original D1 record) | Implementation plan must re-verify currency |

The Developer is responsible for confirming the `origin` remote URL,
the `origin/upstream_master` ref tip, the local fork point, and the
existence of the upstream ref at the time the merge is opened. A
change to the upstream ref or to the local fork point is recorded in
the merge log, not silently absorbed.

## Host tooling and credential assumptions

The merge assumes the following on the host where the merge is run:

- Git is available on `PATH` and supports the merge command family
  the Developer will execute
- The local clone has the `origin` remote configured with read
  access for `upstream_master`
- The local clone has the local default branch checked out at a
  clean tree before the merge begins
- The fork's local credentials allow push to the local default
  branch after the merge resolves cleanly
- The host can run the local build, the regression ctest command
  family, the focused exporter coverage script, the Stage 12 stress
  harness, the Stage 12 benchmark harness, the Stage 13 endpoint
  probe, and the public HTTP /metrics probe used by the prior
  stages
- The host has access to the local model fixture inventory
  required for stress, benchmark, and endpoint execution

A missing or misconfigured remote, credential, build prerequisite,
fixture, or harness is a blocker for the merge and must be reported
in the merge log. It is not silently skipped or worked around with
an unrecorded alternative.

## Boundary with the prior stage designs

Stage 14 is not a replacement for any prior stage design. The prior
stage designs remain the source of truth for behavior, contract, and
traceability within their own stage. Stage 14 only adds the
operational layer that audits, integrates, and reworks prior stages
against upstream changes.

When an upstream change would invalidate a prior stage contract,
the Architect opens a rework of that stage. The rework follows the
standard stage workflow (Design, Implementation, Test, Closure) but
starts from the current state of that stage's docs and code, not
from scratch. The rework records its own evidence, its own review,
and its own closure decision in the implementation log of the stage
being reworked, not in the Stage 14 implementation log.
