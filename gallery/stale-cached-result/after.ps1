# Gallery input: the same check; the age of the result file is compared with a limit first, and a stale result exits 1.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

# Stands in for an earlier run: a result file whose timestamp is two days old.
$path = Join-Path ([IO.Path]::GetTempPath()) 'gallery-stale-cached-result/result.json'
$null = New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force
'{ "status": "passed" }' | Set-Content -LiteralPath $path
(Get-Item -LiteralPath $path).LastWriteTimeUtc = [datetime]::UtcNow.AddDays(-2)

$limitHours = 24
$ageHours = [math]::Floor(([datetime]::UtcNow - (Get-Item -LiteralPath $path).LastWriteTimeUtc).TotalHours)
if ($ageHours -ge $limitHours) {
    Write-Host "[FAIL] The result file is $ageHours hours old (limit $limitHours hours): stale, so it is not the result of this run."
    exit 1
}
$result = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
if ($result.status -eq 'passed') {
    Write-Host 'Check passed: the result file says passed.'
    exit 0
}
Write-Host "[FAIL] The result file says $($result.status)."
exit 1
