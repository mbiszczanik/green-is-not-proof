# Gallery input: the same check; a missing value is a failure, so the comparison never runs on nothing.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$report = @{ job = 'nightly-backup' }
$limit = 5
$actual = $report['failedItems']
if ($null -eq $actual) {
    Write-Host '[FAIL] failedItems is missing from the report: the value was not compared.'
    exit 1
}
if ($actual -le $limit) {
    Write-Host "Check passed: failed items within the limit of $limit."
    exit 0
}
Write-Host "[FAIL] Failed items ($actual) above the limit of $limit."
exit 1
