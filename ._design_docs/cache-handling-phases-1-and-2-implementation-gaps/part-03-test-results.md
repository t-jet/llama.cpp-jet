# Cache handling phases 1 and 2 implementation gaps - Part 3: Test results

Source: [../cache-handling-phases-1-and-2-implementation-gaps.md](../cache-handling-phases-1-and-2-implementation-gaps.md)

### Test results

Commands run:

```text
cmake --build build-coverage --config Debug --target test-cache-controller
ctest --test-dir build-coverage -C Debug -R test-cache-controller --output-on-failure
.\build-coverage\bin\Debug\test-cache-controller.exe
D:\app\OpenCppCoverage\OpenCppCoverage.exe ... --export_type cobertura:D:\source\llama.cpp-jet\build-coverage\coverage-cache.xml ...
cmake --build build-phase2 --config Release --target test-cache-controller
ctest --test-dir build-phase2 -C Release -R test-cache-controller --output-on-failure
cmake --build build-phase2 --config Release --target llama-server
```

Results:

- Debug `test-cache-controller` build passed.
- Debug CTest passed: 1/1 tests.
- Direct Debug test executable passed: 23/23 checks.
- Release `test-cache-controller` build passed.
- Release CTest passed: 1/1 tests.
- Release `llama-server` build passed.

### Updated focused coverage

Report paths:

- HTML: `build-coverage\coverage-cache-html\index.html`
- Cobertura XML: `build-coverage\coverage-cache.xml`

Focused total line rate:

- 95.52% (`703/736` lines)

Updated per-file line rates:

| File | Previous | Updated |
| --- | ---: | ---: |
| `tests/test-cache-controller.cpp` | 100.00% | 100.00% |
| `tools/server/server-cache-controller.cpp` | 83.33% | 83.33% |
| `tools/server/server-cache-controller.h` | 100.00% | 100.00% |
| `tools/server/server-cache-hybrid.cpp` | 53.80% | 86.34% |
| `tools/server/server-cache-hybrid.h` | 91.18% | 91.18% |
| `tools/server/server-task.h` | 45.75% | 97.39% |

Remaining coverage caveat:

- `server-cache-hybrid.cpp` is now above 80%, but the uncovered lines still include model-backed runtime save/restore paths that cannot be honestly tested without a loaded llama context.
- Target/draft restore success and failure still need integration coverage.
