# Demo 1: deleted is not cleaned up

A diagnostic setting is a separate resource attached to a storage account's blob service. Deleting the
account reports success, but the setting may stay behind and attach to a new account with the same name.

The rule: a successful delete is a declaration. Evidence: listing the non-cascaded child resources, read back after
the delete.

## Before the talk

Run `scripts/Start-DemoRun.ps1`. It creates the storage account with the diagnostic setting `diag-to-log`
and writes `out/run.json`, which every step reads (or pass `-RunId`).

## On stage

Each step prints one masked line.

| Step | Command | Prints |
| --- | --- | --- |
| 1 | `./Show-DiagnosticSettingLeftover.ps1 -Step Show` | `Storage <name> has diagnostic setting(s): diag-to-log` |
| 2 | `-Step Delete` | `Deleted storage account <name>: OK` (the green) |
| 3 | `-Step Recreate` | `Recreated storage account <name>` (same name, region, SKU, tags); retries every 5 s for up to 60 s if Azure still holds the name |
| 4 | `-Step List` | `Diagnostic settings on the NEW account: <names>` |
| 5 | `-Step Clean` | `Removed <n> diagnostic setting(s)` |

The point lands at step 4: the delete was green, and the old setting is still listed on the new account.

Live result, 2026-11-03: step 4 printed `Diagnostic settings on the NEW account: diag-to-log`, and
step 5 removed it.

## If you stop after step 2

If the account is deleted and not recreated, `scripts/Stop-DemoRun.ps1` stops before deleting anything and
exits 1 with `Storage <name> from this run is missing; its diagnostic setting may survive.` Run `-Step Recreate`,
then `-Step Clean`, then run the teardown again.

## Cost

No extra resources beyond the run: the recreated account replaces the deleted one. `scripts/Stop-DemoRun.ps1`
removes it with the rest of the run.
