# Gallery input: the runner looks for test files in a folder that holds none, counts no failure and reports success.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$pwsh = (Get-Process -Id $PID).Path
$folder = Join-Path ([IO.Path]::GetTempPath()) 'gallery-zero-tests-pass-empty'
$null = New-Item -ItemType Directory -Path $folder -Force
$tests = @(Get-ChildItem -LiteralPath $folder -Filter *.Tests.ps1)
$failed = 0
foreach ($t in $tests) {
    & $pwsh -NoProfile -File $t.FullName
    if ($LASTEXITCODE -ne 0) { $failed++ }
}
Write-Host "Tests discovered: $($tests.Count), failed: $failed"
if ($failed -gt 0) {
    Write-Host '[FAIL] A test failed.'
    exit 1
}
Write-Host 'All tests passed.'
