# Part 93: Manager Prometheus parser rerun gate

Date: 2026-07-14
Verdict: PASS
Decision: D39-EXEC-22

Design Part 48 and Architect Part 92 prove that D39-EXEC-21 reached the
Prometheus endpoint with valid MTP capability but used an invalid JSON
extractor. D39-EXEC-22 authorizes the helper-only parser correction, its pure
tests, and the exact two-node rerun after those tests pass.

Developer may replace `_extract_metrics_json()` with the single strict,
line-anchored parser in Part 48. Both MTP metrics callers must share it. The
default `Stage39Server`, product exporter, public labels, endpoint, and saved
helper evidence shape remain unchanged. Parser errors must stop before proof or
apply with `BLOCKED-route-fixture-drift`.

Run the four exact pure parser nodes from Part 48 first. All must pass without a
server, model, or network. Only then run the midpoint and step-2 route nodes,
sequentially from fresh isolated processes and roots. Route acceptance remains
`2 passed`, `0 failed`, `0 skipped` under all Part 47 caps and assertions.

No product code, build, alternate parser, JSON fallback, canonical TP-39-03,
coverage, full route suite, full QA, commit, push, PR, or reviewer response is
authorized. Preserve parser output and both route artifact roots. Fresh
Architect implementation review is next after the rerun.
