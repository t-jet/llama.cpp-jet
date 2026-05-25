# Cache handling test plan - Part 5: runner and acceptance criteria

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Recommended runner

Add a PowerShell runner, for example `tools/server/tests/run_cache_integration.ps1`, with these switches:

```powershell
param(
    [string] $BuildDir = "build",
    [string] $Model = $env:LLAMA_CACHE_TEST_MODEL,
    [int] $StartPort = 8120,
    [switch] $SkipBuild,
    [switch] $IncludeDraft,
    [switch] $IncludeStress
)
```

The runner should:

1. Build `llama-server` unless `-SkipBuild` is set.
2. Start a fresh server for each integration case.
3. Run server-backed Python or PowerShell integration cases with `LLAMA_SERVER_BIN_PATH` set when needed.
4. Write logs to `._test_output/cache-handling/<timestamp>/`.
5. Save request bodies, response JSON, metrics snapshots, stderr, and process exit codes.
6. Fail the run if any non-xfailed integration test fails.

## Helper expectations

The runner should include helpers for:

- Finding a free port.
- Starting and stopping `llama-server`.
- Waiting for `/health`.
- Fetching `/metrics`.
- Posting `/completion` and `/v1/chat/completions`.
- Capturing logs even when startup fails.
- Comparing Prometheus counter values before and after a request.

Keep the helper script boring. Cache tests are hard enough without clever shell behavior.

## Acceptance criteria

The current implemented cache scope is covered when:

- Server-backed cache mode tests pass, except any documented xfail for an open runtime gap.
- Invalid `--cache-mode` fails cleanly.
- Legacy remains the default mode.
- `/health` returns exactly `{"status":"ok"}`.
- `/cache/stats` returns 404.
- `/metrics` exposes cache counters for legacy and hybrid when metrics are enabled.
- Hybrid target-only model-backed restore passes at least once with `timings.cache_n > 0`.
- Repeated hybrid restore from the same saved entry passes, proving non-destructive hits at runtime.
- Hybrid divergent-prefix requests miss and still complete.
- Hybrid eviction moves the eviction counter and leaves the server usable.
- Namespace or compatibility-key mismatch tests prove no cross-namespace hit.
- Restore failure tests prove the slot is reset before recomputation, at least for a deterministic synthetic or debug-hook path.

These criteria deliberately go beyond the older Phase 1 and Phase 2 report evidence. The reports show that endpoint-shape integration checks pass, but they also say model-backed restore coverage remains open.

## Optional stress criteria

Run these only under `-IncludeStress`:

- Thirty minutes of mixed legacy and hybrid start/stop cycles.
- Ten minutes of two-slot hybrid requests with different prompts.
- Repeated small-budget runs that force eviction.
- Draft-model paired restore when a small draft model is available.

Stress failures should block a production-readiness claim, but they should not block the basic implemented-scope coverage claim unless the failure reproduces in the normal matrix.

## Evidence to attach to the verification report

For each run, record:

- Git commit or working-tree status.
- Build directory and server binary path.
- Model path.
- Test command lines.
- Test summary with pass, fail, skip, and xfail counts.
- Metrics snapshots around cache save, hit, miss, eviction, and restore failure cases.
- Known gaps, especially any remaining xfail.

Do not report focused cache-controller line coverage here. Integration evidence should describe server runs, model paths, HTTP requests, metrics changes, and remaining xfails.
