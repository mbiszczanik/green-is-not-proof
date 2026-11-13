# Gallery input: a check over a stub that returns an empty list, as a denied read would, and prints success because nothing failed.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

function Get-Finding { @() }
$findings = @(Get-Finding)
$bad = @($findings | Where-Object { $_.Status -ne 'Compliant' })
if ($bad.Count -eq 0) {
    Write-Host 'Check passed: no non-compliant resources found.'
}
