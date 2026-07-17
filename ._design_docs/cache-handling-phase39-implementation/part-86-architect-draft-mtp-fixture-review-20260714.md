# Part 86: Architect draft-MTP fixture review

Date: 2026-07-14
Verdict: REWORK, NARROW CORRECTION READY
Scope: D39-EXEC-19 implementation and Part 85 evidence

## Review result

D39-EXEC-19 did not reach implementation acceptance. The helper correctly
implemented the exact Part 45 command, isolation, request, caps, artifacts, and
fail-closed behavior, but that approved command cannot create the required MTP
draft payload. Design Part 46 supplies the complete correction.

## Evidence

`common/arg.cpp` registers the exact spelling `--spec-type` and maps
`draft-mtp` to `COMMON_SPECULATIVE_TYPE_DRAFT_MTP`. The speculative type list
defaults to `COMMON_SPECULATIVE_TYPE_NONE`. `server-context.cpp` checks for the
MTP enum before creating the target model's MTP context. No separate draft model
or coupled runtime option is required for this NextN fixture.

Both Part 85 commands omit the option. Their roots record the expected model
metadata, identical 5,687-byte request and SHA-256, HTTP 200, three checkpoints,
empty cold roots, and bounded resources. Both stop at
`BLOCKED-route-fixture-capability`; no apply artifact exists. Logs contain
target checkpoint creation and `dft: 0.000`, but not MTP context creation,
bounded partial sequence removal, or `draft-mtp`.

## Required correction

Under a new Manager gate:

1. add exactly `--spec-type draft-mtp` to `Stage39MTPServer`;
2. assert the exact argv pair before admission;
3. retain current startup checks and require positive draft bytes in the source
   save and both proof rows;
4. retain every Part 45 flag, cap, isolation rule, fail-closed result, and fault
   assertion;
5. rerun only the two named nodes, sequentially, with fresh roots.

No product code, build, other flag, fallback, canonical run, coverage, or QA is
authorized. Acceptance is `2 passed, 0 failed, 0 skipped` within the existing
per-node caps.

## Gate

Part 46 is a safe, helper-only correction to an omitted selector, not a runtime
policy change. Architect review: PASS for Part 46; REWORK for current
D39-EXEC-19 evidence. Next owner: Manager for a new correction and rerun gate.
