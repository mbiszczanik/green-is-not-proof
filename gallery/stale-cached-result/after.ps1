# Gallery input: the same check compares the file's timestamp with the limit and exits 1 on a stale result.
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

$age = [datetime]::UtcNow - (Get-Item -LiteralPath $resultFile).LastWriteTimeUtc
if ($age -gt $maxAge) {
    Write-Host "[FAIL] the result is $([int]$age.TotalHours) hours old, the limit is $([int]$maxAge.TotalHours) hour."
    exit 1
}
$status = (Get-Content -LiteralPath $resultFile -Raw).Trim()
if ($status -eq 'ok') {
    Write-Host "Check passed: the last run reported $status."
}
