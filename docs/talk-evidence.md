# Talk evidence index

What each live part of the talk can cite, and where the evidence is. The decks and speaker notes live elsewhere and
shall point here instead of copying results. A figure on a slide comes from a dated block in
[live-run-log.md](live-run-log.md), never from a demo README's expected output.

The newest full runs are the blocks of 2026-11-11, runs `202611111504` (code at `c9a3e9f`) and `202611111517` (code at
`34bf7cb`), in the test subscription: demos 0, 1, 3 and 5 in Azure, the local demos (2, 4, 6 and 7) in the second run.
Each row cites the newest block first and the 2026-11-08 block (run `202611081831`, code at `0571f52`) after it. Where
a block does not record a detail, the row names the older block that does and says so.

## Core

| Part | Demo and command | Last observed (live-run-log block) | The slide may say | The slide may not say |
| --- | --- | --- | --- | --- |
| Act 1, deleted is not cleaned up | [demo 1](../demos/1-deleted-is-not-cleaned/README.md), steps `Show`, `Delete`, `Recreate`, `Verify`, `List`, `Clean` of `Show-DiagnosticSettingLeftover.ps1` | 2026-11-11, run `202611111504`, code at `c9a3e9f`: each step exit 0; `Verify` printed `Demonstration reproduced: diagnostic setting diag-to-log is listed on the NEW account`; `Clean` printed `Removed 1 diagnostic setting(s)`. Earlier, 2026-11-08, run `202611081831`, code at `0571f52`: each step exit 0; `Verify` printed `Demonstration reproduced: diagnostic setting diag-to-log is listed on the NEW account`; `List` printed `Diagnostic settings on the NEW account: diag-to-log`; `Clean` printed `Removed 1 diagnostic setting(s)`. `Verify` after `Clean` was not run on 2026-11-08; its exit 1 is cited from 2026-11-05, run `202611052136`, code at `99fa8fd` | the setting of a deleted account was listed on a new account with the same name | that other child types or other resources are left behind |
| Act 2, a gate you never saw red | [demo 4](../demos/4-gate-never-red/README.md), `Invoke-Gate.ps1 -Script Silent`, `Counted`, `Fixed` with `-State Empty` and `Ok` | 2026-11-11, run `202611111517`, local, code at `34bf7cb`: runner exit 0, 0, 1, 0 for `Silent`/`Empty`, `Counted`/`Empty`, `Fixed`/`Empty`, `Fixed`/`Ok`. Earlier, 2026-11-08, local part of the block of run `202611081831`: runner exit 0, 0, 1, 0 for `Silent`/`Empty`, `Counted`/`Empty`, `Fixed`/`Empty`, `Fixed`/`Ok`; `Process exit code: 0` for the first two. That block records neither the number of failure lines nor the PowerShell version; the 2 failure lines and version 7.6.9 are cited from 2026-11-03, run `202611032044` | a script can print failures and exit 0; the fixed version exits non-zero on the same failure | that the PowerShell behaviour holds on versions other than 7.6.9 (the version recorded on 2026-11-03; the 2026-11-08 block names no version) |

## Module A

| Part | Demo and command | Last observed | The slide may say | The slide may not say |
| --- | --- | --- | --- | --- |
| Exists is not working | [demo 5](../demos/5-exists-is-not-healthy/README.md), `New-FailedExtension.ps1` then `Show-ExistenceVsState.ps1 -ExpectFailed` | 2026-11-11, run `202611111504`, code at `c9a3e9f`: `New-FailedExtension.ps1` exit 0 after 34 s; `Show-ExistenceVsState.ps1` exit 1 without the flag and exit 0 with `-ExpectFailed`, both printing `Existence check: PASS` and `State check: FAIL (ProvisioningState: Failed)`; before the extension exists both modes exit 1. The earlier runs (2026-11-08, run `202611081831`, code at `0571f52`, and 2026-11-04, run `202611041758`) predate the exit-code change: exit 0 without the flag. `VMExtensionProvisioningError` is cited from 2026-11-04; the 2026-11-08 and 2026-11-11 blocks do not record the Azure error | an extension in state `Failed` passes an existence check and fails a state check | that this is what happened in the original SkyCraft case; it is the same shape, built to fail on purpose |

## Optional material and module C

| Item | Command | Last observed | Note |
| --- | --- | --- | --- |
| Demo 0, a tag is not ownership | `Invoke-TagAudit.ps1`, `Invoke-OwnershipAudit.ps1` | 2026-11-11, run `202611111517`, code at `34bf7cb`: tag audit exit 0 with 7 resources; ownership audit exit 1 with 4 rows right after the VM and with 5 rows after the demo 5 extension. Earlier, 2026-11-08, run `202611081831`, code at `0571f52`: tag audit exit 0 with 7 resources; ownership audit exit 1 with 4 rows right after the VM (VM, NIC, OS disk, shutdown schedule) and with 6 rows after the demo 5 extension (the four plus `AzurePolicyforLinux` and `gnp-failing-script`) | the tag audit exits 0 while the ownership audit exits 1; the row count depends on the subscription and on time (a policy of that subscription installs `AzurePolicyforLinux`) |
| Demo 2, dry-run is not safe | `Invoke-Pester ./demos/2-dry-run-is-not-safe` | 2026-11-11, run `202611111517`, local, code at `34bf7cb`: with `-CI` process exit 1 and `Tests Passed: 1, Failed: 1`. Earlier, 2026-11-08, local part of the block of run `202611081831`: with `-CI -Output Detailed` process exit 1 and `Tests Passed: 1, Failed: 1`; without `-CI` process exit 0. That block does not name the tests; the failure on `Deploy-Example.ps1` and the pass on the fixed script are cited from 2026-11-04, code at `4c73f01` | offline; no Azure call |
| Teardown after an interrupted demo 1 | `Stop-DemoRun.ps1 -RunId <id>` after demo 1 `Delete`, with `run.json` moved away | 2026-11-04, run `202611041708`, exit 0: recreated the missing account empty, `Removed 1 diagnostic setting(s)`, nothing left afterwards. No later block repeats this path: the runs of 2026-11-05 and 2026-11-08 completed demo 1 before the teardown | a setting can outlive its deleted account and cannot be listed while the account is gone, so the teardown finds it by recreating the account; it does not cover untagged resources outside the group |
| Demo 6, a gate that reads only the exit code | `Invoke-Gate.ps1 -Gate Bare` and `-Gate Fixed` | 2026-11-11, run `202611111517`, local, code at `34bf7cb`: runner exit 0, 1, 0, 0 for `Bare`/`Sample`, `Fixed`/`Sample`, `Bare`/`Clean`, `Fixed`/`Clean`. Earlier, 2026-11-08, local part of the block of run `202611081831`: runner exit 0, 1, 0, 0 for `Bare`/`Sample`, `Fixed`/`Sample`, `Bare`/`Clean`, `Fixed`/`Clean`. That block does not record the printed lines; `Bare gate: PASS` with 1 diagnostic line and `Fixed gate: FAIL` are cited from 2026-11-04, local, code at `4c73f01` | module C; the client story stays in the private notes |
| Demo 7, a gate that passes when nothing was evaluated | `Invoke-Gate.ps1 -Gate Bare` and `-Gate Fixed` with `-Pipeline Misconfigured` | 2026-11-11, run `202611111517`, local, code at `34bf7cb`: runner exit 0, 1, 1, 1 for `Bare`/`Misconfigured`, `Fixed`/`Misconfigured`, `Fixed`/`Configured`, `Bare`/`Configured`; the two `Configured` runs print `Rules processed: 21, failed: 8, errored: 0`, and the failed rules include `Azure.Storage.MinTLS` (AZR-000200) and `Azure.Storage.BlobPublicAccess` (AZR-000198). Earlier, 2026-11-08, local part of the block of run `202611081831`: `Bare`/`Misconfigured` runner exit 0 with `Rules evaluated: 0`; `Fixed`/`Misconfigured` runner exit 1; `Fixed`/`Configured` runner exit 1 with `Rules processed: 21, failed: 8`. That block does not record module versions; PSRule 2.9.0 with PSRule.Rules.Azure 1.47.0 is cited from 2026-11-05, local | module C; with Bicep expansion off, `Assert-PSRule` evaluated no rule on an insecure template and exited 0; the option `Execution.UnprocessedObject=Error` is not shown as a fix (it stopped a run with expansion on, one observation, 2026-11-05) |
| The repository's own CI gate for skipped tests | `pwsh -NoProfile -File tools/Invoke-CiPester.ps1 -Path ./tests`, as `.github/workflows/ci.yml` runs it | Before the fix (PR #44): CI runs 42512467461 (2026-11-08, main at `8114e6b`) and 42996830906 (2026-11-11, main at `36e27c5`), both conclusion success, `Tests Passed: 301, Failed: 0, Skipped: 2`; those logs do not name the two skipped tests (issue #32 names the demo 7 real-rule tests). After the fix: CI run 43050066849 (2026-11-11, main at `078ea2d`), success, `Pester counts: 338 total, 338 passed, 0 failed, 0 skipped (0 allowlisted), 338 evaluated`; the same command run locally on `078ea2d` gave exit 0 and the same counts. The gate shown failing on a bad input (2026-11-11, local, a temporary suite of one skipped test, outside the repository): exit 1, `Pester counts: 1 total, 0 passed, 0 failed, 1 skipped (0 allowlisted), 0 evaluated` and `Pester rejected: no test was evaluated (every test was skipped); 1 skipped test(s) not on the allowlist` | may say: a green CI run can hide skipped tests; before the fix the demo repository's CI was green with 2 skipped tests; after it CI prints the skipped and evaluated counts and fails on an unlisted skip or on zero evaluated tests. May not say: which tests the two skipped ones were, from the CI logs alone; that the rejection was shown in a CI run (it was shown locally and by `tests/Invoke-CiPester.Tests.ps1`) |

## Not yet observed

These must not be presented as observed:

- the author's review of the demo 2 backup recording: owed. PR #31 asked not to merge before the author had reviewed
  the video; it merged on 2026-11-08, and no file in this repository records a review date or a result;
- the identifier scan of the backup recordings, due at D-2: demos 0, 1, 2, 4, 5, 6 and 7 have a recording (made
  2026-11-07 and 2026-11-08, see the log), and no scan result is recorded;
- the full sequence on the code of the day of delivery (last full runs: 2026-11-11, runs `202611111504` at `c9a3e9f`
  and `202611111517` at `34bf7cb`, both before the merge of PR #43 into main at `078ea2d`; add a dated block to the
  log before each delivery).

## Updating this page

When a new block is added to the live-run-log, the same pull request shall update the matching row here: the date, the
run id and the observed lines. If a row cannot cite a block, then the row shall move to "Not yet observed". If a row
keeps a detail from an older block, then it shall name that block and say why.
