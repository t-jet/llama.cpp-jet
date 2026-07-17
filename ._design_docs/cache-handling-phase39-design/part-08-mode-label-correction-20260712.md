# Part 8: mode label correction

Date: 2026-07-12
Status: READY FOR FRESH ARCHITECT RE-REVIEW

## Finding addressed

F39-AR3-01 found that both new public metric families included a `mode` label
without a closed value domain. Part 3 now sets the complete domain to the single
value `hybrid` for both families.

## Binding contract

The hybrid-cache controller owns the semantic label choice. It reports typed
mode, result, and reason enums. The metrics exporter owns their fixed string
mapping and cannot accept caller-provided label text.

For `llamacpp:cache_two_layer_decisions_total` and
`llamacpp:cache_cold_transactions_total`, the only allowed mode is `hybrid`.
Legacy mode emits neither family. An unknown mode enum is an invariant failure:
the exporter rejects the increment, emits no series, and invokes the existing
internal invariant diagnostic. It must not publish `unknown`, an empty value,
or a caller-supplied value.

## Verification

TP-39-15 exercises every accepted label enum and an invalid mode cast at the
controller/exporter boundary. Focused assertions verify exact enum-to-string
mapping and rejection before increment. A live scrape must show:

- mode values equal the set `{hybrid}` for each family;
- result and reason values are subsets of Part 3's fixed sets;
- no invalid input creates a time series;
- decision-family cardinality is at most 32;
- transaction-family cardinality is at most 27.

The bounds are the complete Cartesian products of each fixed label domain:
`1 * 4 * 8` and `1 * 3 * 9`. Valid pairing constraints can reduce observed
series counts but cannot increase them. All Stage 39 expected tuples name
`mode="hybrid"`; legacy TP-39-11 expects no Stage 39 series delta.

## Handoff

This correction closes the design gap identified by F39-AR3-01. Manager gate
and Developer planning remain blocked until a fresh Architect re-review passes.
