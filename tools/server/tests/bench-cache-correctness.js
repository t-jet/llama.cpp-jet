// bench-cache-correctness.js
// Stage 10 cache correctness benchmark for standard k6 (no SSE extension).
//
// Uses the /completion endpoint (non-streaming) to drive cache hit and miss
// scenarios and validates exact-blob cache behaviour through the timings
// field of each response.
//
// Environment variables:
//   BENCH_URL          Server base URL, default http://127.0.0.1:8132
//   BENCH_ITERS        Total probe iterations (hit + miss rounds), default 12
//   BENCH_PROMPT       Prompt text for all cache-probe iterations
//   BENCH_N_PREDICT    Tokens to predict per request, default 8
//
// Evidence classification (T116 / T117):
//   - cache_n per response: direct stats, from /completion JSON body
//   - cache_hit_rate threshold: harness-only rate derived from timings.cache_n
//   - Cache-miss and cache-hit prompt_ms values: direct stats
//   - Counter deltas (hits_total, misses_total): public Prometheus via /metrics
//     snapshots taken by the caller before and after this script runs.
//
// Correctness gate (T117):
//   The script fails the k6 run if the cache_hit_rate threshold is not met.
//   No performance claim is valid unless the correctness threshold passes.

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const serverUrl  = __ENV.BENCH_URL        || 'http://127.0.0.1:8132';
const totalIters = parseInt(__ENV.BENCH_ITERS    || '12');
const nPredict   = parseInt(__ENV.BENCH_N_PREDICT || '8');
const probePrompt = __ENV.BENCH_PROMPT ||
    'Cache QA deterministic prompt.';

// One cold warmup iteration followed by (totalIters - 1) probe iterations.
// The first probe after warmup should be the first eligible hit candidate.
const warmupIters = 1;
const probeIters  = totalIters - warmupIters;

// Custom metrics.
const cacheMissPromptMs  = new Trend('cache_miss_prompt_ms',  true);
const cacheHitPromptMs   = new Trend('cache_hit_prompt_ms',   true);
const cacheNTrend        = new Trend('cache_n_tokens');
const cacheHitRate       = new Rate('cache_hit_rate');
const requestsOk         = new Counter('requests_ok');

export const options = {
    scenarios: {
        // Single-VU warmup: one cold request to seed the cache entry.
        warmup: {
            executor: 'shared-iterations',
            vus: 1,
            iterations: warmupIters,
            maxDuration: '120s',
            exec: 'doWarmup',
            tags: { phase: 'warmup' },
        },
        // Single-VU hit probes: repeated identical requests to verify cache.
        hit_probe: {
            executor: 'shared-iterations',
            vus: 1,
            iterations: probeIters,
            maxDuration: '300s',
            startTime: '0s',
            exec: 'doProbe',
            tags: { phase: 'hit_probe' },
        },
    },
    thresholds: {
        // Correctness gate: at least 60% of probe iterations must be cache hits.
        // The first probe after warmup may still be a miss if the entry was not
        // yet committed, so 60% allows for one or two warm-up-adjacent misses.
        'cache_hit_rate': ['rate>=0.60'],
        // All requests must succeed.
        'http_req_failed': ['rate<0.01'],
    },
};

// Shared payload for all iterations so the server can cache it.
const completionBody = JSON.stringify({
    prompt: probePrompt,
    n_predict: nPredict,
    temperature: 0,
    seed: 42,
    cache_prompt: true,
    stream: false,
});

const postHeaders = { 'Content-Type': 'application/json' };

// Warmup: send one cold request to prime the cache.
// Does not count toward cache_hit_rate.
export function doWarmup() {
    const res = http.post(serverUrl + '/completion', completionBody, { headers: postHeaders, tags: { name: 'warmup' } });
    check(res, { 'warmup 200': (r) => r.status === 200 });
    if (res.status === 200) {
        requestsOk.add(1);
        try {
            const body = JSON.parse(res.body);
            const cacheN = (body.timings && body.timings.cache_n != null)
                ? body.timings.cache_n : 0;
            cacheMissPromptMs.add(body.timings ? body.timings.prompt_ms : 0);
            cacheNTrend.add(cacheN);
        } catch (_) {}
    }
    sleep(0.2);
}

// Hit probes: send the same payload and validate cache_n > 0.
export function doProbe() {
    const res = http.post(serverUrl + '/completion', completionBody, { headers: postHeaders, tags: { name: 'hit_probe' } });
    const ok200 = check(res, { 'probe 200': (r) => r.status === 200 });
    if (!ok200) {
        cacheHitRate.add(false);
        return;
    }
    requestsOk.add(1);
    try {
        const body = JSON.parse(res.body);
        const cacheN = (body.timings && body.timings.cache_n != null)
            ? body.timings.cache_n : 0;
        const isHit = cacheN > 0;
        cacheHitRate.add(isHit);
        cacheNTrend.add(cacheN);
        if (isHit) {
            cacheHitPromptMs.add(body.timings.prompt_ms);
        } else {
            cacheMissPromptMs.add(body.timings.prompt_ms);
        }
    } catch (_) {
        cacheHitRate.add(false);
    }
    sleep(0.1);
}
