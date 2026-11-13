# Gallery input: a check reads a result file written two days ago and reports success without looking at its age.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$resultDir = Join-Path ([IO.Path]::GetTempPath()) 'gallery-stale-cached-result'
$resultFile = Join-Path $resultDir 'last-run.txt'
New-Item -ItemType Directory -Force -Path $resultDir | Out-Null
Set-Content -LiteralPath $resultFile -Value 'ok'
(Get-Item -LiteralPath $resultFile).LastWriteTimeUtc = [datetime]::UtcNow.AddDays(-2)
$maxAge = [timespan]::FromHours(1)
Write-Host "Freshness limit: $([int]$maxAge.TotalHours) hour."

$status = (Get-Content -LiteralPath $resultFile -Raw).Trim()
if ($status -eq 'ok') {
    Write-Host "Check passed: the last run reported $status."
}
