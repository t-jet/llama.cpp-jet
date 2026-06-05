# Patch Notes - Part 3: No intended change to prompt selection or decoding semantics

Source: [../fix-qwen-summary.md](../fix-qwen-summary.md)

### No intended change to prompt selection or decoding semantics

This change does not alter:

- slot selection heuristics
- prompt similarity logic
- the main decode path when state export succeeds
- the correctness of existing cache reuse / checkpoint restore logic

The goal is not to change model behavior, but to make the server survive large-state export failures, adapt correctly to the current upstream MTP behavior, and avoid pathological checkpoint or draft-context memory failures.
