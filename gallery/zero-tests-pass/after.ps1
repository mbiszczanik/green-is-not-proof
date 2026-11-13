# Gallery input: the same runner treats zero discovered test files as a failure and exits 1.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$testDir = Join-Path ([IO.Path]::GetTempPath()) 'gallery-zero-tests-pass-empty'
New-Item -ItemType Directory -Force -Path $testDir | Out-Null
$found = @(Get-ChildItem -LiteralPath $testDir -Filter '*.Tests.ps1' -File)
Write-Host "Discovered $($found.Count) test files."
if ($found.Count -eq 0) {
    Write-Host '[FAIL] no test files were discovered, so nothing was tested.'
    exit 1
}
Write-Host 'All discovered tests passed.'
