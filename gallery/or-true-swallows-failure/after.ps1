# Gallery input: the same step without `|| $true`; its exit code is read and the process exits 1.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$pwsh = (Get-Process -Id $PID).Path
& $pwsh -NoProfile -Command "Write-Output '[FAIL] deploy step'; exit 1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Deploy step failed with exit code $LASTEXITCODE."
    exit 1
}
Write-Host 'Step complete: deploy step finished.'
