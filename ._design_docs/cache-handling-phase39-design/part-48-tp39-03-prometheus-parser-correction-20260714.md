# Part 48: TP-39-03 Prometheus parser correction

Date: 2026-07-14
Status: ARCHITECT PASS; MANAGER GATE NEXT
Scope: D39-EXEC-21 test-helper metrics parsing only

## Root cause and data flow

The dedicated MTP helper requests `GET /metrics`. `server-context.cpp` returns
`text/plain; version=0.0.4` Prometheus exposition. Cache samples use label
blocks such as `{mode="hybrid"}`. The response contains no JSON object.

`Stage39MTPServer._metrics()` and `_metrics_after_pressure()` both pass that
text to `_extract_metrics_json()`. The extractor slices from the first `{` to
the last `}` and gives the result to `json.loads()`. The first cache label block
therefore becomes a false JSON start. D39-EXEC-21 stopped at the first
pre-apply metrics snapshot. `Stage39Server` has no metrics method and does not
call this extractor.

## Narrow correction

Replace `_extract_metrics_json()` with one pure line parser. It must:

1. inspect only complete Prometheus sample lines anchored at line start and
   line end;
2. recognize exactly `llamacpp:cache_two_layer_decisions_total`,
   `llamacpp:cache_cold_transactions_total`, and
   `llamacpp:cache_namespace_nodes`;
3. parse labels into a map without depending on label order, accept escaped
   Prometheus label text, and reject duplicate label names;
4. require `{mode,result,reason}` on decision and transaction rows, and
   `{mode,scope}` on the namespace-node row;
5. select `mode="hybrid"`, require one `scope="all"` namespace-node sample,
   and require finite nonnegative integer values;
6. reject duplicate target tuples or any malformed line carrying a target
   family name;
7. ignore comments, unrelated metric families, blank lines, and log-like brace
   text that is not an anchored target sample.

Decision and transaction families may be absent before their first event; map
that state to empty arrays. Return this stable helper-only shape:

```text
{
  "cache_two_layer_decisions": [{"result": ..., "reason": ..., "value": ...}],
  "cache_cold_transactions": [{"result": ..., "reason": ..., "value": ...}],
  "branch_forest": {"total_nodes": ...}
}
```

Sort row arrays by result and reason. This keeps preflight equality independent
of exporter row order while preserving the existing decision, transaction, and
topology assertions. It does not change the HTTP endpoint, product exporter,
public labels, route schema, or saved helper JSON shape.

`Stage39MTPServer._metrics()` must catch parser failure and call `_block()` with
`BLOCKED-route-fixture-drift` before proof or apply. `_metrics_after_pressure()`
uses the same parser. Do not add a second parser or a JSON fallback.

## Focused proof before model execution

Add pure pytest nodes in `test_stage39_live_pressure.py`:

- `test_stage39_metrics_parser_preserves_required_schema`: parse comments,
  unrelated `{mode="hybrid"}` samples, shuffled target labels, decision and
  transaction rows, and the hybrid/all node gauge; assert the exact shape,
  integer values, and deterministic row order.
- `test_stage39_metrics_parser_ignores_non_sample_braces`: include log-like
  `{not-json}` text and unrelated label blocks before and after target rows;
  assert they cannot become parser boundaries or output rows.
- `test_stage39_metrics_parser_rejects_target_schema_errors`: parameterize a
  missing node gauge, wrong or duplicate labels, duplicate target tuples,
  malformed target sample, negative, fractional, NaN, and infinite values;
  require `ValueError` for every case.
- `test_stage39_metrics_parser_detects_preapply_and_terminal_drift`: compare
  canonical snapshots and prove changes in a decision value, transaction value,
  or total node count break equality; assert one commit/none row still sums to
  one through the existing terminal expression.

Run only those pure nodes first. They need no server, model, build, route seam,
or network access.

## Supersession and rerun

This part supersedes only the implicit Parts 45-47 assumption that the helper
could recover cache JSON from `/metrics`, plus Part 91's blocked handoff. Parts
45-47 remain binding for fixture, trace, caps, proof, fault, and stop rules.
Part 91 remains historical fail-closed evidence.

After focused parser PASS and a new Manager gate, rerun only midpoint then
step-2 from fresh isolated processes and roots. Acceptance remains `2 passed,
0 failed, 0 skipped`. Any helper failure or cap stops the sequence. Product
code, build, canonical TP-39-03, coverage, full QA, commit, and push remain
blocked.

Architect verdict: PASS for this correction. Next owner: Manager.
