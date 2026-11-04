# Live run log

What was observed in Azure, and what is only expected. A line says "observed" only with a date, a command and an
exit code. Everything else is an expected result and must not be presented as an observed fact.

Run the full sequence once before each delivery and add a block below: what ran, when, with which command and
exit code, and what differed from the expected output. Keep the subscription id, tenant and account names out of
this file; name them by role.

## Observed

### 2026-11-04, demo subscription, `swedencentral`, run `202611041019`, code at `31fc36f`

Run by the author's agent session, about 09:17 to 09:30 UTC. The demo 2 suite is offline; the rest ran in Azure.

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

Run by the author's agent session from 07:02 to about 07:30 UTC. A user-assigned managed identity with Reader on the
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

Run by the author's agent session from 22:17 to 22:28 UTC with the author's own account, which can write (not Reader-only).
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

Run by the author's agent session from 19:43 to 19:54 UTC. Demo 4 ran locally; the rest in Azure.

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

Run by the author's agent session from 18:35 to 18:44 UTC, one run from setup to teardown, every command as
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
| Backup recordings of the on-stage demos | not made |
| A run in the hours before each delivery | add a dated block above |
