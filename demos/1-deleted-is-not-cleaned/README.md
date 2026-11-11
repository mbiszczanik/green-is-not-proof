# Demo 1: deleted is not cleaned up

A diagnostic setting is a separate resource attached to a storage account's blob service. Deleting the
account reports success, but the setting may stay behind and attach to a new account with the same name.

The rule: a successful delete is a declaration. The stronger check is listing the non-cascaded child resources, read
back after the delete.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| `Remove-AzStorageAccount` succeeded (the green) | that the delete call returned | what else the delete left behind |
| Listing diagnostic settings on the new account (step 4) | that this child type was left behind and re-attached to a same-named account | other child types, other resource types, other regions |

## Before the talk

Run `scripts/Start-DemoRun.ps1`. It creates the storage account with the diagnostic setting `diag-to-log`
and writes `out/run.json`, which every step reads (or pass `-RunId`).

## On stage

Each step prints one masked line; `Show` prints the tool versions before it (see Tool versions and timing).

| Step | Command | Prints |
| --- | --- | --- |
| 1 | `./Show-DiagnosticSettingLeftover.ps1 -Step Show` | `Storage <name> has diagnostic setting(s): diag-to-log` |
| 2 | `-Step Delete` | `Deleted storage account <name>: OK` (the green) |
| 3 | `-Step Recreate` | `Recreated storage account <name>` (same name, region, SKU, tags); retries every 5 s for up to 60 s if Azure still holds the name |
| 4 | `-Step List` | `Diagnostic settings on the NEW account: <names>` |
| 5 | `-Step Clean` | `Removed <n> diagnostic setting(s)` |

The point lands at step 4: the delete was green, and the old setting is still listed on the new account.

## Tool versions and timing

- `-Step Show` and `-Step Verify` first print a `Tool versions:` line for PowerShell, Az.Accounts, Az.Storage and
  Az.Monitor; the other steps keep to their one line. A tool whose version differs from the one the result was observed
  with gets a `WARNING:` line naming both versions. No run in the log records a version for these four, so today they
  are printed under `Not compared` (`config/demo-tools.psd1` holds the observed versions).
- Expected duration: not timed per step yet. The one known wait is step 3: while Azure still holds the deleted
  account's name, `Recreate` retries every 5 s for up to 60 s, then fails with `try again shortly`. One retry was
  observed on 2026-11-04 (run `202611041553`), none on 2026-11-05 (run `202611052136`). Have a sentence ready for
  that minute.
- Warm-up: none is known. The preparation check below is the rehearsal.

## Preparation check

Before the stage, run steps 2 and 3, then `-Step Verify`. It exits 0 and prints
`Demonstration reproduced: ...` only when `diag-to-log` is listed on the recreated account. If the setting is absent,
or only another setting is listed, it prints `Demonstration did not reproduce: ...` and exits 1: do not go on stage with
that run. A failed read also exits 1. `-Step List` stays a display step and exits 0 on an empty listing, which is the
expected result after step 5. Run step 5 afterwards, or let `scripts/Stop-DemoRun.ps1` do it.

**Observed 2026-11-03**, earlier setup (the account and its setting were created by the earlier setup script, code
at `1992109`, recorded in PR #2): step 4 printed `Diagnostic settings on the NEW account: diag-to-log`, and step 5
removed it.

**Observed 2026-11-03**, current setup (the account and the setting come from `infra/declared.bicep`, run
`202611031935`, code at `15907c2`): the same output, every step exit 0.

**Observed 2026-11-08**, the newest full run (run `202611081831`, code at `0571f52`): `Show`, `Delete`, `Recreate`,
`Verify`, `List` and `Clean` each exit 0; `Verify` printed `Demonstration reproduced: ...`, `List` printed
`Diagnostic settings on the NEW account: diag-to-log` and `Clean` printed `Removed 1 diagnostic setting(s)`. `Verify`
after `Clean` was not run then; its exit 1 was observed on 2026-11-05 (run `202611052136`). See
[docs/live-run-log.md](../../docs/live-run-log.md). Run it again before each delivery.

## If you stop after step 2

If the account is deleted and not recreated, `scripts/Stop-DemoRun.ps1` recreates it empty
(`Storage <name> from this run is missing; recreating it empty ...`), finds the setting that survived, removes it,
reads the listing back and then deletes the group. Observed live on 2026-11-04 (see the live-run log). You can also
run `-Step Recreate` and `-Step Clean` yourself first.

## Cost

No extra resources beyond the run: the recreated account replaces the deleted one. `scripts/Stop-DemoRun.ps1`
removes it with the rest of the run.
