# Demo 0: a tag is not proof of ownership

A tag-based audit reports green while a VM the code never created sits in the resource group.
The ownership audit compares the group's inventory with what the code declares and flags it.

Prerequisite: `./scripts/Start-DemoRun.ps1` has run (it writes `out/run.json` and creates the rogue VM
`vm-traffic`, which is absent from `config/demo-manifest.psd1` on purpose).

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

   All 6 resources carry project tags: OK
   ```

2. Run the ownership audit. It lists the whole resource group, tagged or not, and compares it with the names in the manifest:

   ```powershell
   ./demos/0-tag-is-not-ownership/Invoke-OwnershipAudit.ps1
   ```

   Expected shape (exit code 1):

   ```text
   Not declared in code:
   Name                         ResourceType                     Id
   ----                         ------------                     --
   vm-traffic                   Microsoft.Compute/virtualMachines /subscriptions/<sub>/resourceGroups/rg-gnp-.../vm-traffic
   vm-traffic-nic               Microsoft.Network/networkInterfaces ...
   vm-traffic_OsDisk_1_<hex>    Microsoft.Compute/disks          ...
   ```

3. State the rule: **A tag is a declaration; the code-derived inventory is proof.**
   Whoever created the VM could copy the tags. Only the comparison with the code shows it was never declared.

Both scripts accept `-RunId` (otherwise they read `out/run.json`) and `-OutDir`. The subscription id is masked in output.

## Further reading

SkyCraft's full audit is the complete version of this idea:
[`scripts/Invoke-ResourceAudit.ps1`](https://github.com/mbiszczanik/skycraft) in the SkyCraft repository.
