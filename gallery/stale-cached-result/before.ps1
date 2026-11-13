# Gallery input: the check reads a result file written two days ago and reports it as the result of this run.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

# Stands in for an earlier run: a result file whose timestamp is two days old.
$path = Join-Path ([IO.Path]::GetTempPath()) 'gallery-stale-cached-result/result.json'
$null = New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force
'{ "status": "passed" }' | Set-Content -LiteralPath $path
(Get-Item -LiteralPath $path).LastWriteTimeUtc = [datetime]::UtcNow.AddDays(-2)

$result = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
if ($result.status -eq 'passed') {
    Write-Host 'Check passed: the result file says passed.'
    exit 0
}
Write-Host "[FAIL] The result file says $($result.status)."
exit 1
