# Stage 10 implementation evidence - 2026-06-02

Source: [../cache-handling-phase10-implementation.md](../cache-handling-phase10-implementation.md)

## Status

Implementation state: PARTIAL PASS for the first Stage 10 implementation pass.
QA execution state: not opened.
Commit state: not committed.

## Completed scope

This pass implemented two Stage 10 hardening items and added durable operator
documentation.

- Prometheus cache metric labels now escape backslash, quote, newline, and
  carriage-return characters before writing label values through the shared
  `/metrics` exporter.
- Cold-store root configuration now stores a canonical absolute root, rejects
  root-directory use, rejects root paths with unsafe control characters, and
  validates every derived payload and staging path against the configured root.
- Cold-store diagnostics no longer print arbitrary configured root paths or
  derived payload file paths. They keep payload IDs, refs, failure reasons, and a
  short root label for operator triage.
- A focused cold-store hardening test target covers the allowed case where the
  root directory name contains `..` as literal characters. The old substring
  check rejected this safe case during write/read/remove.
- Durable operator notes were added for hybrid cache flags, budgets, cold-store
  setup, workload profiles, restore behavior, metrics, diagnostics, benchmark
  evidence classes, and security limits.

## Changed files

Code:

- `tools/server/server-cache-store-cold.h`
- `tools/server/server-cache-store-cold.cpp`
- `tools/server/server-context.cpp`
- `tests/CMakeLists.txt`
- `tests/test-stage10-cold-store-hardening.cpp`

Documentation:

- `tools/server/hybrid-cache.md`
- `tools/server/README-dev.md`
- `tools/server/bench/README.md`
- `tools/server/tests/README.md`
- `._design_docs/cache-handling-phase10-implementation.md`
- `._design_docs/cache-handling-phase10-implementation/part-06-implementation-evidence-20260602.md`
- `._design_docs/cache-handling-phase10-design.md`
- `._design_docs/document-index.md`

## R107 minimal-intrusion notes

Touched shared or legacy-adjacent paths:

- `tools/server/server-context.cpp`: required because the existing `/metrics`
  route is the public exporter for both legacy and hybrid cache stats. The edit
  is limited to escaping label values used by cache metrics; it does not change
  legacy cache policy or request handling.
- `tests/CMakeLists.txt`: required to register the focused Stage 10 hardening
  target. No runtime behavior changes.

No legacy cache controller file was changed.

## Security review record

Focused OWASP status for implemented surfaces:

| Category | Status | Notes |
| --- | --- | --- |
| A01 Broken access control | Mitigated for touched cold-store paths | File operations are constrained to the configured cold root. Request markers were not enabled in this pass. |
| A03 Injection | Mitigated for touched metrics and cold-store diagnostics | Prometheus label values are escaped. Cold-store logs avoid arbitrary paths. |
| A04 Insecure design | Mitigated for touched cold-store paths | Invalid paths fail before file operations. Restore still falls back through existing descriptor and transactional checks. |
| A05 Security misconfiguration | Mitigated for touched root validation | Empty, missing, non-directory, root-directory, unwritable, and control-character roots fail at configuration. POSIX world-writable roots still warn. |
| A08 Software and data integrity failures | Mitigated by existing validation, unchanged | Cold files still validate magic, format, payload ID, pair state, sizes, and checksums. |
| A09 Security logging and monitoring failures | Partially mitigated | Path and metric injection surfaces are covered. Broader structured diagnostic enum coverage remains open. |

No unmitigated item from this pass is known to affect correctness,
confidentiality, or operator control.

## Evidence

Configure:

- `cmake -S . -B build`
- Result: PASS. Existing warning: OpenSSL not found, HTTPS support disabled.

Build:

- `cmake --build build --config Release --target llama-server test-step10-metrics test-stage10-cold-store-hardening`
- Result: PASS.
- `cmake --build build --config Release --target test-step2-cold-store test-step3-4-cold-store-write-read test-cache-controller`
- Result: PASS.

Focused tests:

- `ctest --test-dir build -C Release -R "test-(step10-metrics|stage10-cold-store-hardening)" --output-on-failure`
- Result: PASS, 2/2 tests.
- `ctest --test-dir build -C Release -R "test-(step2-cold-store|step3-4-cold-store-write-read|cache-controller|step10-metrics|stage10-cold-store-hardening)" --output-on-failure`
- Result: PASS, 5/5 tests.

## Coverage and benchmark status

Coverage was not run in this implementation pass. The approved Stage 10 primary
coverage plan remains Clang/LLVM source coverage with branch totals when the
installed LLVM toolset supports them. No GCOV/LCOV/gcovr fallback was used.

Benchmarks were not run in this implementation pass. The benchmark evidence
classification remains the approved Part 2 matrix: public Prometheus,
structured log, direct stats, and harness-only evidence.

## Open implementation items

Still open for later Stage 10 work:

- Complete the R61-R68 metric and diagnostic audit beyond the two touched
  surfaces.
- Add broader structured diagnostic enums for unsupported configuration,
  descriptor rejection, fallback, integrity failure, branch pruning,
  metadata-only retention, promotion, demotion, and cleanup.
- Add startup validation tests for impossible budgets and unsupported runtime
  shapes.
- Add pressure and abuse tests for repeated invalid markers if a marker surface
  is enabled, tiny budgets, branch metadata pressure, large forests, queue
  pressure, shutdown with pending work, and repeated integrity failures.
- Collect LLVM coverage evidence for the approved hybrid-path denominator.
- Run benchmark evidence after correctness coverage is ready.
