# Part 51: Guarded discovery rework evidence

Date: 2026-07-13
Status: PARTIAL
Scope: Developer rework for Architect Part 50 findings F39-GDIR-01 through
F39-GDIR-05

## Implemented

- Removed the snapshot-state digest fallback. Cache generation now advances at
  the mutation helpers covered by the controller mutation matrix.
- Added strict `desired_hot_orders` and `desired_cold_ranks` apply fields.
  Validation happens before consumption. Setup writes and rollback use the
  generation owner; rollback does not rewind the generation.
- Added the seven missing named controller cases and the three guarded
  TP-39-02/03/04 controller cases.
- Added the 13 named Python route cases from test-plan Part 43. They start real
  ON and OFF binaries and exercise the HTTP route with a model-backed cache.
- Replaced `std::random_device` with the operating-system CSPRNG:
  `BCryptGenRandom` on Windows, `arc4random_buf` on Apple platforms, and
  `getrandom` on Linux. Controller construction fails if nonce creation fails.
- Updated the PowerShell driver to send the strict order and rank setup arrays.

## Evidence

| Check | Result | Artifact |
| --- | --- | --- |
| ON Release server and controller build | PASS | `._test_output/stage39-gdir-build9.log` |
| Python guarded-route suite | PASS, 13 tests | `._test_output/stage39-gdir-route6.log` |
| Release controller suite | PASS | `._test_output/stage39-gdir-controller8.log` |

The controller suite includes the generation mutation matrix, changed-restored
snapshot, budget drift, idle-dispatch race, terminal pre-transaction rollback,
normal `tx_update()` success, and guarded TP-39-02/03/04 cases. One preceding
controller run printed the success footer but exited with an access violation;
the immediate clean rerun above exited zero. This transient result remains part
of the evidence and should be considered during review.

## Still open

- The row-specific PowerShell assertions required by F39-GDIR-04 are not yet
  implemented. The driver still checks common response shape only.
- No separate model-backed driver smoke for TP-39-02/03/04 was run in this
  correction pass. The Python route suite is model-backed, but it does not
  replace the driver acceptance rows.
- The four PowerShell 5/7 canonical coverage probes and the 80 percent result
  were not rerun.
- Complete generation ownership still needs fresh Architect review against all
  Part 15 mutation families, including recovery paths.

## Handoff

Return this partial evidence to the Manager. F39-GDIR-02, F39-GDIR-03, and
F39-GDIR-05 have executable correction evidence. F39-GDIR-01 needs the fresh
architecture audit, while F39-GDIR-04 and canonical coverage remain open.
