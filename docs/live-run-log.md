# Live run log

What was observed in Azure, and what is only expected. A line says "observed" only with a date, a command and an
exit code. Everything else is an expected result and must not be presented as an observed fact.

Run the full sequence once before each delivery and add a block below: what ran, when, with which command and
exit code, and what differed from the expected output. Keep the subscription id, tenant and account names out of
this file; name them by role.

## Observed

### 2026-11-11, test subscription, `swedencentral`, run `202611111517`, code at `34bf7cb` (branch of PR #43), second pass

Run by the author from 14:16 to 14:22 UTC on PowerShell 7.6.10, after the pass below, to cover the demos it did not. Every
command as `pwsh -NoProfile -File <script>` (Pester as `Invoke-Pester ... -CI`), exit code from the process.

| Step | Observed |
| --- | --- |
| `Start-DemoRun.ps1`, `New-RogueResource.ps1` | exit 0 after 44 s, exit 0 after 58 s; cost guard 0.293758 EUR for 2 hours |
| Demo 0, `Invoke-TagAudit.ps1`, before and after the extension | exit 0 both times; "All 7 resources carry project tags: OK" |
| Demo 0, `Invoke-OwnershipAudit.ps1`, right after the VM | exit 1; 4 rows: OS disk, VM, shutdown schedule, NIC |
| Demo 0, `Invoke-OwnershipAudit.ps1`, after `New-FailedExtension.ps1` | exit 1; 5 rows, the fifth is `vm-traffic/gnp-failing-script` (the extension carries no tag, so the tag audit still counts 7) |
| Demo 3, `Show-LiveProperty.ps1` | exit 0; `ProvisioningState: Succeeded`, `Strict health: False` |
| Demo 5, `Show-ExistenceVsState.ps1 -ExpectFailed` | exit 0 |
| Demo 2, `Invoke-Pester ./demos/2-dry-run-is-not-safe -CI` | process exit 1; `Passed: 1, Failed: 1` |
| Demo 3, `Invoke-Pester ./demos/3-stub-proves-assumption -CI` | process exit 0; `Passed: 1, Failed: 0` |
| Demo 4, `Invoke-Gate.ps1` `Silent`/`Empty`, `Counted`/`Empty`, `Fixed`/`Empty`, `Fixed`/`Ok` | runner exit 0, 0, 1, 0 |
| Demo 6, `Invoke-Gate.ps1` `Bare`/`Sample`, `Fixed`/`Sample`, `Bare`/`Clean`, `Fixed`/`Clean` | runner exit 0, 1, 0, 0 |
| Demo 7, `Invoke-Gate.ps1` `Bare`/`Misconfigured`, `Fixed`/`Misconfigured`, `Fixed`/`Configured`, `Bare`/`Configured` | runner exit 0, 1, 1, 1; the two `Configured` runs print `Rules processed: 21, failed: 8, errored: 0`; the failed rules include `Azure.Storage.MinTLS` (AZR-000200) and `Azure.Storage.BlobPublicAccess` (AZR-000198) |
| `Stop-DemoRun.ps1` | exit 0 after 139 s; after teardown `rg-gnp*` groups: 0, resources tagged `project=green-is-not-proof`: 0 |

What differed from the expected output: nothing. No policy of this subscription added an extension, so the ownership
audit showed 4 rows and then 5.

Not covered by this pass: the Portal, the dry run with the Activity Log (rule 3), a Reader-only identity and a teardown
that fails the read-back.

### 2026-11-11, test subscription, `swedencentral`, run `202611111504`, code at `c9a3e9f` (branch of PR #43)

Run by the author from 14:04 to 14:11 UTC on PowerShell 7.6.10. Every command as `pwsh -NoProfile -File <script>`, exit
code from the process. The first two attempts stopped at the cost guard (the price API answered 429 Too Many Requests,
nothing was created); the third ran as below.

| Step | Observed |
| --- | --- |
| `Start-DemoRun.ps1 -Location swedencentral` | exit 0 after 73 s; cost guard 0.293758 EUR for 2 hours |
| `New-RogueResource.ps1` | exit 0 after 60 s |
| Demo 5 before the extension exists, `Show-ExistenceVsState.ps1`, without and with `-ExpectFailed` | exit 1 and exit 1; both print `Existence check: FAIL (extension gnp-failing-script not found). Run New-FailedExtension.ps1 first.` |
| `Get-AzVMExtension -ErrorAction Stop` for the missing extension | `ComputeCloudException`, `ErrorCode: ResourceNotFound`, StatusCode 404, message `The Resource 'Microsoft.Compute/virtualMachines/vm-traffic/extensions/gnp-failing-script' under resource group '<run group>' was not found.` |
| `New-FailedExtension.ps1` | exit 0 after 34 s |
| Demo 5, `Show-ExistenceVsState.ps1` (no flag) | exit 1; `Existence check: PASS`, `State check:     FAIL (ProvisioningState: Failed)` |
| Demo 5, `Show-ExistenceVsState.ps1 -ExpectFailed` | exit 0; the same three lines |
| Demo 1, `-Step Show`, `Delete`, `Recreate`, `Verify`, `List`, `Clean` | each exit 0; Verify: "Demonstration reproduced: diagnostic setting diag-to-log is listed on the NEW account"; Clean: "Removed 1 diagnostic setting(s)" |
| `Stop-DemoRun.ps1` | exit 0 after 197 s; resource group deleted and gone; nothing tagged `runId=202611111504` remains |
| After teardown | `rg-gnp*` groups: 0; resources tagged `project=green-is-not-proof`: 0 |

What differed from the expected output: nothing in demos 1 and 5. The message of a missing extension names the extension
path and `ResourceNotFound`, which is what the not-found check matches.

Not covered by this run: the Portal, a missing-extension case under another Az version, the demo 0 audits, demos 2 to 4,
6 and 7, and a new backup recording of demo 5 (green-is-not-proof#41).

### 2026-11-08, second test subscription, `swedencentral`, run `202611081831`, code at `0571f52` (main after PR #29)

Run by the author from 17:30 to 17:40 UTC, in a subscription of a different directory than the blocks below; the
local demos ran at the end. Every command as `pwsh -NoProfile -File <script>`, exit code from the process; the Azure
scripts ran with an Az context built from the Azure CLI session of the same account.

| Step | Observed |
| --- | --- |
| `Start-DemoRun.ps1 -Location swedencentral` | exit 0 after 65 s; cost guard 0.293758 EUR for 2 hours |
| `New-RogueResource.ps1` | exit 0 after 44 s; `vm-traffic` outside the deployment; auto-shutdown 20:32 UTC |
| Demo 0, `Invoke-TagAudit.ps1` | exit 0; 7 resources, "All 7 resources carry project tags: OK" |
| Demo 0, `Invoke-OwnershipAudit.ps1`, right after the VM | exit 1; 4 rows: VM, NIC, OS disk, shutdown schedule |
| Demo 1, `-Step Show`, `Delete`, `Recreate`, `Verify`, `List`, `Clean` | each exit 0; Show: `diag-to-log` on the account; Verify: "Demonstration reproduced: diagnostic setting diag-to-log is listed on the NEW account"; List: `Diagnostic settings on the NEW account: diag-to-log`; Clean: `Removed 1 diagnostic setting(s)` |
| Demo 3, `Show-LiveProperty.ps1` | exit 0; `PrivateLinkScopedResources: (empty)`, `ProvisioningState: Succeeded`, `Strict health: False` |
| Demo 5, `New-FailedExtension.ps1`, `Show-ExistenceVsState.ps1` | exit 0 after 39 s with `ProvisioningState Failed`; exit 0 with `Existence check: PASS`, `State check:     FAIL (ProvisioningState: Failed)` |
| Demo 0 audits after the extension | tag audit exit 0, 7 resources; ownership audit exit 1 with 6 rows: the four above plus `AzurePolicyforLinux` (installed by a policy of this subscription) and `gnp-failing-script` |
| `Stop-DemoRun.ps1` | exit 0 after 212 s; resource group deleted and gone; nothing tagged `runId=202611081831` remains |
| After teardown | `rg-gnp*` groups: 0; resources tagged `project=green-is-not-proof`: 0; no `out/run.json` |
| Demo 2, `Invoke-Pester ./demos/2-dry-run-is-not-safe -CI -Output Detailed` | process exit 1; `Tests Passed: 1, Failed: 1`; the same command without `-CI`: process exit 0 |
| Demo 4, `Invoke-Gate.ps1` `Silent`/`Empty`, `Counted`/`Empty`, `Fixed`/`Empty`, `Fixed`/`Ok` | runner exit 0, 0, 1, 0; `Process exit code: 0` for the first two |
| Demo 6, `Invoke-Gate.ps1` `Bare`/`Sample`, `Fixed`/`Sample`, `Bare`/`Clean`, `Fixed`/`Clean` | runner exit 0, 1, 0, 0 |
| Demo 7, `Invoke-Gate.ps1` `Bare`/`Misconfigured`, `Fixed`/`Misconfigured`, `Fixed`/`Configured` | runner exit 0 with `Rules evaluated: 0`, 1, 1 with `Rules processed: 21, failed: 8` |

What differed from the expected output: the ownership audit row count depends on time. A policy of this subscription
installs the `AzurePolicyforLinux` extension a few minutes after the VM exists, so the audit shows 4 rows at first and
a further row later (see the note in the demo 0 README).

Notes on the run itself: the first attempt of the demo 2 command in the run script gave exit 64 and then -1, a quoting
mistake of the script and not a test result, and was rerun as above; the script's first teardown count was invalid
(a function shadowed `az`), so the counts above were taken again with the Azure CLI.

Not covered by this run: the Portal, the dry run with the Activity Log (rule 3), a Reader-only identity, a teardown that
fails the read-back, and any region other than `swedencentral`.

### 2026-11-05, local, no Azure, demo 7, code at `a02c3b8` plus demo 7

Run by the author on PowerShell 7.6.9 with PSRule 2.9.0, PSRule.Rules.Azure 1.47.0 and Bicep CLI 0.38.5. Each command
as `pwsh -NoProfile -File <script>`, exit code from the process. The experiment that led to the demo ran the same
modules on small fixtures first.

| Step | Observed |
| --- | --- |
| `Invoke-Gate.ps1 -Gate Bare -Pipeline Misconfigured` | runner exit 0; `[WARN] Target object ... has not been processed because no matching rules were found.`; `Rules processed: 0, failed: 0, errored: 0`; `The gate would PASS although no rule was evaluated.` |
| `Invoke-Gate.ps1 -Gate Fixed -Pipeline Misconfigured` | runner exit 1; `Fixed gate: FAIL` |
| `Invoke-Gate.ps1 -Gate Fixed -Pipeline Configured` | runner exit 1; `Rules processed: 21, failed: 8, errored: 0`; 8 `[FAIL]` rule lines |
| `Invoke-Gate.ps1 -Gate Bare -Pipeline Configured`, first run after a cold start | runner exit 1; PSRule printed `Bicep compilation hasn't completed within the timeout window`; 0 rules processed. A repeat of the same setup in the experiment completed normally the second time |
| Experiment, `Assert-PSRule` on a JSON object that no rule targets | process exit 0 with the warning; with `Execution.UnprocessedObject` `Error` process exit 1; with `Ignore` exit 0 and no warning |
| Experiment, `Execution.UnprocessedObject=Error` on a template without resources, expansion on | process exit 1, `has not been processed`, 0 rules processed; without the option the same template ran 7 deployment rules and exited 0 |

Not covered: other PSRule or rule-set versions, other input types, and a pipeline that uses a different PSRule entry
point (for example the GitHub Action or the Azure DevOps task, which may map warnings to its own status).

### 2026-11-05, test subscription, `swedencentral`, run `202611052136`, code at `99fa8fd` (main after PRs #23 to #25)

The Azure part of the on-stage sequence plus the two checks added by PRs #24 and #25, 20:36 to 20:46 UTC, run by the
author with Azure PowerShell under the account of the test subscription. The demo subscription pin was set for that
process only (`GNP_SUBSCRIPTION_ID`), no configuration file changed. Each step a child `pwsh -NoProfile -File <script>`;
the exit code is the process's own. Row counts of the ownership audits were not captured (the output filter dropped the
rows). Before: 0 `rg-gnp*` groups, 0 tagged resources.

| Step | Exit | Observed |
| --- | --- | --- |
| `Start-DemoRun.ps1 -Location swedencentral` | 0 | cost guard 0,293758 EUR for 2 hours |
| `New-RogueResource.ps1` | 0 | `vm-traffic` created outside the declared deployment; auto-shutdown set |
| Demo 0, `Invoke-TagAudit.ps1` | 0 | "All 7 resources carry project tags: OK" |
| Demo 0, `Invoke-OwnershipAudit.ps1` | 1 (by design) | "Not in the deployment record:" |
| Demo 1, `Show`, `Delete`, `Recreate` | 0 each | account deleted and recreated, no name retry needed |
| Demo 1, `Verify` after `Recreate` (#21) | 0 | `Demonstration reproduced: diagnostic setting diag-to-log is listed on the NEW account` |
| Demo 1, `List`, `Clean` | 0 each | `List`: `Diagnostic settings on the NEW account: diag-to-log`; `Clean`: `Removed 1 diagnostic setting(s)` |
| Demo 1, `Verify` after `Clean` (#21) | 1 (by design) | `Demonstration did not reproduce: ... found: none` |
| Demo 3, `Show-LiveProperty.ps1` | 0 | `PrivateLinkScopedResources: (empty)`, `ProvisioningState: Succeeded`, `Strict health: False` |
| Demo 5, `New-FailedExtension.ps1` | 0 | extension in `Failed` |
| Demo 5, `Show-ExistenceVsState.ps1` | 0 | `Existence check: PASS`; `State check: FAIL (ProvisioningState: Failed)` |
| Demo 0, `Invoke-OwnershipAudit.ps1` after the extension | 1 (by design) | "Not in the deployment record:" |
| `Stop-DemoRun.ps1` (with `run.json`) | 0 | `Removed 0` (`Clean` had removed it); listed again none on 13 resources and sub-services; group deleted; no tagged resources; key pair deleted |
| `Stop-DemoRun.ps1 -RunId 202611050000 -OutDir <scratch dir>` with a `run.json` of run `202611050001` and two dummy key files (#20) | 0 | group not found, skipped; `run.json belongs to another run; kept it and the SSH key pair in out/`; all three files still present afterwards |
| After teardown | | `rg-gnp*` groups: 0; resources tagged `project=green-is-not-proof`: 0 |

Not covered: a teardown after an interrupted demo 1 (see the block of runs `202611041652` and `202611041708`), and a
foreign record next to a teardown that deletes a real group (the #20 check used a run id whose group does not exist).

### 2026-11-04, demo subscription, `swedencentral`, run `202611041758`, code at `04b51f8` (main after PRs #17 and #18)

One run of the Azure part of the on-stage sequence, 16:58 to 17:06 UTC, run by the author. Each step a child
`pwsh -NoProfile -File <script>`; the exit code is the process's own. Row counts of the ownership audits were not
captured (the output filter dropped the rows); the earlier blocks hold them.

| Step | Exit | Observed |
| --- | --- | --- |
| `Start-DemoRun.ps1 -Location swedencentral` | 0 | cost guard 0,293758 EUR for 2 hours |
| `New-RogueResource.ps1` | 0 | `vm-traffic` created outside the declared deployment; auto-shutdown set |
| Demo 0, `Invoke-TagAudit.ps1` | 0 | "All 7 resources carry project tags: OK" |
| Demo 0, `Invoke-OwnershipAudit.ps1` | 1 (by design) | "Not in the deployment record:" with a table of rows |
| Demo 1, `Show`, `Delete`, `Recreate`, `List`, `Clean` | 0 each | `List`: `Diagnostic settings on the NEW account: diag-to-log`; `Clean`: `Removed 1 diagnostic setting(s)` |
| Demo 3, `Show-LiveProperty.ps1` | 0 | `PrivateLinkScopedResources: (empty)`, `ProvisioningState: Succeeded`, `Strict health: False` |
| Demo 5, `New-FailedExtension.ps1` | 0 | `VMExtensionProvisioningError`; extension in `Failed` |
| Demo 5, `Show-ExistenceVsState.ps1` | 0 | `Existence check: PASS`; `State check: FAIL (ProvisioningState: Failed)` |
| Demo 0, `Invoke-OwnershipAudit.ps1` after the extension | 1 (by design) | table with the extension among the rows |
| `Stop-DemoRun.ps1` (with `run.json`) | 0 | `Removed 0` (demo 1 `Clean` had removed it); listed again none on 12 resources and sub-services; group deleted; final line printed; key pair deleted |
| After teardown | | `rg-gnp*` groups: 0; resources tagged `project=green-is-not-proof`: 0 |

Not covered: the teardown after an interrupted demo 1 (see the block of runs `202611041652` and `202611041708`).

### 2026-11-04, local, no Azure, demos 2, 4 and 6, code at `4c73f01` (main after PR #17)

Each command as `pwsh -NoProfile -File <script>`, exit code from the process; demo 2 with `Invoke-Pester -CI`.

| Step | Observed |
| --- | --- |
| Demo 4, `Invoke-Gate.ps1 -Script Silent -State Empty` and `-Script Counted -State Empty` | runner exit 0 each; `Process exit code: 0`; 2 failure lines each; "The gate would PASS although the output shows a failure." |
| Demo 4, `-Script Fixed -State Empty` / `-State Ok` | runner exit 1 with `Process exit code: 1` and 2 failure lines / runner exit 0 with 0 failure lines |
| Demo 6, `Invoke-Gate.ps1 -Gate Bare -Template Sample` / `-Gate Fixed -Template Sample` | runner exit 0, `Bare gate: PASS` with 1 diagnostic line / runner exit 1, `Fixed gate: FAIL` |
| Demo 2, `Invoke-Pester ./demos/2-dry-run-is-not-safe -CI` | process exit 1: 1 passed (fixed script), 1 failed (`Deploy-Example.ps1`), as designed |

### 2026-11-04, demo subscription, `swedencentral`, runs `202611041652` and `202611041708`, branch of PR #17

Each command as `pwsh -NoProfile -File <script>`, exit code from the process (these two runs are the evidence the block
above lacks). Run `202611041652`: setup, demo 1 `Show` and `Delete` (exit 0 each), then `Get-AzDiagnosticSetting` on the
deleted account's blob service.

| Step | Observed |
| --- | --- |
| `Get-AzDiagnosticSetting` on the blob service of the deleted account | error: `Failed to perform 'read' on resource(s) of type 'storageAccounts/blobServices', because the parent resource ... could not be found.` The orphaned setting cannot be listed while the account is gone |
| `Stop-DemoRun.ps1 -RunId 202611041652` (`run.json` moved away), first version of the branch | exit 0; "Could not check" path; `Removed 0`, because the group listing right after the create still lacked the new account (listing lag); group deleted, so the setting was not swept |
| After a fix (the new account's id taken from the create result), run `202611041708`: `Start-DemoRun.ps1`, demo 1 `Show`, `Delete` | each exit 0 |
| `Stop-DemoRun.ps1 -RunId 202611041708` (`run.json` moved away) | exit 0; "Storage stgnp202611041708 from this run is missing; recreating it empty ..."; `Removed 1 diagnostic setting(s)`; `Listed again: no diagnostic settings remain on 7 resource(s) and sub-service(s)`; group deleted; final line printed |
| After both teardowns | `rg-gnp*` groups: 0; resources tagged `project=green-is-not-proof`: 0 |

So a setting orphaned by an interrupted demo 1 is real, and the teardown now removes it by recreating the account empty.

### 2026-11-04, demo subscription, `swedencentral`, run `202611041553`, branch of PR #17 (code at `2f04b4f`)

Run from 15:53 to 15:58 UTC by one driver script (Azure PowerShell signed in with a token of the demo subscription,
process scope, each script called in the same process). The exit codes the driver printed after the first ownership
audit were stale values of the audit's exit 1, so they are not recorded here. This block records what the scripts
printed; the process exit codes of this run are not evidenced. Process exit codes are in the 2026-11-03 blocks.

| Step | Observed |
| --- | --- |
| `Start-DemoRun.ps1`, `New-RogueResource.ps1` | completed; cost guard 0,293758 EUR; auto-shutdown at 17:54 UTC |
| Demo 0, tag audit; ownership audit | "All 7 resources carry project tags: OK"; ownership audit listed 4 rows (disk, VM, schedule, network interface) |
| Demo 1, `Show`, `Delete`, `Recreate`, `List`, `Clean` | `diag-to-log` shown; account deleted; recreated after one "name still held" retry; `Diagnostic settings on the NEW account: diag-to-log`; `Removed 1 diagnostic setting(s)` |
| Demo 3, `Show-LiveProperty.ps1` | `PrivateLinkScopedResources: (empty)`, `ProvisioningState: Succeeded`, `Strict health: False` |
| Demo 5, `New-FailedExtension.ps1` | `VMExtensionProvisioningError`, Azure error code 2 ("command terminated with exit status=1"); extension in `Failed` |
| Demo 5, `Show-ExistenceVsState.ps1` | `Existence check: PASS`; `State check: FAIL (ProvisioningState: Failed)` |
| Ownership audit after the extension | 5 rows, including `Microsoft.Compute/virtualMachines/extensions` |
| `Stop-DemoRun.ps1 -RunId <id>` with `out/run.json` moved away | no `run.json` and the storage account present: no "could not check" line; `Removed 0 diagnostic setting(s)` (demo 1 `Clean` had removed it); listed again none on 12 resources; group deleted; final line printed; key pair deleted |
| After teardown | `rg-gnp*` groups: 0; resources tagged `project=green-is-not-proof`: 0 |

Error texts for a type without diagnostic settings, both from `Get-AzDiagnosticSetting` and both matched by the
teardown: `[ResourceTypeNotSupported] : The resource type 'microsoft.devtestlab/schedules' does not support diagnostic settings.` and
`[ResourceTypeNotSupported] : The resource type 'microsoft.compute/virtualmachines/extensions' does not support diagnostic settings.`
No run produced a `BadRequest`, so the teardown no longer matches it.

Not covered: the "could not check" line (the storage account was present), a diagnostic setting orphaned by an
interrupted demo 1, and process exit codes.

### 2026-11-04, local, no Azure, demo 6, code at `f5aae22` plus demo 6

Run by the author with Bicep CLI 0.38.5 (`bicep lint`); every command as a child `pwsh -NoProfile -File` process, exit code from the process itself.

| Step | Observed |
| --- | --- |
| `Invoke-Gate.ps1 -Gate Bare -Template Sample` | runner exit 0; one `Warning no-unused-params` line; `Process exit code: 0`; `Bare gate: PASS`; "The gate would PASS although the output shows a diagnostic." |
| `-Gate Fixed -Template Sample` | runner exit 1; the same warning line; `Process exit code: 0`; `Fixed gate: FAIL` |
| `-Gate Bare -Template Clean` and `-Gate Fixed -Template Clean` | both runner exit 0; no diagnostic line; no extra line |
| Linter output paths | printed as `.\Sample.bicep(3,7)`; no local path in the output |

`az bicep lint --file` was also run on the same template (before the demo was written): it printed the warning with a `WARNING:` prefix and exited 0. The demo uses `bicep` when it is on the path and `az bicep` otherwise; only the `bicep` route was run through the demo scripts here.

### 2026-11-04, demo subscription, `swedencentral`, run `202611041019`, code at `31fc36f`

Run by the author, about 09:17 to 09:30 UTC. The demo 2 suite is offline; the rest ran in Azure.

| Step | Observed |
| --- | --- |
| Demo 2, `Invoke-Pester ./demos/2-dry-run-is-not-safe -Output Detailed` | 2 tests: 1 failed (`Deploy-Example.ps1`: `line 18: Register-AzResourceProvider`), 1 passed (`Deploy-Example.Fixed.ps1`); process exit 0 without `-CI`, 1 with `-CI` |
| `Start-DemoRun.ps1`, `New-RogueResource.ps1` | both completed without error; cost guard 0,293758 EUR |
| Demo 0, `Invoke-OwnershipAudit.ps1` | exit 1 (by design); 4 rows: VM, network interface, disk, auto-shutdown schedule; the disk's id carries the group name in upper case, as Azure returned it |
| Cheat sheet rule 1 command, as written | the same 4 resources; the deployment's operation list had 6 entries, 1 of them empty; the group held 7 resources |
| `Get-AzDiagnosticSetting` on the auto-shutdown schedule | error `[ResourceTypeNotSupported] : The resource type 'microsoft.devtestlab/schedules' does not support diagnostic settings.` (matched by the teardown's pattern) |
| The same call on the VM and the network interface | no error; 0 settings |
| `Get-AzResourceGroup -Name <missing group>` | error `Provided resource group does not exist.`; with `-ErrorAction SilentlyContinue` it returns null, which is what the teardown relies on, not the text |
| `Stop-DemoRun.ps1 -RunId <id>` with `out/run.json` moved away | completed without error: removed 1 diagnostic setting, listed again none on 11 resources, deleted the group, printed the final line, deleted the key pair; afterwards 0 `rg-gnp*` groups and 0 resources tagged `project=green-is-not-proof` |

Not covered by this run: a diagnostic setting orphaned by an interrupted demo 1, a `run.json` from another run, and the
error text for a VM extension. The teardown also treats `BadRequest` as "type does not support diagnostic settings";
no run here produced a `BadRequest`, so that pattern is unconfirmed (tracked in #4).

### 2026-11-04, demo subscription, rule 3 under a Reader-only identity, run `202611040802`, code at `b3896c0`

Run by the author from 07:02 to about 07:30 UTC. A user-assigned managed identity with Reader on the
run's resource group was attached to the run's VM (`Run Command`, curl, token from the instance metadata endpoint).
The demo script itself was not run as that identity; the same Azure operations were called by REST.

| Step | Observed |
| --- | --- |
| `GET` the resource group | HTTP 200 |
| `POST` `Microsoft.Insights/register` (subscription scope, what the example script calls) | HTTP 403 `AuthorizationFailed` (the first attempt returned 411 because `curl` sent no body; repeated with `Content-Length: 0`) |
| `PATCH` a tag on the resource group (a write inside the Reader scope) | HTTP 403 `AuthorizationFailed` |
| `Get-AzActivityLog -Caller <principal id>`, polled 8 min, then a wider query by time | 0 entries for the identity; 45 entries in total, none a refusal |
| `Stop-DemoRun.ps1` | exit 0; `rg-gnp*` groups: 0; resources tagged `project=green-is-not-proof`: 0; role assignments left for the identity: 0 |

The role assignment was created over REST because the PowerShell cmdlet needed a Microsoft Graph sign-in that the
account did not have in this session.

### 2026-11-03, demo subscription, rule 3 (Activity Log after a dry run), code at `b3896c0`

Run by the author from 22:17 to 22:28 UTC with the author's own account, which can write (not Reader-only).
Both demo 2 example scripts were run for real with `-DryRun`; the only call outside the guard is
`Register-AzResourceProvider -ProviderNamespace Microsoft.Insights` (already `Registered`, so nothing changed).

| Step | Observed |
| --- | --- |
| Both scripts back to back, then `Get-AzActivityLog -Caller <account>` filtered to `Authorization.Action -notlike '*/read'` | 2 entries of `Microsoft.Insights/register/action` (one correlation id), stamped about 6 s after the scripts ended: attribution unclear |
| `Deploy-Example.Fixed.ps1 -DryRun` alone, log queried 4 min later | 0 write operations |
| `Deploy-Example.ps1 -DryRun` alone, log queried 4 min later | 2 write entries of `Microsoft.Insights/register/action`, one correlation id |

`OperationName` was empty on the entries; `Authorization.Action` carried the operation. Entries appeared within
4 minutes after the run; a query right after the run was not tried.

### 2026-11-03, test subscription, `swedencentral`, run `202611032044`, code at `c4b2d8b` plus demos 4 and 5

Run by the author from 19:43 to 19:54 UTC. Demo 4 ran locally; the rest in Azure.

| Step | Observed |
| --- | --- |
| Demo 4, `Invoke-Gate.ps1 -Script Silent -State Empty` | runner exit 0; 2 failure lines; `Process exit code: 0`; "The gate would PASS although the output shows a failure." |
| Demo 4, `-Script Counted -State Empty` | runner exit 0; the child printed 2 failure lines and "Validation complete: 2 failed.", yet `Process exit code: 0` (PowerShell 7.6.9 drops `exit 1` under `#Requires -Modules`) |
| Demo 4, `-Script Fixed -State Empty` / `-State Ok` | runner exit 1 with 2 failure lines / runner exit 0 with 0 failure lines |
| `Start-DemoRun.ps1`, `New-RogueResource.ps1` | exit 0, exit 0; cost guard 0.293758 EUR |
| Demo 0, `Invoke-OwnershipAudit.ps1` | exit 1; 4 rows (VM, NIC, disk, schedule) |
| Demo 5, `New-FailedExtension.ps1` | exit 0 after 37 s; Azure returned `VMExtensionProvisioningError`; extension reached `Failed` |
| Demo 5, `Show-ExistenceVsState.ps1` | exit 0; `Existence check: PASS`, `State check:     FAIL (ProvisioningState: Failed)` |
| Demo 0 audits after the extension | tag audit exit 0 with 7 resources (the extension has no tag); ownership audit exit 1 with 5 rows, including `Microsoft.Compute/virtualMachines/extensions` |
| `Stop-DemoRun.ps1` | exit 0; the extension and the schedule printed `No diagnostic settings supported` and did not stop the teardown; `Removed 1 diagnostic setting(s)` (`diag-to-log`); `Listed again: no diagnostic settings remain on 12 resource(s) and sub-service(s)`; `out/demo_key*` deleted |
| After teardown | `rg-gnp*` groups: 0; resources tagged `project=green-is-not-proof`: 0 |

### 2026-11-03, test subscription, `swedencentral`, run `202611031935`, code at `15907c2`

Run by the author from 18:35 to 18:44 UTC, one run from setup to teardown, every command as
`pwsh -NoProfile -File <script>`. This is the current setup: declared resources from `infra/declared.bicep`, the
rogue VM from a separate script, the teardown with read-back.

| Step | Observed |
| --- | --- |
| `scripts/Start-DemoRun.ps1 -Location swedencentral` | exit 0; cost guard 0.293758 EUR for 2 hours; deployment `declared-202611031935` succeeded |
| `scripts/New-RogueResource.ps1` | exit 0; created `vm-traffic` outside the deployment; auto-shutdown schedule set for 21:36 UTC |
| Demo 0, `Invoke-TagAudit.ps1` | exit 0; 7 resources, "All 7 resources carry project tags: OK" |
| Demo 0, `Invoke-OwnershipAudit.ps1` | exit 1; "Not in the deployment record:" listed `vm-traffic`, `vm-traffic-nic`, its OS disk (named `vm-traffic_disk1_<hex>`) and the schedule `shutdown-computevm-vm-traffic`. So deployment operations did report the resource ids the comparison expects |
| Demo 1, `-Step Show`, `Delete`, `Recreate`, `List`, `Clean` | each exit 0; Show: `diag-to-log` on the account; List: `Diagnostic settings on the NEW account: diag-to-log`; Clean: `Removed 1 diagnostic setting(s)` |
| Demo 3, `Show-LiveProperty.ps1` | exit 0; `PrivateLinkScopedResources: (empty)`, `ProvisioningState: Succeeded`, `Strict health: False` |
| `scripts/Stop-DemoRun.ps1` | exit 0; `Listed again: no diagnostic settings remain on 11 resource(s) and sub-service(s)`; the schedule resource printed `No diagnostic settings supported` and did not stop the teardown; final line: "Resource group rg-gnp-202611031935 gone; no resources tagged runId=202611031935 in the subscription. Not covered: untagged resources outside the group."; `out/demo_key` and `out/demo_key.pub` deleted |
| After teardown | `rg-gnp*` groups in the subscription: 0; resources tagged `project=green-is-not-proof`: 0 |

Not covered by this run: the dry run with the Activity Log (rule 3, see the block above), a teardown that fails the
read-back, a deployment whose record is missing, and any region other than `swedencentral`.

### 2026-11-03, test subscription, `swedencentral`, run `202611031445`, code at `1992109`

Source: the description of PR #2. The earlier setup, which created every resource with `New-Az*` cmdlets and compared
names with a hand-written list. Both have since been replaced; kept for history.

| Step | Observed |
| --- | --- |
| `Start-DemoRun.ps1 -Location swedencentral` | exit 0; cost guard 0.29 EUR; one resource group with the run tags |
| Demo 0, `Invoke-TagAudit.ps1` | exit 0; 6 resources, "OK" |
| Demo 0, `Invoke-OwnershipAudit.ps1` | exit 1; listed `vm-traffic`, `vm-traffic-nic` and its OS disk |
| Demo 1, Show, Delete, Recreate, List, Clean | each exit 0; List printed `Diagnostic settings on the NEW account: diag-to-log`; Clean removed 1 |
| Demo 3, `Show-LiveProperty.ps1` | exit 0; `PrivateLinkScopedResources: (empty)`; strict health False (a lenient verdict was printed too, since removed) |
| Demo 2 | offline: red on `Deploy-Example.ps1`, green on the fixed script |
| `Stop-DemoRun.ps1` | exit 0; "Nothing tagged runId=... remains"; no `rg-gnp*` group left |

## Expected, not yet observed

| Item | Expected result |
| --- | --- |
| Backup recordings of the on-stage demos | demos 0, 1, 2, 4, 5, 6 and 7 made (2026-11-07 and 2026-11-08) |
| A run in the hours before each delivery | add a dated block above |
