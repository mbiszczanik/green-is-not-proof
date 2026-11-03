# Demo 0: a tag is not proof of ownership

A tag-based audit reports green while a VM the code never created sits in the resource group.
The ownership audit compares the group's full inventory with the deployment record, the list Azure wrote of what
the declared code deployed, and flags it.

The rule: a tag is a declaration. Evidence: the group's full inventory compared with the deployment record.

Prerequisites:

1. `./scripts/Start-DemoRun.ps1` has run. It deploys `infra/declared.bicep` as one deployment named
   `declared-<runId>` and writes `out/run.json`.
2. `./scripts/New-RogueResource.ps1` has run. It creates the VM `vm-traffic`, its NIC and its auto-shutdown schedule
   with the run's tags copied on, outside that deployment, the way a resource made by hand or by another pipeline
   would appear.

Run demo 0 before demo 1: demo 1 recreates the storage account outside the deployment, and the audit would then
flag it too.

## On-stage sequence

1. Run the tag audit. It asks Azure for everything tagged `project=green-is-not-proof` and passes:

   ```powershell
   ./demos/0-tag-is-not-ownership/Invoke-TagAudit.ps1
   ```

   Expected shape (exit code 0):

   ```text
   Name                       ResourceType
   ----                       ------------
   vnet-gnp                   Microsoft.Network/virtualNetworks
   vm-traffic                 Microsoft.Compute/virtualMachines
   ...

   All 7 resources carry project tags: OK
   ```

2. Run the ownership audit. It lists the whole resource group, tagged or not, and compares each resource id with
   the target resources of the `declared-<runId>` deployment operations:

   ```powershell
   ./demos/0-tag-is-not-ownership/Invoke-OwnershipAudit.ps1
   ```

   Expected shape (exit code 1):

   ```text
   Not in the deployment record:
   Name                         ResourceType                     Id
   ----                         ------------                     --
   vm-traffic                   Microsoft.Compute/virtualMachines /subscriptions/<sub>/resourceGroups/rg-gnp-.../vm-traffic
   vm-traffic-nic               Microsoft.Network/networkInterfaces ...
   vm-traffic_OsDisk_1_<hex>    Microsoft.Compute/disks          ...
   shutdown-computevm-vm-traffic Microsoft.DevTestLab/schedules  ...
   ```

   If the deployment record is missing or did not succeed, the audit exits 1 and names the record instead of
   reporting anything as declared or undeclared.

3. State the rule. Whoever created the VM could copy the tags. Only the record Azure wrote when the code deployed
   shows it was never declared.

Both scripts accept `-RunId` (otherwise they read `out/run.json`) and `-OutDir`. The subscription id is masked in output.

## Further reading

SkyCraft's full audit is the complete version of this idea:
[`scripts/Invoke-ResourceAudit.ps1`](https://github.com/mbiszczanik/skycraft) in the SkyCraft repository.
