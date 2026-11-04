BeforeAll {
    $stubs = @{
        'Get-AzDiagnosticSetting'    = 'param($ResourceId)'
        'Remove-AzDiagnosticSetting' = 'param($ResourceId, $Name)'
    }
    $script:StubNames = @($stubs.Keys)
    foreach ($n in $stubs.Keys) { Set-Item -Path "function:global:$n" -Value ([scriptblock]::Create($stubs[$n])) }
    . $PSScriptRoot/../lib/Mask.ps1
    . $PSScriptRoot/../lib/DiagnosticSettings.ps1
}

AfterAll { foreach ($n in $script:StubNames) { Remove-Item "function:global:$n" -ErrorAction SilentlyContinue } }

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

    It 'returns an int count even when Remove-AzDiagnosticSetting emits output' {
        Mock Get-AzDiagnosticSetting { @([pscustomobject]@{ Name = 'a' }, [pscustomobject]@{ Name = 'b' }) }
        Mock Remove-AzDiagnosticSetting { $true }
        $n = Remove-DemoDiagnosticSetting -ResourceId '/r'
        $n | Should -BeOfType [int]
        $n | Should -Be 2
    }

    It 'treats <msg> as zero settings' -ForEach @(@{ msg = 'ResourceTypeNotSupported' }, @{ msg = '[ResourceTypeNotSupported] : The resource type ''microsoft.compute/virtualmachines/extensions'' does not support diagnostic settings.' }) {
        Mock Get-AzDiagnosticSetting { throw $msg }
        Mock Remove-AzDiagnosticSetting { }
        (Remove-DemoDiagnosticSetting -ResourceId '/r' 6>$null) | Should -Be 0
    }

    It 'a BadRequest throws, even one that mentions diagnostic settings' {
        Mock Get-AzDiagnosticSetting { throw 'BadRequest: diagnostic settings payload is malformed' }
        Mock Remove-AzDiagnosticSetting { }
        { Remove-DemoDiagnosticSetting -ResourceId '/r' } | Should -Throw '*malformed*'
    }

    It 'prints the raw Azure message so a live run records the text' {
        Mock Get-AzDiagnosticSetting { throw '[ResourceTypeNotSupported] : the type does not support diagnostic settings.' }
        $out = Remove-DemoDiagnosticSetting -ResourceId '/r' 6>&1 | Out-String
        $out | Should -Match 'ResourceTypeNotSupported'
    }

    It 'masks the subscription id in the unsupported-type line' {
        $sub = [guid]::NewGuid().ToString()
        Mock Get-AzDiagnosticSetting { throw 'does not support diagnostic settings' }
        $out = Remove-DemoDiagnosticSetting -ResourceId "/subscriptions/$sub/x" -SubscriptionId $sub 6>&1 | Out-String
        $out | Should -Not -Match $sub
        $out | Should -Match '<sub>'
    }

    It 'treats an unsupported resource type as zero settings' {
        Mock Get-AzDiagnosticSetting { throw 'The resource type does not support diagnostic settings.' }
        Mock Remove-AzDiagnosticSetting { }
        (Remove-DemoDiagnosticSetting -ResourceId '/r' 6>$null) | Should -Be 0
        Should -Invoke Remove-AzDiagnosticSetting -Times 0
    }
}

Describe 'Get-DemoDiagnosticSettingName' {
    It 'returns the listed names' {
        Mock Get-AzDiagnosticSetting { @([pscustomobject]@{ Name = 'diag-to-log' }) }
        @(Get-DemoDiagnosticSettingName -ResourceId '/r') | Should -Be @('diag-to-log')
    }

    It 'returns none for a type that does not support diagnostic settings' {
        Mock Get-AzDiagnosticSetting { throw 'The resource type does not support diagnostic settings.' }
        @(Get-DemoDiagnosticSettingName -ResourceId '/r').Count | Should -Be 0
    }

    It 'a failed read throws instead of reading as no settings' {
        Mock Get-AzDiagnosticSetting { throw 'Forbidden' }
        { Get-DemoDiagnosticSettingName -ResourceId '/r' } | Should -Throw 'Forbidden'
    }
}
