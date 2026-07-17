# Part 177: F176-01 controller terminal matrix fix

Date: 2026-07-17
Status: ACCEPTED BY ARCHITECT PART 178
Scope: C++ controller test correction only

## Trigger

Architect Part 176 found that `stage39_terminal_forbidden_effects_clear()`
still checked the older forbidden-effect field set. The route driver already
required the three component fields added after D39-QA-05:

- `later_kind_work_delta`
- `post_abort_pressure_delta`
- `post_abort_diagnostic_delta`

That made the C++ controller predicate weaker than the route proof and weaker
than the Part 167/168 accepted contract.

## Change

`tests/test-cache-controller.cpp` now includes all three component fields in
`stage39_terminal_forbidden_effects_clear()`.

The observed forbidden-effect probe matrix now covers the three component
production-boundary probes:

- `later_kind_work` -> `later_kind_work_delta`
- `post_abort_pressure` -> `post_abort_pressure_delta`
- `post_abort_diagnostic` -> `post_abort_diagnostic_delta`

For each component negative, the test checks that the selected component is
`1`, both sibling components are `0`, aggregate `later_work_delta` is `1`, the
common terminal predicate rejects the proof, checkpoint residency remains hot,
topology deltas remain zero, and diagnostic deltas stay empty.

No product code changed.

## Evidence

Fresh seam-ON Release configure:

```powershell
cmake -S . -B build-stage39-f176-fix-20260717-01 -DCMAKE_BUILD_TYPE=Release -DLLAMA_STAGE39_LIVE_TEST_SEAM=ON -DLLAMA_BUILD_TESTS=ON -DGGML_CUDA=OFF
```

Result: PASS, exit `0`.

Focused controller build:

```powershell
cmake --build build-stage39-f176-fix-20260717-01 --config Release --target test-cache-controller -j 4
```

Result: PASS, exit `0`. MSVC emitted pre-existing conversion warnings and three
`fprintf` format warnings in `tests/test-cache-controller.cpp`; none failed the
build.

Controller executable:

```powershell
.\build-stage39-f176-fix-20260717-01\bin\Release\test-cache-controller.exe
```

Result: PASS, exit `0`; footer reported `All tests passed successfully!`.
The Stage 39 observed forbidden-effect probe row passed with the three new
component probe roots:

- `stage39_tp39_03_probe_later_kind_work_delta`
- `stage39_tp39_03_probe_post_abort_pressure_delta`
- `stage39_tp39_03_probe_post_abort_diagnostic_delta`

Not run by request:

- TP-39-03 model run
- coverage

## Handoff

F176-01 is fixed in the C++ controller test matrix and accepted by Architect
Part 178. Manager may consider a new bounded D39-QA-07 rerun gate. Coverage
remains blocked until canonical TP-39-03 passes.
