# Gallery input: a Pester test whose mock answers 'Succeeded' for every input, so it passes whatever the code does.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
Import-Module Pester -MinimumVersion 5.5

$container = New-PesterContainer -ScriptBlock {
    BeforeAll {
        function Get-DeploymentState {
            param([string]$Name)
            throw "No real read of '$Name' is made in this demo."
        }
        function Test-Deployment {
            param([string]$Name)
            $state = Get-DeploymentState -Name $Name
            # The defect: the state is read and never compared with 'Succeeded'.
            $null -ne $state
        }
    }
    Describe 'Test-Deployment' {
        BeforeAll {
            Mock Get-DeploymentState { 'Succeeded' }
        }
        It 'is true for a deployment that succeeded' {
            Test-Deployment -Name 'web-frontend' | Should -BeTrue
        }
    }
}
$config = New-PesterConfiguration
$config.Run.Container = $container
$config.Run.PassThru = $true
$config.Output.Verbosity = 'None'
$result = Invoke-Pester -Configuration $config
Write-Host "Tests passed: $($result.PassedCount), failed: $($result.FailedCount)"
foreach ($t in $result.Failed) { Write-Host "[FAIL] $($t.ExpandedName)" }
if ($result.Result -ne 'Passed') { exit 1 }
Write-Host 'All tests passed.'
