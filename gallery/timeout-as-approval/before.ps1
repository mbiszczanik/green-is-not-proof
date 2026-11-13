# Gallery input: the loop waits for an approval, the time limit passes, and the script goes on as though the answer were yes.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$answer = Join-Path ([IO.Path]::GetTempPath()) 'gallery-timeout-as-approval-missing/approved.txt'
$limitSeconds = 2
$deadline = [datetime]::UtcNow.AddSeconds($limitSeconds)
while (-not (Test-Path -LiteralPath $answer) -and [datetime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 200 }
Write-Host 'Approval wait finished. Proceeding with the change.'
