# Cache handling test plan - Part 6: stress tests and acceptance criteria

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Current test coverage

The implemented test suite covers:

- **R01-R04:** Regression prevention (legacy unchanged, default mode, opt-in, dependencies)
- **C01-C06:** Mode selection (default, legacy, hybrid, invalid, HTTP endpoints)
- **C10:** Legacy compatibility with prompt reuse
- **C11-C15:** Concurrent access safety (save, load, metrics under concurrency)
- **B01-B06:** Stage 2 boundary metadata (extraction, threading, fallbacks, edge cases)
- **H01-H29:** Phase 3 hybrid cache (non-destructive hits, LRU eviction, namespace isolation)
- **D01-D05:** Draft model paired save/restore
- **N01-N13:** Edge and negative scenarios (validation, failures, oversized entries)

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

The test matrix scenarios (Parts 3 and 4) define the testable acceptance criteria for the currently implemented cache scope. Check the design documents listed in [document-index.md](../document-index.md) to understand what features are available for testing.

## Concrete stress test scenarios

Run these only under `-IncludeStress` flag. Each stress test must run to completion without crashes, deadlocks, or memory leaks.

### S01: Memory pressure sustained

**Objective:** Verify stable memory usage under prolonged cache pressure.

**Configuration:**

- `--cache-mode hybrid --cache-ram 10 --parallel 2`
- 1000 unique prompts (different prefixes, varying lengths 10-100 tokens)
- 30 minutes continuous runtime

**Procedure:**

1. Generate 1000 unique prompt variations
2. Loop through prompts with 1-second delay between requests
3. Monitor memory usage every 60 seconds
4. Capture `/metrics` every 5 minutes

**Success Criteria:**

- Peak memory (working set) remains stable (< 5% growth over 30 minutes)
- Cache memory stays within `--cache-ram` limit (10 MiB)
- No process crashes or hangs
- Eviction metrics show expected churn
- No memory leaks detected (final memory ≈ initial memory after GC)

### S02: High concurrency

**Objective:** Verify thread safety under high concurrent load.

**Configuration:**

- `--cache-mode hybrid --parallel 8 --cache-ram 50`
- 50 unique prompts
- 500 total requests (mix of hits and misses)

**Procedure:**

1. Warm up cache with 50 unique prompts
2. Send 500 requests with 8 concurrent clients
3. Mix: 70% cache hits (repeat prompts), 30% misses (new prompts)
4. No delay between requests (maximum concurrency)

**Success Criteria:**

- All 500 requests complete successfully
- No deadlocks or race conditions
- No cache corruption (verify metrics accuracy)
- `llamacpp_cache_hits + llamacpp_cache_misses = 500` (no lost operations)
- Response times consistent (no pathological slowdowns)

### S03: Eviction churn

**Objective:** Verify eviction policy stability under constant pressure.

**Configuration:**

- `--cache-mode hybrid --cache-ram 1 --parallel 1`
- 10 unique prompts (each ~100 tokens, ~10 KB serialized)
- Budget allows only ~3 entries
- Rotate through all 10 prompts 100 times (1000 total requests)

**Procedure:**

1. Send prompts in sequence: P1, P2, P3, ..., P10, P1, P2, ...
2. Each prompt triggers eviction after first 3 entries
3. Monitor eviction metrics after each cycle

**Success Criteria:**

- All 1000 requests complete successfully
- Eviction count ~970 (1000 requests - 3 initial fills - ~27 cache hits from LRU)
- No cache corruption or invalid state
- Memory usage stable (cache size oscillates but doesn't grow)
- LRU policy maintains correct ordering (most recent 3 entries retained)

### S04: Long-running stability

**Objective:** Verify 6-hour production-like stability.

**Configuration:**

- `--cache-mode hybrid --cache-ram 100 --parallel 4`
- Mix of operations: 60% cache hits, 30% misses, 10% evictions
- 10-second intervals between request batches

**Procedure:**

1. Define 100 unique prompts (10-200 tokens each)
2. Loop for 6 hours:
   - Send batch of 4 requests (1 per slot)
   - 60% reuse recent prompts, 30% new prompts, 10% trigger eviction
   - Wait 10 seconds
3. Capture `/metrics` every 15 minutes
4. Monitor memory usage every 15 minutes

**Success Criteria:**

- Process runs 6 hours without crash or hang
- Memory usage stable (< 10% growth over 6 hours)
- Metrics remain accurate throughout (spot-check samples)
- No memory leaks (final memory ≈ stabilized memory after 1 hour)
- Cache hit rate ~60% as expected
- Response times consistent (no degradation over time)

## Stress test acceptance criteria

Stress test failures block production-readiness claims. However, they should not block basic implemented-scope coverage claims unless:

1. The failure reproduces in the normal test matrix (C/H/N/B/D/R series)
2. The failure indicates a fundamental design flaw (not environmental)
3. The failure severity is critical (crashes, data corruption, security)

Non-blocking stress failures (acceptable for Phase 3 sign-off):

- Performance degradation under extreme load (> 8 concurrent slots)
- Memory usage slightly above configured limits (< 10% overage)
- Eviction timing variations under heavy concurrency

Blocking stress failures (must be fixed before production):

- Crashes or hangs
- Memory leaks (> 20% growth over test duration)
- Cache corruption (incorrect metrics, lost entries, data mismatch)
- Race conditions or deadlocks
- Security issues (unauthorized access, descriptor corruption)

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
