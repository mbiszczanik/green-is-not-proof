# Gallery input: the same runner; zero discovered tests is a failure, so the process exits 1.
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
if ($tests.Count -eq 0) {
    Write-Host '[FAIL] No test was discovered: nothing ran, so nothing passed.'
    exit 1
}
if ($failed -gt 0) {
    Write-Host '[FAIL] A test failed.'
    exit 1
}
Write-Host 'All tests passed.'
