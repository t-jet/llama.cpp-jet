# Coverage summary

Denominator: hybrid sources and the 8 focused test files.
Source: OpenCppCoverage Cobertura XML, line-rate (branch-rate is 0 because OpenCppCoverage does not produce branch coverage).
Fallback reason: line coverage is used because LLVM source-based coverage on the MSVC build requires clang-cl + clang_rt.profile, which fails to link cleanly due to MSVC ABI and template instantiation differences on this host (see log entries cov-configure.log and cov-build.log). GCOV-style fallback via OpenCppCoverage was used instead.

## test-cache-controller

- Aggregate line rate: 0.204850031908105
- Lines covered: 0 / 0

| File | Line rate | Covered | Valid |
| --- | --- | --- | --- |
| test-cache-controller.cpp | 0.9874 | 783 | 793 |
| server-cache-controller.cpp | 0.8333 | 5 | 6 |
| server-cache-controller.h | 0 | 0 | 5 |
| server-cache-graph.cpp | 0.3202 | 170 | 531 |
| server-cache-graph.h | 0.95 | 19 | 20 |
| server-cache-hybrid.cpp | 0.3575 | 660 | 1846 |
| server-cache-hybrid.h | 0.629 | 78 | 124 |
| server-cache-io-worker.cpp | 0.2403 | 37 | 154 |
| server-cache-legacy.h | 0 | 0 | 1 |
| server-cache-policy-lru.cpp | 0.7037 | 19 | 27 |
| server-cache-store-cold.cpp | 0.133 | 29 | 218 |
| server-cache-store-cold.h | 0 | 0 | 20 |
| server-context.cpp | 0.0041 | 13 | 3138 |

## test-step10-metrics

- Aggregate line rate: 0.127204460120605
- Lines covered: 0 / 0

| File | Line rate | Covered | Valid |
| --- | --- | --- | --- |
| test-step10-metrics.cpp | 1 | 206 | 206 |
| server-cache-controller.cpp | 0 | 0 | 6 |
| server-cache-controller.h | 0 | 0 | 5 |
| server-cache-graph.cpp | 0.2561 | 136 | 531 |
| server-cache-graph.h | 0.95 | 19 | 20 |
| server-cache-hybrid.cpp | 0.2216 | 409 | 1846 |
| server-cache-hybrid.h | 0.7027 | 78 | 111 |
| server-cache-io-worker.cpp | 0.5519 | 85 | 154 |
| server-cache-legacy.h | 0 | 0 | 1 |
| server-cache-policy-lru.cpp | 0.6667 | 18 | 27 |
| server-cache-store-cold.cpp | 0.4954 | 108 | 218 |
| server-cache-store-cold.h | 0.25 | 5 | 20 |
| server-context.cpp | 0.0124 | 39 | 3138 |

## test-stage10-cold-store-hardening

- Aggregate line rate: 0.125270470333675
- Lines covered: 0 / 0

| File | Line rate | Covered | Valid |
| --- | --- | --- | --- |
| test-stage10-cold-store-hardening.cpp | 0.9947 | 187 | 188 |
| server-cache-controller.cpp | 0 | 0 | 6 |
| server-cache-controller.h | 0 | 0 | 5 |
| server-cache-graph.cpp | 0.2128 | 113 | 531 |
| server-cache-graph.h | 0.95 | 19 | 20 |
| server-cache-hybrid.cpp | 0.2308 | 426 | 1846 |
| server-cache-hybrid.h | 0.6724 | 78 | 116 |
| server-cache-io-worker.cpp | 0.513 | 79 | 154 |
| server-cache-legacy.h | 0 | 0 | 1 |
| server-cache-policy-lru.cpp | 0 | 0 | 27 |
| server-cache-store-cold.cpp | 0.7615 | 166 | 218 |
| server-cache-store-cold.h | 0.8333 | 20 | 24 |
| server-context.cpp | 0 | 0 | 3138 |

## test-step6-demotion-protocol

- Aggregate line rate: 0.137675463222908
- Lines covered: 0 / 0

| File | Line rate | Covered | Valid |
| --- | --- | --- | --- |
| test-step6-demotion-protocol.cpp | 0.9903 | 305 | 308 |
| server-cache-controller.cpp | 0 | 0 | 6 |
| server-cache-controller.h | 0 | 0 | 5 |
| server-cache-graph.cpp | 0.2599 | 138 | 531 |
| server-cache-graph.h | 0.95 | 19 | 20 |
| server-cache-hybrid.cpp | 0.247 | 456 | 1846 |
| server-cache-hybrid.h | 0.6341 | 78 | 123 |
| server-cache-io-worker.cpp | 0.5519 | 85 | 154 |
| server-cache-legacy.h | 0 | 0 | 1 |
| server-cache-policy-lru.cpp | 0.7037 | 19 | 27 |
| server-cache-store-cold.cpp | 0.5046 | 110 | 218 |
| server-cache-store-cold.h | 0.25 | 5 | 20 |
| server-context.cpp | 0 | 0 | 3138 |

## test-step7-promotion-protocol

- Aggregate line rate: 0.151336302895323
- Lines covered: 0 / 0

| File | Line rate | Covered | Valid |
| --- | --- | --- | --- |
| test-step7-promotion-protocol.cpp | 0.9922 | 380 | 383 |
| server-cache-controller.cpp | 0 | 0 | 6 |
| server-cache-controller.h | 0 | 0 | 5 |
| server-cache-graph.cpp | 0.2128 | 113 | 531 |
| server-cache-graph.h | 0.95 | 19 | 20 |
| server-cache-hybrid.cpp | 0.2486 | 459 | 1846 |
| server-cache-hybrid.h | 0.6341 | 78 | 123 |
| server-cache-io-worker.cpp | 0.7987 | 123 | 154 |
| server-cache-legacy.h | 0 | 0 | 1 |
| server-cache-policy-lru.cpp | 0 | 0 | 27 |
| server-cache-store-cold.cpp | 0.7385 | 161 | 218 |
| server-cache-store-cold.h | 0.75 | 15 | 20 |
| server-context.cpp | 0 | 0 | 3138 |

## test-step11-test-hooks-fault-injection

- Aggregate line rate: 0.139858569985408
- Lines covered: 0 / 0

| File | Line rate | Covered | Valid |
| --- | --- | --- | --- |
| test-step11-test-hooks-fault-injection.cpp | 0.9967 | 300 | 301 |
| server-cache-controller.cpp | 0 | 0 | 6 |
| server-cache-controller.h | 0 | 0 | 5 |
| server-cache-graph.cpp | 0.275 | 146 | 531 |
| server-cache-graph.h | 0.95 | 19 | 20 |
| server-cache-hybrid.cpp | 0.2524 | 466 | 1846 |
| server-cache-hybrid.h | 0.5954 | 78 | 131 |
| server-cache-io-worker.cpp | 0.5974 | 92 | 154 |
| server-cache-legacy.h | 0 | 0 | 1 |
| server-cache-policy-lru.cpp | 0.6667 | 18 | 27 |
| server-cache-store-cold.cpp | 0.5092 | 111 | 218 |
| server-cache-store-cold.h | 0.2174 | 5 | 23 |
| server-context.cpp | 0 | 0 | 3138 |

## test-step12-branch-graph

- Aggregate line rate: 0.578279266572638
- Lines covered: 0 / 0

| File | Line rate | Covered | Valid |
| --- | --- | --- | --- |
| test-step12-branch-graph.cpp | 0.9557 | 151 | 158 |
| server-cache-graph.cpp | 0.452 | 240 | 531 |
| server-cache-graph.h | 0.95 | 19 | 20 |

## test-step13-stage8

- Aggregate line rate: 0.175214615892582
- Lines covered: 0 / 0

| File | Line rate | Covered | Valid |
| --- | --- | --- | --- |
| test-step13-stage8.cpp | 1 | 503 | 503 |
| server-cache-controller.cpp | 0 | 0 | 6 |
| server-cache-controller.h | 0 | 0 | 5 |
| server-cache-graph.cpp | 0.7552 | 401 | 531 |
| server-cache-graph.h | 0.95 | 19 | 20 |
| server-cache-hybrid.cpp | 0.3066 | 566 | 1846 |
| server-cache-hybrid.h | 0.7027 | 78 | 111 |
| server-cache-io-worker.cpp | 0.039 | 6 | 154 |
| server-cache-legacy.h | 0 | 0 | 1 |
| server-cache-policy-lru.cpp | 0 | 0 | 27 |
| server-cache-store-cold.cpp | 0 | 0 | 218 |
| server-cache-store-cold.h | 0 | 0 | 20 |
| server-context.cpp | 0 | 0 | 3138 |

## Combined denominator (sum across all 8 coverage runs)

- Combined line rate: 0.2127
- Combined covered: 9785 / 45999
- 80% threshold: FAIL
