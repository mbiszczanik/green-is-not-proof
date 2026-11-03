# Demo input: a validator that prints [FAIL] and never sets an exit code. Run it with Invoke-Gate.ps1.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$StatePath)
Set-StrictMode -Version Latest

$state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
$checks = [ordered]@{
    'Resource group lab-rg exists' = ('lab-rg' -in @($state.resourceGroups))
    'Lock lock-no-delete exists'   = ('lock-no-delete' -in @($state.locks))
}
foreach ($name in $checks.Keys) {
    if ($checks[$name]) { Write-Host "[ OK ] $name" } else { Write-Host "[FAIL] $name" }
}
Write-Host 'Validation complete.'
