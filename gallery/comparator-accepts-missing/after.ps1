# Gallery input: the same check fails first when the value is missing, says so and exits 1.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$limit = 200
$reading = @{ cpuPercent = 40 }
$actual = $reading['latencyMs']
if ($null -eq $actual) {
    Write-Host '[FAIL] the value latencyMs was missing, so it was not compared with the limit.'
    exit 1
}
if ($actual -le $limit) {
    Write-Host "Check passed: latency is within the limit of $limit ms."
}
