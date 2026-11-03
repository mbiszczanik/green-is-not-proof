# Green is not proof: cheat sheet

A green check is what a system says about itself. Proof is what you read back from somewhere else.

## 1. A tag is a declaration; a code-derived inventory is proof

```powershell
Get-AzResource -ResourceGroupName $rg | Where-Object Name -notin $declaredNames
```

Anyone can copy a tag, so list the whole group and compare it with `$declaredNames`, taken from the code (the manifest).

## 2. A successful delete is a declaration; listing the non-cascaded children is proof

```powershell
Get-AzDiagnosticSetting -ResourceId "$($storage.Id)/blobServices/default"
```

A diagnostic setting is its own resource: after deleting and recreating the account with the same name, run this on the new account.

## 3. A dry-run switch is a declaration; a syntax-tree test is proof

```powershell
[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)
```

Parse the script and check every mutating call sits behind the guard, instead of running it to see.

## 4. A stubbed test is a declaration; one live read is proof

```powershell
Get-AzOperationalInsightsWorkspace -ResourceGroupName $rg -Name $name | Format-List *
```

A test with a hand-written object proves only what you assumed, so read the real resource once.

## Source

Demos, tests and the full write-up: <https://github.com/mbiszczanik/green-is-not-proof>
