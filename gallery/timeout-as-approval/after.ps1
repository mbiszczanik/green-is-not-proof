# Gallery input: the same loop; when the time limit passes without an answer, that is said and the process exits 1.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$answer = Join-Path ([IO.Path]::GetTempPath()) 'gallery-timeout-as-approval-missing/approved.txt'
$limitSeconds = 2
$deadline = [datetime]::UtcNow.AddSeconds($limitSeconds)
while (-not (Test-Path -LiteralPath $answer) -and [datetime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 200 }
if (-not (Test-Path -LiteralPath $answer)) {
    Write-Host "[FAIL] No answer arrived within $limitSeconds seconds: a timeout is not an approval."
    exit 1
}
Write-Host 'Approval wait finished. Proceeding with the change.'
