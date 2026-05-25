# Cache handling test plan - Part 5: runner and acceptance criteria

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Implemented runner

**Implementation available:** The test runner described below has been implemented and is available in [../cache-handling-test-scripts/](../cache-handling-test-scripts/).

**Quick start:**

```powershell
# Run all tests with default configuration
& "._design_docs\cache-handling-test-scripts\execute_tests.ps1"
```

See [../cache-handling-test-scripts/README.md](../cache-handling-test-scripts/README.md) for usage instructions and customization options.

## Runner specification

The implemented PowerShell runner (`execute_tests.ps1`) includes these features:

**Configuration (via script variables):**

- `$BuildDir` - Build directory path (default: "build")
- `$Model` - Test model path (default: hardcoded Qwen2.5-VL-3B path)
- `$StartPort` - Starting port for server instances (default: 8120)

The runner:

1. Uses a pre-built `llama-server` from the specified build directory (build must be done separately).
2. Starts a fresh server for each integration test case.
3. Writes logs to `._test_output/cache-handling/<timestamp>/`.
4. Saves stdout, stderr, and process exit codes for each test.
5. Writes a comprehensive test report to `._design_docs/.test_reports/test-report-<date>.md`.
6. Exits with non-zero code if any tests fail.

## Helper functions

The runner includes helper functions in `run_cache_integration.ps1`:

- `Get-FreePort` - Finding a free TCP port
- `Start-LlamaServer` - Starting `llama-server` with test configuration
- `Wait-ForServer` - Waiting for `/health` endpoint to become ready
- `Stop-LlamaServer` - Stopping server processes cleanly
- `Invoke-Test` - Executing individual test cases with logging and error handling
- `Add-TestResult` - Recording test results to the report file

The helper functions handle HTTP requests to `/completion`, `/health`, `/metrics`, and `/cache/stats`, capture logs even when startup fails, and ensure process cleanup in finally blocks.

The implementation follows the principle: keep the helper script boring. Cache tests are hard enough without clever shell behavior.

## Current test coverage

The implemented test suite covers:

- **C01-C04:** Cache mode selection (default, legacy, hybrid, invalid)
- **C05-C06:** HTTP endpoints with/without metrics
- **C10:** Legacy mode compatibility with prompt reuse
- **N01-N04:** Edge and negative scenarios (invalid modes, cache disabled, idle-slots config, missing model)
- **N05-N07:** HTTP surface validation (`/cache/stats`, `/health`, `/metrics`)

See Parts 3 and 4 of this test plan for the complete test matrix.

## Future enhancements

The current runner does not yet implement:

- `-SkipBuild` switch (build must be done separately)
- `-IncludeDraft` switch (draft model tests not yet implemented)
- `-IncludeStress` switch (stress tests not yet implemented)
- Environment variable for model path override (path is hardcoded)
- Cache hit/miss counter validation from `/metrics`
- Multi-prompt cache behavior tests

These features should be added as the cache implementation matures and the test scope expands.

## Acceptance criteria

The test matrix scenarios (Part 3) define the testable acceptance criteria for the currently implemented cache scope. Check the design documents listed in [document-index.md](../document-index.md) to understand what features are available for testing.

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
- Test summary with pass, fail, skip counts.
- Metrics snapshots around cache save, hit, miss, eviction, and restore failure cases.
- Known gaps with references to implementation gap documents.

Do not report focused cache-controller line coverage here. Integration evidence should describe server runs, model paths, HTTP requests, and metrics changes.
