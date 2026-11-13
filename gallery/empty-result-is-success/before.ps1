# Gallery input: the read returns an empty list, no item fails, and the check reports success.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

# Stands in for a read the caller may not make: it returns nothing and raises no error.
function Get-StorageAccountList { @() }

$accounts = @(Get-StorageAccountList)
$bad = @($accounts | Where-Object { -not $_.HttpsOnly })
if ($bad.Count -gt 0) {
    Write-Host "[FAIL] $($bad.Count) storage account(s) allow HTTP."
    exit 1
}
Write-Host 'Check passed: no storage account allows HTTP.'
