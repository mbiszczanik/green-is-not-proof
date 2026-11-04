# Talk evidence index

What each live part of the talk can cite, and where the evidence is. The decks and speaker notes live elsewhere and
shall point here instead of copying results. A figure on a slide comes from a dated block in
[live-run-log.md](live-run-log.md), never from a demo README's expected output.

## Core

| Part | Demo and command | Last observed (live-run-log block) | The slide may say | The slide may not say |
| --- | --- | --- | --- | --- |
| Act 1, deleted is not cleaned up | [demo 1](../demos/1-deleted-is-not-cleaned/README.md), five steps `Show`, `Delete`, `Recreate`, `List`, `Clean` of `Show-DiagnosticSettingLeftover.ps1` | 2026-11-03, run `202611031935`: each step exit 0; `List` printed `Diagnostic settings on the NEW account: diag-to-log`; `Clean` removed 1 | the setting of a deleted account was listed on a new account with the same name | that other child types or other resources are left behind |
| Act 2, a gate you never saw red | [demo 4](../demos/4-gate-never-red/README.md), `Invoke-Gate.ps1 -Script Silent`, `Counted`, `Fixed` with `-State Empty` and `Ok` | 2026-11-03, run `202611032044`: `Silent` and `Counted` printed 2 failure lines and `Process exit code: 0`; `Fixed` exited 1 on the empty state and 0 on the ok state | a script can print failures and exit 0; the fixed version exits non-zero on the same failure | that the PowerShell behaviour holds on versions other than 7.6.9 (the version it was observed on) |

## Module A

| Part | Demo and command | Last observed | The slide may say | The slide may not say |
| --- | --- | --- | --- | --- |
| Exists is not working | [demo 5](../demos/5-exists-is-not-healthy/README.md), `New-FailedExtension.ps1` then `Show-ExistenceVsState.ps1` | 2026-11-03, run `202611032044`: extension step exit 0 after 37 s, Azure returned `VMExtensionProvisioningError`; `Existence check: PASS`, `State check: FAIL (ProvisioningState: Failed)` | an extension in state `Failed` passes an existence check and fails a state check | that this is what happened in the original SkyCraft case; it is the same shape, built to fail on purpose |

## Optional material and module C

| Item | Command | Last observed | Note |
| --- | --- | --- | --- |
| Demo 0, a tag is not ownership | `Invoke-TagAudit.ps1`, `Invoke-OwnershipAudit.ps1` | 2026-11-04, run `202611041019`: ownership audit exit 1 with 4 rows (VM, network interface, disk, auto-shutdown schedule) | the tag audit exits 0 while the ownership audit exits 1 |
| Demo 2, dry-run is not safe | `Invoke-Pester ./demos/2-dry-run-is-not-safe` | 2026-11-04, run `202611041019`: 1 failed on `Deploy-Example.ps1` (line 18), 1 passed on the fixed script | offline; no Azure call |
| Teardown after an interrupted demo 1 | `Stop-DemoRun.ps1 -RunId <id>` after demo 1 `Delete`, with `run.json` moved away | 2026-11-04, run `202611041708`, exit 0: recreated the missing account empty, `Removed 1 diagnostic setting(s)`, nothing left afterwards | a setting can outlive its deleted account and cannot be listed while the account is gone, so the teardown finds it by recreating the account; it does not cover untagged resources outside the group |
| Demo 6, a gate that reads only the exit code | `Invoke-Gate.ps1 -Gate Bare` and `-Gate Fixed` | 2026-11-04, local: `Bare` PASS with a diagnostic printed; `Fixed` FAIL | module C candidate; the client story stays in the private notes |

## Not yet observed

These must not be presented as observed:

- backup recordings of demos 0, 1, 4, 5 and 6 (due D-2, after an identifier check);
- the full sequence on the code of the day of delivery (add a dated block to the log before each delivery).

## Updating this page

When a new block is added to the live-run-log, the same pull request shall update the matching row here: the date, the
run id and the observed lines. If a row cannot cite a block, then the row shall move to "Not yet observed".
