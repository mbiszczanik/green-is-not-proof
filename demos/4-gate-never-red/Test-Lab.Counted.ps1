#Requires -Modules Pester
# Demo input: counts failures and calls exit 1, yet under `pwsh -File` the process exits 0, because the #Requires
# line makes PowerShell import a module and the host drops the exit code (SkyCraft PR 109). Run it with Invoke-Gate.ps1.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$StatePath)
Set-StrictMode -Version Latest

$state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
$checks = [ordered]@{
    'Resource group lab-rg exists' = ('lab-rg' -in @($state.resourceGroups))
    'Lock lock-no-delete exists'   = ('lock-no-delete' -in @($state.locks))
}
$failed = 0
foreach ($name in $checks.Keys) {
    if ($checks[$name]) { Write-Host "[ OK ] $name" } else { Write-Host "[FAIL] $name"; $failed++ }
}
Write-Host "Validation complete: $failed failed."
exit $(if ($failed -gt 0) { 1 } else { 0 })
