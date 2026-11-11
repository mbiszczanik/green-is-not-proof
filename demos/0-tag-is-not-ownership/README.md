# Demo 0: a tag is not proof of ownership

A tag-based audit reports green while a VM the declared deployment never created sits in the resource group. The
ownership audit lists the resources in the group that are absent from the deployment record, the list Azure wrote of
what `infra/declared.bicep` deployed.

The rule: a tag is a declaration. The stronger check is the group's full inventory compared with the deployment record.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| Tag audit | that resources carry the project tags | who created them: anyone can copy a tag |
| Ownership audit | which resources in the group the deployment record does not list | who created a resource that is listed (an incremental deployment can update a resource that already existed), who created an unlisted one, or whether it is unwanted |

Detecting a resource outside the record is a finding to investigate, not a verdict on origin. A matching name or id
does not confirm who created a resource.

Prerequisites:

1. `./scripts/Start-DemoRun.ps1` has run. It deploys `infra/declared.bicep` as one deployment named
   `declared-<runId>` and writes `out/run.json`.
2. `./scripts/New-RogueResource.ps1` has run. It creates the VM `vm-traffic`, its NIC and its auto-shutdown schedule
   with the run's tags copied on, outside that deployment, the way a resource made by hand or by another pipeline
   would appear.

Run demo 0 before demo 1: demo 1 recreates the storage account outside the deployment, and the audit would then
flag it too.

## Results

- **Observed 2026-11-03**, earlier setup (the audit compared names with a hand-written list, code at `1992109`,
  recorded in PR #2): tag audit exit 0 with 6 resources; ownership audit exit 1, listing `vm-traffic`,
  `vm-traffic-nic` and its OS disk.
- **Observed 2026-11-03**, current setup (run `202611031935`, code at `15907c2`, see
  [docs/live-run-log.md](../../docs/live-run-log.md)): tag audit exit 0 with 7 resources; ownership audit exit 1,
  listing `vm-traffic`, `vm-traffic-nic`, the OS disk and the shutdown schedule. The target resources of the
  deployment operations were the resource ids the comparison expects.
- **Observed 2026-11-08**, the newest full run (run `202611081831`, code at `0571f52`, a subscription with a policy
  that installs the Guest Configuration extension): tag audit exit 0 with 7 resources; ownership audit exit 1 with 4
  rows right after the VM (VM, NIC, OS disk, shutdown schedule) and with 6 rows after the demo 5 extension.
- Run it again before each delivery and add a dated block to the log.

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

   What it confirms: the tags are there. What it does not settle: who created the resources.

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
   vm-traffic_disk1_<hex>      Microsoft.Compute/disks          ...
   shutdown-computevm-vm-traffic Microsoft.DevTestLab/schedules  ...
   ```

   The row count depends on the subscription and on time. If a policy installs the Guest Configuration extension, an
   extra row `vm-traffic/AzurePolicyforLinux` (`Microsoft.Compute/virtualMachines/extensions`) appears a few minutes
   after the VM exists: observed 2026-11-08, 4 rows right after `New-RogueResource.ps1` and 5 later. Run the audit once
   before the talk and expect that row; it is not in the deployment record either, and it does not weaken the point.

   If the deployment record is missing or did not succeed, the audit exits 1 and names the record instead of
   reporting anything as declared or undeclared.

3. State what the comparison does: it detects resources the deployment record does not list. It does not say who
   made them, and a green tag audit never could.

Both scripts accept `-RunId` (otherwise they read `out/run.json`) and `-OutDir`. The subscription id is masked in output.

## Further reading

SkyCraft's full audit is the complete version of this idea:
[`scripts/Invoke-ResourceAudit.ps1`](https://github.com/mbiszczanik/skycraft) in the SkyCraft repository.
