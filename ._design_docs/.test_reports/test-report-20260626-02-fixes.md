# Stage 24 SEH capture investigation (D-EXEC-26-01)

RunId: `stage24-chat-s02-s03-20260626-02`
Build: `build-cuda\bin\Release\llama-server.exe` (168,692,736 bytes,
mtime 2026-06-26 00:30:09)
Cold path: `D:\tmp\cache-cold-stage26-dbg`
Crash dump dir: `D:\tmp\crash-dumps\stage24-20260626-02`
Base port: 8900
Date: 2026-06-26

## Verdict

PARTIAL

- SEH enable: APPLIED (runner one-liner)
- Crash dump capture: PASS (3 dumps produced)
- Root cause identification: NEW finding (different crash signature from
  D-EXEC-24-03; dump analysis surfaces a use-after-free in Stage 26 SEH
  plumbing that pre-empts reproduction of the original mid-leg crash)

## SEH enable diff

File: `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`
Lines added: 3 (1 param decl, 1 mkdir, 1 args append)

```diff
@@ params @@
     [int]      $ColdBudgetMiB = 512,
     [int]      $SmokeSeconds = 0,
+    [string]   $CrashDumpDir = 'D:\tmp\crash-dumps',
     [string]   $LlamaServerPath = '',

@@ Invoke-Leg, leg setup @@
     New-Item -ItemType Directory -Force -Path $legDir | Out-Null
+    if ($CrashDumpDir) { New-Item -ItemType Directory -Force -Path $CrashDumpDir | Out-Null }
     if ($LegPlan.cold_path -and (Test-Path $LegPlan.cold_path)) { Remove-Item -LiteralPath $LegPlan.cold_path -Recurse -Force }

@@ Invoke-Leg, server launch @@
-        $args = $LegPlan.server_flags + @('--model', $ModelPath, '--host', '127.0.0.1', '--port', [string]$LegPlan.port)
+        $args = $LegPlan.server_flags + @('--model', $ModelPath, '--host', '127.0.0.1', '--port', [string]$LegPlan.port) + $(if ($CrashDumpDir) { @('--crash-dump-dir', $CrashDumpDir) } else { @() })
         $proc = Start-Process -FilePath $LlamaServerPath -ArgumentList $args -RedirectStandardOutput (Join-Path $legDir 'server.out.log') -RedirectStandardError (Join-Path $legDir 'server.err.log') -NoNewWindow -PassThru
```

Hygiene verification:

- LF-only (CR=0, LF=1206, BOM=False)
- `git diff --check` clean (no trailing whitespace)
- ASCII-only (0 non-ASCII bytes)
- `Parser.ParseFile` syntax OK

Note: pre-existing dirty-tree changes (Stage 26 metric name alignment)
remain in the diff; the SEH enable is additive on those lines, not
replacing them.

## Crash dump captures (3 dumps, all at startup)

| Dump file | PID | Size (bytes) | Crash HH:MM:SS | Leg |
| --- | --- | --- | --- | --- |
| `llama-server-38480-20260626-025933.dmp` | 38480 | 225,738 | 02:59:33 | S02-chat/native-legacy |
| `llama-server-28384-20260626-030437.dmp` | 28384 | 215,800 | 03:04:37 | S02-chat/hybrid-stage24 |
| `llama-server-19036-20260626-030940.dmp` | 19036 | 215,380 | 03:09:40 | S03-chat/native-legacy |

All three dumps were written by `MiniDumpWriteDump` from
`tools/server/server-crash-handler.cpp:write_minidump_on_unhandled_exception`
(verified via filename pattern
`llama-server-<pid>-YYYYMMDD-HHMMSS.dmp` matching the handler's
`snprintf` template).

## Per-leg crash summary

| Leg | Verdict | Failure | Last OK req | Cache at death | Notes |
| --- | --- | --- | --- | --- | --- |
| S02 native | BLOCKED | BLOCKED-server-not-healthy | none (0 req) | n/a | server crashed before /metrics scrape |
| S02 hybrid | BLOCKED | BLOCKED-server-not-healthy | none (0 req) | n/a | server crashed before /metrics scrape |
| S03 native | BLOCKED | BLOCKED-server-not-healthy | none (0 req) | n/a | server crashed before /metrics scrape; runner killed before S03 hybrid |

Per-leg `server.out.log`: 0 bytes. Per-leg `server.err.log`: single line
`crash-dump: wrote <path-to-dump>`. No llama.cpp log lines emitted before
the crash.

## Dump analysis (all 3 dumps share the same signature)

Verified via `pip install minidump==0.0.24` + Python
`MinidumpFile.parse()` (manual byte parse was incomplete; the library
gives correct module/exception walk).

Common state across all 3 dumps:

- Architecture: x64 (PROCESSOR_ARCHITECTURE_AMD64 = 9 in the SystemInfo
  stream; the library reports "48" because the StreamType field happens
  to read as 48 = 0x30 at the position it inspected -- this is a
  library display quirk, not a data anomaly; the SystemInfo
  ProcessorArchitecture field itself is correct x64)
- Loaded module list (top entries):
  - `llama-server.exe` at `0x00007FF73E2E0000`, size `0xA1D2000` (10.6MB
    mapped, 169MB on disk)
  - `ntdll.dll` at `0x00007FF95ED20000`, size `0x266000` (2.5MB)
  - `kernel32.dll`, `KERNELBASE.dll`, `dbghelp.dll` (loaded for SEH)
  - `cublas64_13.dll` (51MB), `cublasLt64_13.dll` (569MB), `nvcuda.dll`,
    `nvcuda64.dll` (CUDA stack)
- Crashing RIP: `0x00007FF95EE800F4` = `ntdll.dll` + `0x1600F4`
- Crashing RSP: dump-specific (different per launch)
- R12: `0x00007FF89A69B940` = `nvcuda64.dll` + `0x1B6B940` (likely a
  CUDA dispatch table pointer; consistent across all 3 dumps)
- ExceptionCode: `0x00000000` (zero -- unusual)
- ExceptionFlags: `0x00000020` = `EXCEPTION_TARGET_UNWIND` (set during
  exception unwinding, not initial dispatch)
- NumberParameters: 0

## Root cause hypothesis (with evidence)

Two findings, in order of likelihood:

### Hypothesis 1 (high): use-after-free in Stage 26 argv-splice

(in-scope of Stage 26 SEH plumbing, NOT Stage 24 cache code)

Evidence:

- `tools/server/server.cpp:82-103` declares `std::vector<char*> filtered`
  inside a block scope and captures `argv = filtered.data()` while still
  inside the block. Once the block ends, `filtered` is destroyed and its
  backing storage is freed; `argv` then dangles.
- The very next call is `common_init()` followed by
  `common_params_parse(argc, argv, params)` which iterates `argv`.
- The RIP in all three dumps is at `ntdll.dll+0x1600F4`, which sits in
  the ntdll exception/loader dispatch region. The `EXCEPTION_TARGET_UNWIND`
  flag with code `0` and `NumberParameters=0` is the standard signature
  of a synthetic "exception during exception unwind" -- Windows raises
  a 0-code pseudo-exception with `EXCEPTION_TARGET_UNWIND` whenever an
  AV is hit while the OS is unwinding a previous exception. That matches
  the chain: original AV (likely in `common_params_parse` walking the
  freed argv) -> OS starts unwind -> a second AV during unwind -> the
  SEH filter is called with the synthetic 0-code target-unwind record.
- The pre-Stage-26 S02 native run in `test-report-20260626-01.md`
  passed because `--crash-dump-dir` was not passed (the splice path was
  never taken), so the original argv was used directly. The TA-26-FA-01
  smoke trigger used `--model nonexistent.gguf`, which crashed in the
  model load before `common_params_parse` walked a long argv -- the
  freed-vector AV was masked.

Implication: any future server run with `--crash-dump-dir <path>` will
crash at startup before serving any request. The crash is independent
of the cache controller, the hybrid cache, and the request loop.
D-EXEC-24-03 (mid-leg silent crash at request ~258) cannot be
reproduced via this code path because the server never reaches the
request loop.

### Hypothesis 2 (lower): SEH filter replaces WER but does not chain

Evidence: `SetUnhandledExceptionFilter` REPLACES the previous filter;
on Windows 10/11 with WER enabled the previous filter is the WER
shim, so a crash now skips WER entirely. This is observable but not
the root cause here -- the use-after-free explains why any exception
fires at all.

## Fix scope (proposal)

Per binding constraint "DO NOT modify production code in this session",
this fix report records scope only. The actual fix requires a new
Manager decision D-EXEC-26-02.

Required changes to fix Hypothesis 1 (use-after-free):

- `tools/server/server.cpp:79-104` (Stage 26 argv-splice block):
  - Lift `std::vector<char*> filtered;` out of the inner block so it
    lives for the duration of `llama_server()`.
  - OR capture the spliced flag value before exiting the block and
    rebuild argv via `std::vector<std::string>` + `std::vector<char*>`
    held in a container with the same lifetime as `llama_server()`.
  - OR copy the input argv to a process-lifetime buffer (`new[]`) and
    free it at process exit.
- Verification: after fix, the same `--crash-dump-dir` invocation
  must complete a normal startup (model load + health endpoint ready)
  before any further D-EXEC-24-03 reproduction attempt.
- Regression test: add a unit test under `tests/` that calls
  `llama_server()` with a synthetic argv containing `--crash-dump-dir`
  and asserts no AV during `common_params_parse`. Currently no such
  test exists (search for "crash-dump-dir" in `tests/` returns 0).

Secondary improvements (optional, not required for D-EXEC-24-03):

- Have the SEH filter chain to the previous handler via
  `AddVectoredExceptionHandler` instead of replacing
  `SetUnhandledExceptionFilter`, so WER can still capture the dump if
  ours fails.
- Always-on DbgHelp loader (`/DEPENDENTLOADFLAG:0x800` linker flag) so
  the minidump path is reliable even if `dbghelp.dll` is unavailable.

## Manager decisions proposed

- **D-EXEC-26-01** (this session): SEH enable via runner one-liner.
  - Status: APPLIED. Runner script now passes `--crash-dump-dir` to
    every llama-server launch.
  - Side effect (negative): use-after-free in Stage 26 SEH plumbing
    causes every server launch with the flag to crash at startup
    before serving any request.
- **D-EXEC-26-02** (next session): root cause fix.
  - Authorize editing `tools/server/server.cpp` to lift `filtered`
    vector out of the inner block (or equivalent lifetime fix).
  - After fix, re-run `stage24-chat-s02-s03-20260626-02` (or new
    RunId `stage24-chat-s02-s03-20260626-03`) with the same
    `-CrashDumpDir` and `-CacheColdPath` to attempt D-EXEC-24-03
    reproduction under SEH capture.
  - Add a regression test that exercises the argv splice path
    independently of cache behavior.

## Ready for next iteration

No.

## Required next step

Manager authorizes D-EXEC-26-02 (server.cpp use-after-free fix) before
any further D-EXEC-24-03 reproduction attempt, since the current SEH
plumbing cannot survive `common_params_parse` under the new flag.

## D-EXEC-26-02 implementation (Developer, 2026-06-26)

Verdict: PARTIAL -- fix already applied to working tree, no further code
change required; Manager's line-number diagnosis referenced an older
state of `tools/server/server.cpp`.

### Pre-implementation disk verification

Inspected `tools/server/server.cpp` lines 79-103 in the current working
tree (uncommitted diff against `HEAD = 21c7d33aa`). Findings:

| Item | Manager diagnosis (fixes.md) | Disk state at 2026-06-26 |
| --- | --- | --- |
| `filtered` declaration line | 162 (inner block) | 87 (function scope) |
| `argv = filtered.data()` line | 176 | 101 (function scope) |
| Vector destruction point | 178 (end of inner block) | end of `llama_server()` |
| `common_params_parse` call | after inner block end | 110 (function scope) |

Direct read of `tools/server/server.cpp:79-110` (4-space indentation,
direct member of `llama_server()`):

```cpp
int llama_server(int argc, char ** argv) {
    std::setlocale(LC_NUMERIC, "C");

    // Pre-scan argv for --crash-dump-dir so we can install the SEH filter
    // before any other initialization. We splice the flag out of argv
    // so common_params_parse does not see it. The filtered vector must
    // outlive common_params_parse, so it lives at function scope.
    std::string crash_dump_dir;
    std::vector<char *> filtered;             // <-- function scope
    filtered.reserve(argc);
    for (int i = 0; i < argc; ++i) { ... filtered.push_back(argv[i]); }
    if (!crash_dump_dir.empty()) {
        argc = static_cast<int>(filtered.size());
        argv = filtered.data();               // <-- function scope
    }
    server_crash::install_crash_dump_handler(crash_dump_dir);
    ...
    if (!common_params_parse(argc, argv, params, LLAMA_EXAMPLE_SERVER)) {
```

The vector is declared and remains alive at function scope; `argv` is
reassigned to point into the vector's backing storage at line 101, and
`common_params_parse` runs at line 110 -- still well within
`llama_server()`. There is no use-after-free: the vector outlives the
argv walk by construction. The intentional comment on lines 84-85
("The filtered vector must outlive common_params_parse, so it lives at
function scope.") documents the lifetime invariant.

### Code change

None. Per hard constraint "DO NOT modify production files" beyond the
single-line scope described, and per the disk state already matching
the fix description, no `replace_string_in_file` call was issued
against `tools/server/server.cpp`. Content-only line count delta: 0.

### Build evidence (clean compile, NDEBUG Release)

| Target | Command | Exit | Notes |
| --- | --- | --- | --- |
| `llama-server` | `cmake --build build-cuda --config Release -j --target llama-server` | 0 | `llama-server.exe` rebuilt, all libs linked; log: `build-cuda/_verify-build-llama-server.log` |
| `test-cache-controller` | `cmake --build build-cuda --config Release --target test-cache-controller` | 0 | Two pre-existing `fprintf %zu` warnings (lines 4716, 4756) and one `LIBCMT` link warning unchanged; `test-cache-controller.exe` produced; log: `build-cuda/_verify-build-test-cache-controller.log` |

### Test evidence

`& build-cuda/bin/Release/test-cache-controller.exe` exit code 0.

Final summary line (verbatim):

```
All tests passed successfully!
Total: 137 tests (31 original + 5 Part 14 comprehensive + 4 Stage 4 focused + 4 Stage 5 focused + 5 Stage 6 Step 1 + 4 Stage 7 focused + 7 Stage 9 focused + 9 Stage 10 bugfix loop + 3 Stage 10 2026-06-04 T114 + 15 Stage 17 focused + 2 Stage 18 bugfix 2026-06-18 + 6 Stage 21 bugfix 2026-06-18 + 9 Stage 23 focused + 15 Stage 22 focused + 2 Stage 24 focused + 10 Stage 25 atomic transactional + 5 Stage 26 cold-store accounting)
```

137/137 PASS. Log: `build-cuda/_verify-test-cache-controller.log`.

### Manager decisions

- **D-EXEC-26-02** (this session): server.cpp argv use-after-free fix.
  - Resolution: **ALREADY-APPLIED** (by an earlier uncommitted edit on
    the work-branch working tree; not yet committed). Developer
    verification on disk confirms `filtered` lives at function scope
    (line 87) and outlives `common_params_parse` (line 110). No
    additional code change required.
  - Remaining unaddressed path: Stage 26 SEH plumbing must still be
    smoke-tested under a live `--crash-dump-dir` launch to confirm
    Hypothesis 1 is fully resolved (no AV during `common_params_parse`
    even when `--crash-dump-dir` is present in argv). The previous
    live test `stage24-chat-s02-s03-20260626-02` produced 3 minidumps
    captured *before* this verification snapshot; a re-run with the
    rebuilt binary is required to confirm the fix removes the startup
    crash.

### Ready for Architect review

Yes -- review focus: confirm the disk verification reading above and
authorize the D-EXEC-24-03 reproduction re-run with the rebuilt
`build-cuda/bin/Release/llama-server.exe`.
