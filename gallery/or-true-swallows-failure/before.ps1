# Gallery input: a failing step followed by `|| $true`, so the script carries on and exits 0.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$pwshPath = (Get-Process -Id $PID).Path
& $pwshPath -NoProfile -Command 'Write-Host "error: input file not found"; exit 1' || $true
Write-Host 'Step complete: build finished.'
