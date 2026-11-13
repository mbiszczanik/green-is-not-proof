# Gallery input: the same step without `|| $true`; its exit code is checked, the failure is printed and the process exits 1.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$pwshPath = (Get-Process -Id $PID).Path
& $pwshPath -NoProfile -Command 'Write-Host "error: input file not found"; exit 1'
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] the step exited with code $LASTEXITCODE."
    exit 1
}
Write-Host 'Step complete: build finished.'
