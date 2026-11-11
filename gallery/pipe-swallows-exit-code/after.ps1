# Gallery input: the same inner command and pipe; the exit code is read right after the pipeline and passed on.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$pwsh = (Get-Process -Id $PID).Path
& $pwsh -NoProfile -Command "Write-Output '[FAIL] inner check'; exit 1" | Tee-Object -Variable captured
# Saved first: the next native command would overwrite it.
$code = $LASTEXITCODE
Write-Host "Step complete: $(@($captured).Count) line(s) captured."
if ($code -ne 0) {
    Write-Host "Inner command failed with exit code $code."
    exit $code
}
