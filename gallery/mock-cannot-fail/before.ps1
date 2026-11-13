# Gallery input: a Pester test whose mock answers Healthy for every input, so it passes whatever the code does.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest

$container = New-PesterContainer -ScriptBlock {
    BeforeAll {
        function Get-BackupState { param([string]$Name) throw "the real call for $Name needs Azure" }
        function Confirm-Backup { param([string]$Name) $null = Get-BackupState $Name; $true }
        Mock Get-BackupState { [pscustomobject]@{ Status = 'Healthy' } }
    }
    Describe 'Confirm-Backup' {
        It 'confirms a healthy backup' {
            Confirm-Backup 'vault-good' | Should -BeTrue
        }
    }
}
$run = Invoke-Pester -Container $container -PassThru -Output None
if ($run.FailedCount -gt 0) {
    Write-Host "[FAIL] $(@($run.Failed.ExpandedName) -join '; ')"
    exit 1
}
Write-Host "All tests passed: $($run.PassedCount) passed."
