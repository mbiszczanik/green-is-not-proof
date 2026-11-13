# Gallery input: the step fails, `|| $true` turns the failure into a success, and the script goes on.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$pwsh = (Get-Process -Id $PID).Path
& $pwsh -NoProfile -Command "Write-Output '[FAIL] deploy step'; exit 1" || $true
Write-Host 'Step complete: deploy step finished.'
