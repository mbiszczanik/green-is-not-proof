# Green is not proof: cheat sheet

A green check is what a system says about itself. Evidence is what you read back from a source independent of
the thing being checked.

Before trusting any green, ask: **What would this show if it did not work?**

## 1. A tag is a declaration

Evidence: the group's full inventory compared with the deployment record.

```powershell
$declared = (Get-AzResourceGroupDeploymentOperation -ResourceGroupName $rg -DeploymentName $name).TargetResource
Get-AzResource -ResourceGroupName $rg | Where-Object ResourceId -notin $declared
```

Anyone can copy a tag. The deployment record is written by Azure when the code deploys, so a resource missing from
it was not created by that code.

## 2. A successful delete is a declaration

Evidence: listing the non-cascaded child resources, read back after the delete.

```powershell
Get-AzDiagnosticSetting -ResourceId "$($storage.Id)/blobServices/default"
```

A diagnostic setting is its own resource: after deleting and recreating the account with the same name, run this on
the new account.

## 3. A dry-run switch is a declaration

Evidence: a dry run under a Reader-only identity, with zero write operations in the Activity Log.

```powershell
Get-AzActivityLog -StartTime $start -Caller $readerId | Where-Object { $_.Authorization.Action -notlike '*/read' }
```

The syntax-tree test (`[System.Management.Automation.Language.Parser]::ParseFile`) is a fast pre-check that every
mutating call sits behind the guard. It is not evidence that nothing mutated.

## 4. A stubbed test is a declaration

Evidence: the same assertion against one live read of the real resource.

```powershell
Get-AzOperationalInsightsWorkspace -ResourceGroupName $rg -Name $name | Format-List *
```

A test with a hand-written object proves only what you assumed the API returns.

## Source

Demos, tests and the full write-up: <https://github.com/mbiszczanik/green-is-not-proof>
