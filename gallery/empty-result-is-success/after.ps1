# Gallery input: the same check; an empty list is a failure, because nothing was checked.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

# Stands in for a read the caller may not make: it returns nothing and raises no error.
function Get-StorageAccountList { @() }

$accounts = @(Get-StorageAccountList)
if ($accounts.Count -eq 0) {
    Write-Host '[FAIL] The read returned nothing: zero storage accounts were checked, so nothing passed.'
    exit 1
}
$bad = @($accounts | Where-Object { -not $_.HttpsOnly })
if ($bad.Count -gt 0) {
    Write-Host "[FAIL] $($bad.Count) storage account(s) allow HTTP."
    exit 1
}
Write-Host 'Check passed: no storage account allows HTTP.'
