# Stage 39 Developer QA3 corrections

Date: 2026-07-12
Status: READY FOR ARCHITECT REVIEW

## Changes

F39-QA3-01 is fixed at the shared exporter boundary. The public exporter keeps
its implicit `mode` label and emits only `result` and `reason` from each bounded
Stage 39 row. The internal tuple still includes `mode`. A focused rendered-text
test covers decision and transaction families, proves expected rows, and counts
one `mode` label per sample. The live driver now rejects duplicate label names.

F39-QA3-02 is fixed in `test-step10-metrics.cpp`. The gauge assertion reads the
committed cold file size and checks it equals `sizeof(cold_store_header) + 125`
before comparing the gauge. Count, descriptor, and demotion assertions remain.

## Evidence

- Release build `test-step10-metrics`: PASS.
- Direct `test-step10-metrics.exe`: PASS, including Stage 39 exporter regression.
- Release build and direct `test-cache-controller.exe`: PASS.
- Release build and direct `test-chat-peg-parser.exe`: PASS.

## Open work

TP-39-02 through TP-39-04 are not closed. The public live driver cannot prove
equal-rank victim tuples, make every cold resident ineligible, or bind measured
pair bytes to the exact production-pressure candidate. QA must calibrate a
model-backed workload or request a reviewed diagnostic seam. Metric-family
presence is not proof.

Coverage is also open. No `.cov` artifact or percentage was manufactured. QA or
the environment owner must repair OpenCppCoverage, prove one readable smoke
artifact, then run the fail-closed coverage set at the required 80% threshold.
