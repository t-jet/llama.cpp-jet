# Part 47: TP-39-03 trace preflight correction

Date: 2026-07-14
Status: ARCHITECT PASS; MANAGER GATE NEXT
Scope: D39-EXEC-20 route fixture logging and preflight only

## Finding

D39-EXEC-20 selected the required MTP runtime. Its midpoint artifact records
the MTP context, a 164.758 MiB target component, a 14.375 MiB draft component,
19 accepted draft tokens out of 33, and real checkpoints. Preflight stopped
because two required literals are emitted through `COM_TRC` and `SPC_TRC`.
Default verbosity is 3; trace requires 4.

`common/arg.cpp` registers `-lv`, `--verbosity`, and `--log-verbosity`, maps 4
to trace, and also registers `LLAMA_ARG_LOG_VERBOSITY`. Use the explicit CLI so
`command.json` owns the setting. Do not set the environment form.

## Corrected command and caps

Add exactly one adjacent pair to `Stage39MTPServer`, immediately after the
speculative selector:

```text
--spec-type draft-mtp --log-verbosity 4
```

Before process start, require exactly one `--spec-type draft-mtp` pair and one
`--log-verbosity 4` pair. Reject `-v`, `--verbose`, level 5, an environment
override, duplicate logging options, or product-log changes.

Keep the 20-minute wall, 16 GiB RSS, and 4 GiB cold-root caps per node. Add a
64 MiB `server.log` cap to the existing resource guard. A cap breach terminates
the node and records `BLOCKED-route-fixture-cap`. This is test-only logging;
default server behavior does not change.

## Complete preflight contract

The rerun must check all coupled assertions in one pass:

1. Binary, model, and template exist. Model size is 2,834,975,040 bytes;
   architecture is `qwen35`, context length 262144, and NextN layers 1.
2. `command.json` contains the two exact selector pairs above, one each, and
   records only the two existing test-seam environment names without values.
3. Literal message lengths, compact JSON bytes, 5,687-byte total, and SHA-256
   `d34dee12bb4b0c0782975f853f25a9a063f1a01d76d1552de1202e7457379a49`
   match before the single chat admission.
4. Admission returns HTTP 200 and discovery waits for an idle server.
5. Trace startup contains the exact model name, MTP context creation,
   `bounded partial sequence removal`, `draft-mtp`, checkpoint maximum 32,
   spacing 0, and real checkpoint creation. Source save has positive target and
   draft components.
6. Discovery has exactly one owned hot `exact_blob`, no cold candidate or cold
   file, positive resident bytes and budgets, and no pre-apply decision or
   transaction delta.
7. Proof returns exactly `exact_blob`, then `checkpoint`. IDs are distinct and
   nonzero; owner matches; both are hot; kind links match; target, draft,
   resident, and prepared sizes are positive and checked; runtime pair matching
   is true.
8. Repeated discovery and proof leave generation, tokens, metrics, descriptors,
   files, topology, ranks, budgets, and one-shot state unchanged.
9. Apply uses only those two IDs, exact at step 1 and checkpoint at step 2, with
   current generation, HMAC token, and production-prepared size records.

No literal may be removed or replaced by a weaker metadata inference. The two
trace literals remain direct checks of the bounded-removal and installed
speculative implementations.

## Rerun and supersession

After a Manager gate, change only the dedicated helper command, exact argv
assertions, and log-size guard. Rerun the midpoint and step-2 node IDs from new
processes, roots, ports, tokens, and sessions. Run midpoint first; stop on any
failed preflight. Acceptance remains `2 passed, 0 failed, 0 skipped`.

This part supersedes only Part 46's assumption that the two literals appear at
default logging and Part 88's resulting blocked handoff. Part 88 stays as
historical fail-closed evidence. Parts 45-47 otherwise remain binding. Product
code, normal logging, route schema, workload, budgets, fault assertions,
canonical TP-39-03, coverage, and QA are unchanged.

Architect verdict: PASS for this narrow test-only correction. Next owner:
Manager for a correction and exact two-node rerun gate.
