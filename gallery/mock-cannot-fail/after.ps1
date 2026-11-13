# Gallery input: the mock answers Failed for a bad input and a canary input must turn the test red; the failure is printed and the process exits 1.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$container = New-PesterContainer -ScriptBlock {
    BeforeAll {
        function Get-BackupState { param([string]$Name) throw "the real call for $Name needs Azure" }
        function Confirm-Backup { param([string]$Name) $null = Get-BackupState $Name; $true }
        Mock Get-BackupState { [pscustomobject]@{ Status = 'Healthy' } } -ParameterFilter { $Name -eq 'vault-good' }
        Mock Get-BackupState { [pscustomobject]@{ Status = 'Failed' } } -ParameterFilter { $Name -eq 'vault-corrupt' }
    }
    Describe 'Confirm-Backup' {
        It 'confirms a healthy backup' {
            Confirm-Backup 'vault-good' | Should -BeTrue
        }
        It 'canary: rejects a corrupt backup' {
            Confirm-Backup 'vault-corrupt' | Should -BeFalse
        }
    }
}
$run = Invoke-Pester -Container $container -PassThru -Output None
if ($run.FailedCount -gt 0) {
    Write-Host "[FAIL] $(@($run.Failed.ExpandedName) -join '; ')"
    exit 1
}
Write-Host "All tests passed: $($run.PassedCount) passed."
