# Part 3: Windows SEH handler + crash-dump design

Status: design draft
Date: 2026-06-25
Stage: 26 (Metrics Alignment + Stage 24/25 Carry-Over Resolution)
Author: Architect
Scope: install a Windows unhandled-exception filter in llama-server
that writes a minidump file and surfaces the exit code on graceful
shutdown.

## Motivation

D-EXEC-24-03 (Stage 24 part-16) and D25-EXEC-04 (Stage 25 part-10)
both observed silent termination of the llama-server process. No
FATAL, SEGV, OOM, or exception marker is present in `server.err.log`,
so the root cause cannot be attributed from logs alone. An
unhandled-exception filter that writes a minidump to disk is the
minimum diagnostic primitive needed to attribute the crash.

## Design

### Handler selection

Use `SetUnhandledExceptionFilter` from the Windows API
(`#include <windows.h>`) wrapped in a new file
`tools/server/server-crash-handler.cpp` plus a corresponding header
`tools/server/server-crash-handler.h`. `SetUnhandledExceptionFilter`
runs after the OS has already terminated the process for unhandled
exceptions (access violation, stack overflow, illegal instruction,
etc.) but before process teardown, so it can write a minidump to
disk before the OS collects it.

`AddVectoredExceptionHandler` is the alternative. It runs in the
exception context and is harder to use for minidumps because the
EXCEPTION_POINTERS structure is more involved. Recommendation:
`SetUnhandledExceptionFilter` for simplicity and the standard
minidump pattern documented by Microsoft.

### Minidump generation

Use `MiniDumpWriteDump` from `DbgHelp.h` (Windows). The minidump
includes:

- Memory: per default `MiniDumpWithDataSegs |
  MiniDumpWithHandleData | MiniDumpWithThreadInfo |
  MiniDumpWithProcessThreadData | MiniDumpWithUnloadedModules`
  for full attribution. Trade-off: full dumps are large. Restrict
  to `MiniDumpWithIndirectlyReferencedMemory |
  MiniDumpWithThreadInfo` so the dump is bounded but still has
  registers, call stacks, and referenced memory pages.
- Registers: implicit in any minidump type.
- Call stack: 32 frames per thread via `MiniDumpWithThreadInfo` +
  `MiniDumpWithProcessThreadData`.
- TID list: `MiniDumpWithThreadInfo`.

### File output

New CLI flag `--crash-dump-dir <path>` (default: empty, meaning no
dumps). When the flag is set, the filter writes
`<path>/llama-server-<pid>-<timestamp>.dmp` using the Windows
process ID and the system time at the moment of the unhandled
exception. Default format: `MiniDump` (small, ~few MiB).

CLI surface change: this is a new public flag. The previous stages
explicitly excluded public CLI changes; this stage is an explicit
exception per user direction because the flag is a diagnostic
operator-facing primitive.

### Installation point

Install the filter at the top of `main()` in `llama-server.cpp`
(or `server.cpp` if `llama-server.cpp` does not exist; the actual
entry point is `tools/server/llama-server.cpp` per the file_search
in this repo). The filter is Windows-only; on non-Windows the
filter install is a no-op guarded by `#ifdef _WIN32`.

### Graceful shutdown

The unhandled-exception filter runs after the OS has decided the
process will terminate. The filter cannot prevent termination but
can write the minidump before the OS tears the process down.

For graceful shutdown (user-driven `Ctrl+C` or `kill`), the server
already exits with status 0 via the signal handler at
`tools/server/server.cpp`. No new graceful-shutdown code is needed.

For the runner to detect "server died" vs "server exited cleanly",
the existing `runner.detect-server-death` check (in
`stage24-chat-s02-s03-comparison.ps1`) already inspects the process
state. The filter writes the dump regardless; the runner reads
`server.exitcode.txt` (new artifact) for post-mortem. The
implementation plan adds a tiny post-process step that writes
`server.exitcode.txt` with the GetExitCodeProcess value on
runner-detected exit.

### Cross-platform behavior

On non-Windows, the filter is a no-op. The `tools/server/CMakeLists.txt`
should add `server-crash-handler.cpp` only when `WIN32` is true.
The new file does not compile on Linux but the design assumes
Windows is the primary platform because the silent crash is a
Windows-only symptom.

## Failure modes

- Disk full: dump write fails. Filter logs the error to stderr
  before returning, which becomes part of the server.err.log
  next to the silent crash signature.
- Permission denied on `--crash-dump-dir`: dump write fails.
  Same stderr fallback.
- Recursive crash inside the filter: MiniDumpWriteDump can throw
  exceptions. Wrap the call in `__try` / `__except` to avoid
  recursive dump writes.

## Expected evidence after implementation

- A `--crash-dump-dir` exists.
- When the server crashes, a `.dmp` file is written.
- The dump is loadable in WinDbg or Visual Studio and shows the
  thread that threw the unhandled exception with full register
  state and call stack.
- The runner captures the dump path in `server.crash-dump.txt` for
  post-mortem.
- Stage 24 rerun in part-05 either captures a fresh crash dump
  (D-EXEC-24-03-b closure) or confirms the server stayed up.

## Handoff

Part-03 is reviewable. Next: part-04 cold-store metric drift.
