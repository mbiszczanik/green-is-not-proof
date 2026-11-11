# Talk evidence index

What each live part of the talk can cite, and where the evidence is. The decks and speaker notes live elsewhere and
shall point here instead of copying results. A figure on a slide comes from a dated block in
[live-run-log.md](live-run-log.md), never from a demo README's expected output.

The newest full run is the block of 2026-11-08, run `202611081831`, code at `0571f52`: the Azure part in the second
test subscription, the local demos (2, 4, 6 and 7) at the end. Each row cites that block first. Where the block does
not record a detail, the row names the older block that does and says so.

## Core

| Part | Demo and command | Last observed (live-run-log block) | The slide may say | The slide may not say |
| --- | --- | --- | --- | --- |
| Act 1, deleted is not cleaned up | [demo 1](../demos/1-deleted-is-not-cleaned/README.md), steps `Show`, `Delete`, `Recreate`, `Verify`, `List`, `Clean` of `Show-DiagnosticSettingLeftover.ps1` | 2026-11-08, run `202611081831`, code at `0571f52`: each step exit 0; `Verify` printed `Demonstration reproduced: diagnostic setting diag-to-log is listed on the NEW account`; `List` printed `Diagnostic settings on the NEW account: diag-to-log`; `Clean` printed `Removed 1 diagnostic setting(s)`. `Verify` after `Clean` was not run on 2026-11-08; its exit 1 is cited from 2026-11-05, run `202611052136`, code at `99fa8fd` | the setting of a deleted account was listed on a new account with the same name | that other child types or other resources are left behind |
| Act 2, a gate you never saw red | [demo 4](../demos/4-gate-never-red/README.md), `Invoke-Gate.ps1 -Script Silent`, `Counted`, `Fixed` with `-State Empty` and `Ok` | 2026-11-08, local part of the block of run `202611081831`: runner exit 0, 0, 1, 0 for `Silent`/`Empty`, `Counted`/`Empty`, `Fixed`/`Empty`, `Fixed`/`Ok`; `Process exit code: 0` for the first two. That block records neither the number of failure lines nor the PowerShell version; the 2 failure lines and version 7.6.9 are cited from 2026-11-03, run `202611032044` | a script can print failures and exit 0; the fixed version exits non-zero on the same failure | that the PowerShell behaviour holds on versions other than 7.6.9 (the version recorded on 2026-11-03; the 2026-11-08 block names no version) |

## Module A

| Part | Demo and command | Last observed | The slide may say | The slide may not say |
| --- | --- | --- | --- | --- |
| Exists is not working | [demo 5](../demos/5-exists-is-not-healthy/README.md), `New-FailedExtension.ps1` then `Show-ExistenceVsState.ps1` | 2026-11-08, run `202611081831`, code at `0571f52`: `New-FailedExtension.ps1` exit 0 after 39 s with `ProvisioningState Failed`; `Show-ExistenceVsState.ps1` exit 0 with `Existence check: PASS`, `State check: FAIL (ProvisioningState: Failed)`. That block does not record the Azure error; `VMExtensionProvisioningError` is cited from 2026-11-04, run `202611041758` | an extension in state `Failed` passes an existence check and fails a state check | that this is what happened in the original SkyCraft case; it is the same shape, built to fail on purpose |

## Optional material and module C

| Item | Command | Last observed | Note |
| --- | --- | --- | --- |
| Demo 0, a tag is not ownership | `Invoke-TagAudit.ps1`, `Invoke-OwnershipAudit.ps1` | 2026-11-08, run `202611081831`, code at `0571f52`: tag audit exit 0 with 7 resources; ownership audit exit 1 with 4 rows right after the VM (VM, NIC, OS disk, shutdown schedule) and with 6 rows after the demo 5 extension (the four plus `AzurePolicyforLinux` and `gnp-failing-script`) | the tag audit exits 0 while the ownership audit exits 1; the row count depends on the subscription and on time (a policy of that subscription installs `AzurePolicyforLinux`) |
| Demo 2, dry-run is not safe | `Invoke-Pester ./demos/2-dry-run-is-not-safe` | 2026-11-08, local part of the block of run `202611081831`: with `-CI -Output Detailed` process exit 1 and `Tests Passed: 1, Failed: 1`; without `-CI` process exit 0. That block does not name the tests; the failure on `Deploy-Example.ps1` and the pass on the fixed script are cited from 2026-11-04, code at `4c73f01` | offline; no Azure call |
| Teardown after an interrupted demo 1 | `Stop-DemoRun.ps1 -RunId <id>` after demo 1 `Delete`, with `run.json` moved away | 2026-11-04, run `202611041708`, exit 0: recreated the missing account empty, `Removed 1 diagnostic setting(s)`, nothing left afterwards. No later block repeats this path: the runs of 2026-11-05 and 2026-11-08 completed demo 1 before the teardown | a setting can outlive its deleted account and cannot be listed while the account is gone, so the teardown finds it by recreating the account; it does not cover untagged resources outside the group |
| Demo 6, a gate that reads only the exit code | `Invoke-Gate.ps1 -Gate Bare` and `-Gate Fixed` | 2026-11-08, local part of the block of run `202611081831`: runner exit 0, 1, 0, 0 for `Bare`/`Sample`, `Fixed`/`Sample`, `Bare`/`Clean`, `Fixed`/`Clean`. That block does not record the printed lines; `Bare gate: PASS` with 1 diagnostic line and `Fixed gate: FAIL` are cited from 2026-11-04, local, code at `4c73f01` | module C; the client story stays in the private notes |
| Demo 7, a gate that passes when nothing was evaluated | `Invoke-Gate.ps1 -Gate Bare` and `-Gate Fixed` with `-Pipeline Misconfigured` | 2026-11-08, local part of the block of run `202611081831`: `Bare`/`Misconfigured` runner exit 0 with `Rules evaluated: 0`; `Fixed`/`Misconfigured` runner exit 1; `Fixed`/`Configured` runner exit 1 with `Rules processed: 21, failed: 8`. That block does not record module versions; PSRule 2.9.0 with PSRule.Rules.Azure 1.47.0 is cited from 2026-11-05, local | module C; with Bicep expansion off, `Assert-PSRule` evaluated no rule on an insecure template and exited 0; the option `Execution.UnprocessedObject=Error` is not shown as a fix (it stopped a run with expansion on, one observation, 2026-11-05) |

## Not yet observed

These must not be presented as observed:

- the author's review of the demo 2 backup recording: owed. PR #31 asked not to merge before the author had reviewed
  the video; it merged on 2026-11-08, and no file in this repository records a review date or a result;
- the identifier scan of the backup recordings, due at D-2: demos 0, 1, 2, 4, 5, 6 and 7 have a recording (made
  2026-11-07 and 2026-11-08, see the log), and no scan result is recorded;
- the full sequence on the code of the day of delivery (last full run: 2026-11-08, run `202611081831`, at `0571f52`;
  add a dated block to the log before each delivery).

## Updating this page

When a new block is added to the live-run-log, the same pull request shall update the matching row here: the date, the
run id and the observed lines. If a row cannot cite a block, then the row shall move to "Not yet observed". If a row
keeps a detail from an older block, then it shall name that block and say why.
