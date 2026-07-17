# Part 18: TP-39-14 fault matrix

Date: 2026-07-12
Status: IMPLEMENTATION READY

## Change

The cold transaction test interface now exposes a one-shot descriptor-apply
fault. The controller checks it after the commit marker and ownership journal
are durable but before changing in-memory descriptors. A simulated crash at
that boundary therefore leaves durable committed state for startup replay.

`test_stage39_multi_victim_fault_position_matrix` builds three cold victims,
forces all three into one room-making transaction, and injects failures at:

- each of three victim quarantine positions;
- incoming publish and commit marker;
- descriptor apply;
- each of three victim unlink positions;
- manifest unlink.

Each row destroys the active controller and constructs two fresh controllers.
Pre-commit rows recover exactly three victim descriptors and their byte total.
Post-commit rows recover exactly one incoming descriptor and its byte total.
No replay exposes a partial victim set. Cleanup faults still return the one
successful final demotion decision; descriptor-apply crash injection records
the bounded transaction recovery/apply tuple.

## Verification

- Release `test-cache-controller` build: PASS.
- Release `llama-server` build: PASS.
- Release `test-cache-controller.exe`: PASS.
- `ctest --test-dir build -C Release -R cache-controller`: PASS, 1/1.
- Stage 39 PowerShell driver parser: PASS.
- Existing C4477 warnings remain outside Stage 39 changes.

## Gate

No Stage 39 product or implementation-automation gap remains. QA still owns
changed-line coverage and live model-backed execution before closure.
