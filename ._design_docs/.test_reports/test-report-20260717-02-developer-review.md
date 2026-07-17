# Stage 39 Developer results review 20260717-02

Status: REWORK REQUIRED
Reviewed report: `test-report-20260717-02.md`

## Verdict

TP-39-03 is blocked by the canonical PowerShell driver's startup configuration,
not by product retention behavior or the GGUF fixture. The driver omits the
binding `--spec-type draft-mtp` selector. Coverage is deliberately unrun under
Manager Part 149's fail-fast rule. No product invariant reached evaluation.

## Exact failed conjunct

`Get-Tp3903PreparedBindingsS39` passed proof shape, ordered
`exact_blob,checkpoint` kinds, source payload, same owner, distinct IDs, and
equal pair state before line 129 threw. Product proof rejects non-hot rows,
runtime pair mismatch, zero target bytes, resident-sum mismatch, or bad hot
records before returning a response. The remaining failed component predicates
are therefore exact: both rows had `runtime_has_draft=false` and
`draft_size_bytes=0`. Their target component and resident sums were valid.

The discovery row's `pair_state="target_only"` and both `tx_save` records'
`dft: 0.000` independently confirm this result. Six target-context checkpoints
do not prove an MTP draft context. The launch arguments contain checkpoint
options but no `--spec-type`. Design Part 46 already records that
`common_params_speculative::types` defaults to none and that only
`--spec-type draft-mtp` creates the no-separate-model MTP draft context.

## Product proof and fixture assessment

The runtime did create the Part 43 checkpoint payload descriptor. The linked
proof expanded the discovered exact ID to two ordered exact/checkpoint rows;
otherwise the driver would have thrown `proof-binding` before `proof-component`.
It created a target-only checkpoint descriptor, not the required
target-and-draft descriptor.

Proof requests use the current contract: snapshot generation, snapshot token,
and literal `payload_ids`; the bootstrap sends the exact ID and the binding
request sends both returned IDs. Product proof fields and driver validation are
also correct for Part 43: kind, owner, pair state, runtime draft presence,
component sizes, checksums, residency, and resident totals. The fault is the
driver launch configuration. The driver has a separate diagnostics gap because
it validates before preserving redacted linked and explicit proof requests and
responses.

## Classification and ownership

| Finding | Classification | Owner | Correction and evidence |
| --- | --- | --- | --- |
| TP-39-03 preflight | QA driver/workload configuration blocker | Developer | Add exactly one adjacent `--spec-type`, `draft-mtp` pair to canonical both-filled argv. Add preflight/self-test proof of that final argv and positive draft save/proof components. Preserve all fixture, caps, schema, and product code. |
| Missing raw proof | QA driver diagnostics gap | Developer | Save redacted bootstrap and explicit proof requests/responses before validation. Add a pure failing-component test that proves artifacts survive the throw. |
| Coverage | Acceptable fail-fast deferral | QA after Manager gate | No coverage correction. Run only after canonical TP-39-03 passes. |

## Retest

After Developer correction, fresh Architect review, and Manager authorization:

1. Run PowerShell 7 and Windows PowerShell 5 parser/self-tests. Require exact
   argv selection and preserved proof artifacts on a deliberate component fail.
2. Run one fresh bounded canonical TP-39-03 node. Require positive `dft`, two
   target-and-draft proof rows, `Assert-Tp3903` PASS, exact retained cold,
   checkpoint eviction, retained topology, zero pruning, and reconciled bytes.
3. Only then run Part 149's four fresh coverage blocks. Require both success
   reports at or above 80 percent and both delegated exit-23 negative results.

No fix, test, model, build, or coverage command ran in this review.
