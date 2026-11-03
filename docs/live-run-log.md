# Live run log

What was observed in Azure, and what is only expected. A line says "observed" only with a date, a command and an
exit code. Everything else is an expected result and must not be presented as an observed fact.

Run the full sequence once before each delivery and add a block below: what ran, when, with which command and
exit code, and what differed from the expected output. Keep the subscription id, tenant and account names out of
this file; name them by role.

## Observed

### 2026-11-03, test subscription, `swedencentral`, run `202611031445`, code at `1992109`

Source: the description of PR #2. This was the setup that created every resource with `New-Az*` cmdlets and the
ownership audit that compared names with a hand-written list. Both have since been replaced.

| Step | Observed |
| --- | --- |
| `Start-DemoRun.ps1 -Location swedencentral` | exit 0; cost guard 0.29 EUR; one resource group with the run tags |
| Demo 0, `Invoke-TagAudit.ps1` | exit 0; 6 resources, "OK" |
| Demo 0, `Invoke-OwnershipAudit.ps1` | exit 1; listed `vm-traffic`, `vm-traffic-nic` and its OS disk |
| Demo 1, Show, Delete, Recreate, List, Clean | each exit 0; List printed `Diagnostic settings on the NEW account: diag-to-log`; Clean removed 1 |
| Demo 3, `Show-LiveProperty.ps1` | exit 0; `PrivateLinkScopedResources: (empty)`; strict health False (the run also printed a lenient verdict, since removed) |
| Demo 2 | offline: red on `Deploy-Example.ps1`, green on the fixed script |
| `Stop-DemoRun.ps1` | exit 0; "Nothing tagged runId=... remains"; no `rg-gnp*` group left |

## Expected, not yet observed

| Item | Expected result |
| --- | --- |
| `Start-DemoRun.ps1`, current form | exit 0; deployment `declared-<runId>` Succeeded (needs the Bicep CLI on PATH and the subscription's policy to accept the template) |
| `New-RogueResource.ps1` | exit 0; VM, NIC and auto-shutdown schedule `shutdown-computevm-vm-traffic` created |
| Demo 0, `Invoke-TagAudit.ps1` | exit 0; 7 resources |
| Demo 0, `Invoke-OwnershipAudit.ps1` | exit 1; lists the VM, its NIC, its OS disk and the schedule; needs confirming that deployment operations report the resource ids the comparison expects |
| Demo 1 on the Bicep-deployed account | same output as observed above |
| Demo 3, `Show-LiveProperty.ps1`, current workspace | `PrivateLinkScopedResources: (empty)`, `ProvisioningState: Succeeded`, `Strict health: False` |
| `Stop-DemoRun.ps1`, current form | exit 0; "Listed again: no diagnostic settings remain ..."; final line names what was and was not checked; `out/demo_key*` deleted. Needs confirming that listing diagnostic settings on the schedule resource does not error |
| Cheat sheet rule 1 and rule 3 commands | not run in this form |
| Backup recordings of the on-stage demos | not made |
