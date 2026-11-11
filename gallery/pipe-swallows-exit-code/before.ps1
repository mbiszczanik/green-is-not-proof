# Gallery input: the inner command fails, its output goes through a pipe, and nobody reads its exit code.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$pwsh = (Get-Process -Id $PID).Path
& $pwsh -NoProfile -Command "Write-Output '[FAIL] inner check'; exit 1" | Tee-Object -Variable captured
Write-Host "Step complete: $(@($captured).Count) line(s) captured."
