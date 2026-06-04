# Hybrid-mode coverage report

Denominator: hybrid cache implementation files and 8 focused test files.
Excluded: server-context.cpp, server-context.h (general dispatcher).
Tool: OpenCppCoverage, Cobertura XML line-rate.
Branch-rate: not available (OpenCppCoverage does not produce branch coverage).
LLVM fallback blocked: lld-link rejects -fprofile-instr-generate as a linker flag on this MSVC host.

| File | Line rate | Covered | Valid |
| --- | --- | --- | --- |
| server-cache-controller.cpp | 0.8333 | 5 | 6 |
| server-cache-controller.h | 0.4 | 2 | 5 |
| server-cache-graph.cpp | 0.8719 | 463 | 531 |
| server-cache-graph.h | 0.95 | 19 | 20 |
| server-cache-hybrid.cpp | 0.6197 | 1144 | 1846 |
| server-cache-hybrid.h | 0.5929 | 83 | 140 |
| server-cache-io-worker.cpp | 0.8442 | 130 | 154 |
| server-cache-legacy.h | 0 | 0 | 1 |
| server-cache-policy-lru.cpp | 0.7037 | 19 | 27 |
| server-cache-store-cold.cpp | 0.8688 | 192 | 221 |
| server-cache-store-cold.h | 0.7407 | 20 | 27 |
| test-cache-controller.cpp | 0.9791 | 1029 | 1051 |
| test-stage10-cold-store-hardening.cpp | 0.9923 | 388 | 391 |
| test-step10-metrics.cpp | 1 | 226 | 226 |
| test-step11-test-hooks-fault-injection.cpp | 0.9967 | 300 | 301 |
| test-step12-branch-graph.cpp | 0.9557 | 151 | 158 |
| test-step13-stage8.cpp | 1 | 503 | 503 |
| test-step6-demotion-protocol.cpp | 0.9903 | 305 | 308 |
| test-step7-promotion-protocol.cpp | 0.9922 | 380 | 383 |

## Combined result

- Combined line rate: 0.8508
- Combined covered: 5359 / 6299
- 80% threshold: PASS

## Product-only result

- Product-only line rate: 0.6974
- Product-only covered: 2077 / 2978
- 70% threshold: FAIL
