# Part 14: build-path gate and report 03 runner fix 2026-06-24

Status: Architect review PASS
Date: 2026-06-24
Owner: Manager / Developer
Scope: Stage 24 execution handoff corrections after report 02 and report 03.

## Report 02 build-path inspection

`test-report-20260624-02.md` records an abandoned setup attempt and build-path
inspection. The `build-cov` clean-build command removed the configured tree and
forced full `ggml-cuda` kernel compilation, which made setup much slower than
the previous CUDA-stage path.

The Manager build-path gate switches active Stage 24 execution to `build-cuda`.
The required proof is:

```text
Build dir: build-cuda
Generator: Visual Studio 17 2022
Platform: x64
GGML_CUDA:BOOL=ON
GGML_NATIVE:BOOL=OFF
BUILD_SHARED_LIBS:BOOL=OFF
Binary: build-cuda/bin/Release/llama-server.exe
```

After removing an accidental uncommitted token in `server-context.cpp`, a
non-destructive `build-cuda` target build passed in 17.042 seconds.

## Report 03 runner-contract block

`test-report-20260624-03.md` passed build, CUDA configure proof, dry-run, and
route-only gates. It blocked during S02 native startup before request traffic.
The server log already contained CUDA/NVIDIA proof, but the runner crashed in
`Get-CudaRuntimeProof`.

Failure:

```text
Cannot find an overload for "Add" and the argument count: "1".
stage24-chat-s02-s03-comparison.ps1:214
```

## Runner fix

`Get-CudaRuntimeProof` used `$matches` as a local `List[object]`. PowerShell
variable names are case-insensitive, so this collided with the automatic
`$Matches` variable populated by `-match`. After a CUDA proof line matched, the
automatic variable replaced the list with a hashtable. The next append called
hashtable `Add(key, value)` with one ordered-dictionary argument.

The runner-only fix renames the local collection to `$proofMatches`. It changes
no product code, public API, metrics, fixtures, request generation, row
classification, or Stage 23 artifacts.

## Verification

Developer verification recorded in `test-report-20260624-03-fixes.md`:

```text
parser=PASS
captured_log=PASS matches=3 first_line=3
isolated_add=PASS matches=2
cuda_cache=PASS GGML_CUDA:BOOL=ON
routeAssignments=1
legacyCompletionLiterals=0
dryrun=PASS rows=2 variants=4 cuda=PASS badRoute=0 badFlags=0 llamaServerProcesses=0
scratch_report_created=NO
```

## Handoff

Architect review passed in Part 15. Manager can reopen QA execution with suffix
`test-report-20260624-04.md`.
