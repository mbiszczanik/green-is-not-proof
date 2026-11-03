# Green is not proof: cheat sheet

A green check is what a system says about itself. A better check reads back from a source independent of the thing
being checked. Even then it settles one specific question, in one configuration, at one moment.

Before trusting any green, ask: **What would this show if it did not work?**

Each rule below says what the stronger check confirms and what it does not settle. Commands marked *sketch* have
not been run against Azure in this form yet; see [live-run-log.md](live-run-log.md).

## 1. A tag is a declaration

Stronger check: the group's full inventory compared with the deployment record.

```powershell
$declared = (Get-AzResourceGroupDeploymentOperation -ResourceGroupName $rg -DeploymentName $name).TargetResource
Get-AzResource -ResourceGroupName $rg | Where-Object ResourceId -notin $declared
```

*Sketch.* It finds resources that the deployment did not touch. It does not settle who created a resource that is in
the record: an incremental deployment can update a resource that already existed. A matching name or id is not
proof of origin.

## 2. A successful delete is a declaration

Stronger check: listing the non-cascaded child resources, read back after the delete.

```powershell
Get-AzDiagnosticSetting -ResourceId "$($storage.Id)/blobServices/default"
```

Observed on 2026-11-03 (earlier setup): after deleting and recreating the account with the same name, the old
setting was listed on the new account. It settles that one child type is left behind; other child types need
their own listing.

## 3. A dry-run switch is a declaration

Stronger check: run the dry run, then list the write operations the Activity Log recorded for the caller. Under a
Reader-only identity Azure also refuses the write; under a wider identity the write happens and the log only shows it.

```powershell
Get-AzActivityLog -StartTime $start -Caller $caller |
    Where-Object { $_.Authorization.Action -notlike '*/read' } |
    ForEach-Object { $_.Authorization.Action }
```

Observed 2026-11-03 (demo subscription, an account that can write, not Reader-only): the demo 2 example with
`-DryRun` left two entries of one operation, `Microsoft.Insights/register/action`; the fixed example left none. Allow
a few minutes for the log, start the window a few seconds before the run, and filter on `Authorization.Action`
(`OperationName` came back empty). The Reader-only refusal was not tested.

The syntax-tree test (`[System.Management.Automation.Language.Parser]::ParseFile`) is a fast pre-check: it
finds specific Az calls outside the guard. It does not settle that the whole script is safe, and it does not see az
CLI or REST calls. The Activity Log shows what one run did under one input.

## 4. A stubbed test is a declaration

Stronger check: the same assertion against one live read of the real resource.

```powershell
Get-AzOperationalInsightsWorkspace -ResourceGroupName $rg -Name $name | Format-List *
```

The stubbed test still checks your program's logic. The live read shows what the real service returned for this
resource, in this configuration, at this moment; it does not show what it returns elsewhere.

## Source

Demos, tests and the full write-up: <https://github.com/mbiszczanik/green-is-not-proof>
