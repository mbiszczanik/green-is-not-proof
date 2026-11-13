# Gallery input: the same test; the mock answers 'Failed' for a canary input, and a canary test must go red on the defect.
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
            Mock Get-DeploymentState { 'Failed' } -ParameterFilter { $Name -eq 'canary-failed' }
        }
        It 'is true for a deployment that succeeded' {
            Test-Deployment -Name 'web-frontend' | Should -BeTrue
        }
        It 'is false for the canary, a deployment that failed' {
            Test-Deployment -Name 'canary-failed' | Should -BeFalse
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
