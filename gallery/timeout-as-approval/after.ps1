# Gallery input: the same loop treats the time limit as no answer, prints the failure and exits 1.
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
if (-not $approved) {
    Write-Host '[FAIL] no answer arrived before the time limit, so the change was not approved.'
    exit 1
}
Write-Host 'Step complete: change approved and applied.'
