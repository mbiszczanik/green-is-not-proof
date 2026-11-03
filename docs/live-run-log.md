# Live run log

What was observed in Azure, and what is only expected. A line says "observed" only with a date, a command and an
exit code. Everything else is an expected result and must not be presented as an observed fact.

Run the full sequence once before each delivery and add a block below: what ran, when, with which command and
exit code, and what differed from the expected output. Keep the subscription id, tenant and account names out of
this file; name them by role.

## Observed

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

Not covered by this run: the Reader-only dry run with the Activity Log (rule 3), a teardown that fails the
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
| Demo 2 on-stage suite, current code | red on `Deploy-Example.ps1`, green on the fixed script (last observed at `1992109`, before the verb allow list) |
| Cheat sheet rule 1 command as written | lists the same resources as the ownership audit |
| Cheat sheet rule 3 command (Reader-only dry run, Activity Log) | no write operations for a correct dry run; the command is a sketch and has not been run |
| Backup recordings of the on-stage demos | not made |
| A run in the hours before each delivery | add a dated block above |
