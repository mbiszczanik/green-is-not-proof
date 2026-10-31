BeforeAll {
    $stubs = @{
        'Get-AzDiagnosticSetting'    = 'param($ResourceId)'
        'Remove-AzDiagnosticSetting' = 'param($ResourceId, $Name)'
    }
    foreach ($n in $stubs.Keys) {
        if (-not (Get-Command $n -ErrorAction SilentlyContinue)) { Set-Item -Path "function:global:$n" -Value ([scriptblock]::Create($stubs[$n])) }
    }
    . $PSScriptRoot/../lib/Mask.ps1
    . $PSScriptRoot/../lib/DiagnosticSettings.ps1
}

Describe 'Remove-DemoDiagnosticSetting' {
    It 'removes every setting whatever its name' {
        Mock Get-AzDiagnosticSetting { @([pscustomobject]@{ Name = 'diag-to-log' }, [pscustomobject]@{ Name = 'hand-made-setting' }) }
        Mock Remove-AzDiagnosticSetting { }
        $n = Remove-DemoDiagnosticSetting -ResourceId '/subscriptions/x/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/st'
        $n | Should -Be 2
        Should -Invoke Remove-AzDiagnosticSetting -Times 1 -ParameterFilter { $Name -eq 'diag-to-log' }
        Should -Invoke Remove-AzDiagnosticSetting -Times 1 -ParameterFilter { $Name -eq 'hand-made-setting' }
    }

    It 'list failure throws and removes nothing' {
        Mock Get-AzDiagnosticSetting { throw 'Forbidden' }
        Mock Remove-AzDiagnosticSetting { }
        { Remove-DemoDiagnosticSetting -ResourceId '/r' } | Should -Throw '*Forbidden*'
        Should -Invoke Remove-AzDiagnosticSetting -Times 0
    }

    It 'remove failure throws' {
        Mock Get-AzDiagnosticSetting { @([pscustomobject]@{ Name = 'a' }) }
        Mock Remove-AzDiagnosticSetting { throw 'Conflict' }
        { Remove-DemoDiagnosticSetting -ResourceId '/r' } | Should -Throw '*Conflict*'
    }

    It 'treats an unsupported resource type as zero settings' {
        Mock Get-AzDiagnosticSetting { throw 'The resource type does not support diagnostic settings.' }
        Mock Remove-AzDiagnosticSetting { }
        (Remove-DemoDiagnosticSetting -ResourceId '/r' 6>$null) | Should -Be 0
        Should -Invoke Remove-AzDiagnosticSetting -Times 0
    }
}
