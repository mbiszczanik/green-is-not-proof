# Gallery input: the same check fails first when the list is empty, says the read returned nothing and exits 1.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

function Get-Finding { @() }
$findings = @(Get-Finding)
if ($findings.Count -eq 0) {
    Write-Host '[FAIL] the read returned nothing, so nothing was checked.'
    exit 1
}
$bad = @($findings | Where-Object { $_.Status -ne 'Compliant' })
if ($bad.Count -eq 0) {
    Write-Host 'Check passed: no non-compliant resources found.'
}
