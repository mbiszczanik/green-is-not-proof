# Gallery input: a wait loop for an approval that never comes; when the time limit passes it proceeds as if the answer were yes.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$approvalFile = Join-Path ([IO.Path]::GetTempPath()) 'gallery-timeout-as-approval-approved.txt'
if (Test-Path -LiteralPath $approvalFile) { Remove-Item -LiteralPath $approvalFile }
$approved = $false
$deadline = [datetime]::UtcNow.AddSeconds(2)
while ([datetime]::UtcNow -lt $deadline) {
    if (Test-Path -LiteralPath $approvalFile) { $approved = $true; break }
    Start-Sleep -Milliseconds 200
}
Write-Host "Waited for approval (answered: $approved)."
Write-Host 'Step complete: change approved and applied.'
