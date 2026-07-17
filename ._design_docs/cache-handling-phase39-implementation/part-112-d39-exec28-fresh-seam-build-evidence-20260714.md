# Part 112: D39-EXEC-28 fresh seam build evidence

Date: 2026-07-14
Status: BLOCKED; CONTROLLER SUITE CRASHED
Authority: Manager Part 111

## Guarded inputs

Pre-build and post-test SHA-256 values matched:

| Input | SHA-256 | UTC write time |
| --- | --- | --- |
| `tools/server/server-cache-hybrid.cpp` | `8BFD3BB8F0F7E302FAC80F6CA5282190AD2AE7E1CFD84436990797D86F54EC97` | `2026-07-13T23:50:34.6980332Z` |
| `tools/server/server-cache-hybrid.h` | `701FC17AFEC9D1B710841CF0B16ADEB13F4B0CAAB3DF853A95EAA6F8FECC0442` | `2026-07-13T23:45:26.3992563Z` |
| `tests/test-cache-controller.cpp` | `3E30AA091DB7873440EE80784338714342B2FEED3FC6768AFFF9703DAB121080` | `2026-07-13T23:48:00.9947137Z` |

No guarded input changed during the build and test window.

## Build

The sole authorized incremental build was:

```text
cmake --build build-stage39-seam-on --config Release \
  --target test-cache-controller llama-server --parallel 2
exit 0, 9.246 seconds
```

The log records compilation of `server-cache-hybrid.cpp` and links for both
targets. It is preserved at
`._test_output/stage39-d39-exec28-build.log`.

| Output | SHA-256 | UTC write time |
| --- | --- | --- |
| `server-cache-hybrid.obj` | `2B552C180E2F99A6FDA4DBB07596C767E7FB460F4BD32AC87010F34AF26B2478` | `2026-07-14T00:02:28.0748496Z` |
| `test-cache-controller.obj` | `7C5AF1D360CBDAD417DD882CC15110B706FEEB71AD1E8E20D989FEA419ECE165` | `2026-07-13T23:48:26.4490173Z` |
| `test-cache-controller.exe` | `C89B01AECCFD40CAF504BC2658FD9784C14A4B987C9C1729FB2EB012125CFDF2` | `2026-07-14T00:02:28.7859498Z` |
| `llama-server.exe` | `7731168CEEF1ACB1A3AEC8A69DA3B37879477E5981FECD894DCB5AA526D1B0CC` | `2026-07-14T00:02:30.5077479Z` |
| `llama-server-impl.dll` | `16CDBCD05A76AFBF8A9AD21F331F6E378C5AFD9E198817B44FF97BC5A4BB83DD` | `2026-07-14T00:02:30.2700645Z` |

Each object is newer than its guarded source inputs. Both executables and the
server implementation DLL are newer than all guarded inputs.

## Controller result

The sole authorized full controller run exited `-1073741819` (`0xC0000005`)
after 1.768 seconds. Before the crash, all seven observed forbidden-effect
probes passed, as did the midpoint and step-2 common-epilogue fault cases. The
process crashed after emitting `Stage 23 demotion budget fallback stale
completion checkpoint attach...`. It did not print that test's verdict or the
suite completion line.

The full log is preserved at
`._test_output/stage39-d39-exec28-controller.log`. No rerun occurred.

## Verdict

D39-EXEC-28 fails its required controller exit-zero check. Fresh build and
input-identity proof pass, but they do not waive the suite crash. Route nodes,
pure/model/default/canonical tests, coverage, and full QA remain blocked.
Manager direction is required before any further build or test execution.
