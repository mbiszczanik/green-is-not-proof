#Requires -Modules Pester
# Demo input: the same validator with the exit code set on the host as well as with exit, so it survives the
# #Requires import. A state file that cannot be read counts as a failure, never as success. Run it with Invoke-Gate.ps1.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$StatePath)
Set-StrictMode -Version Latest

$failed = 0
try {
    $state = Get-Content -LiteralPath $StatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    $checks = [ordered]@{
        'Resource group lab-rg exists' = ('lab-rg' -in @($state.resourceGroups))
        'Lock lock-no-delete exists'   = ('lock-no-delete' -in @($state.locks))
    }
    foreach ($name in $checks.Keys) {
        if ($checks[$name]) { Write-Host "[ OK ] $name" } else { Write-Host "[FAIL] $name"; $failed++ }
    }
}
catch {
    Write-Host "[FAIL] State could not be read: $($_.Exception.Message)"
    $failed++
}
Write-Host "Validation complete: $failed failed."
$code = if ($failed -gt 0) { 1 } else { 0 }
$Host.SetShouldExit($code)
exit $code
