// k6 script: pull /health and /metrics from the local llama-server in hybrid mode.
// This is a connectivity-only probe because the standard k6 distribution does
// not include the SSE extension that the project's bench/script.js needs.
import http from 'k6/http';
import { check, sleep } from 'k6';

const url = __ENV.SERVER_URL || 'http://127.0.0.1:8132';
const vus = parseInt(__ENV.K6_VUS || '1');
const iters = parseInt(__ENV.K6_ITERS || '20');

export const options = {
    vus: vus,
    iterations: iters,
    thresholds: {
        'http_req_failed': ['rate<0.10'],
        'http_req_duration': ['p(95)<500'],
    },
};

export default function () {
    const health = http.get(url + '/health', { tags: { name: 'health' } });
    check(health, { 'health 200': (r) => r.status === 200 });
    const metrics = http.get(url + '/metrics', { tags: { name: 'metrics' } });
    check(metrics, { 'metrics 200': (r) => r.status === 200 });
    sleep(0.1);
}
