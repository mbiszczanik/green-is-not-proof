BeforeAll {
    $script:Sub = [guid]::NewGuid().ToString()
    $stubs = @{
        'Get-AzContext'              = 'param()'
        'Get-AzResource'             = 'param($ResourceGroupName, $TagName, $TagValue)'
        'Get-AzResourceGroup'        = 'param($Name)'
        'Remove-AzResourceGroup'     = 'param($Name, [switch]$Force)'
        'Get-AzDiagnosticSetting'    = 'param($ResourceId)'
        'Remove-AzDiagnosticSetting' = 'param($ResourceId, $Name)'
    }
    foreach ($n in $stubs.Keys) {
        if (-not (Get-Command $n -ErrorAction SilentlyContinue)) { Set-Item -Path "function:global:$n" -Value ([scriptblock]::Create($stubs[$n])) }
    }
    . $PSScriptRoot/../scripts/Stop-DemoRun.ps1

    function script:Initialize-Mock {
        $script:out = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:out
        Mock Get-AzContext { [pscustomobject]@{ Subscription = [pscustomobject]@{ Id = $script:Sub } } }
        $script:RgGone = $false
        Mock Get-AzResourceGroup { if ($script:RgGone) { throw 'ResourceGroupNotFound: Resource group could not be found.' }; [pscustomobject]@{ ResourceGroupName = 'rg-gnp-202611181805' } }
        Mock Remove-AzResourceGroup { $script:RgGone = $true }
        Mock Remove-DemoDiagnosticSetting { 0 }
        Mock Get-AzResource { @() }
    }
}

Describe 'Invoke-StopDemoRun' {
    BeforeEach { Initialize-Mock }

    It 'Stop-DemoRun on partial run' {
        $code = Invoke-StopDemoRun -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 0
        Should -Invoke Remove-AzResourceGroup -Times 1 -ParameterFilter { $Name -eq 'rg-gnp-202611181805' -and $Force }
        Should -Invoke Remove-DemoDiagnosticSetting -Times 0
    }

    It 'removes settings on resources and storage sub-services before deleting the group' {
        $id = "/subscriptions/$($script:Sub)/resourceGroups/rg-gnp-202611181805/providers/Microsoft.Storage/storageAccounts/stgnp202611181805"
        Mock Get-AzResource { if ($ResourceGroupName) { @([pscustomobject]@{ ResourceId = $id; ResourceType = 'Microsoft.Storage/storageAccounts' }) } else { @() } }
        $null = Invoke-StopDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        Should -Invoke Remove-DemoDiagnosticSetting -Times 1 -ParameterFilter { $ResourceId -eq $id }
        foreach ($s in 'blob', 'file', 'queue', 'table') {
            Should -Invoke Remove-DemoDiagnosticSetting -Times 1 -ParameterFilter { $ResourceId -eq "$id/${s}Services/default" }
        }
    }

    It 'list failure throws and leaves resource' {
        Mock Get-AzResource { if ($ResourceGroupName) { @([pscustomobject]@{ ResourceId = '/r'; ResourceType = 'Microsoft.Network/virtualNetworks' }) } else { @() } }
        Mock Remove-DemoDiagnosticSetting { throw 'Forbidden' }
        $out = Invoke-StopDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        ($out | Select-Object -Last 1) | Should -Be 1
        Should -Invoke Remove-AzResourceGroup -Times 0
    }

    It 'skips deletion when the group is gone and still runs the tag check' {
        $script:RgGone = $true
        $code = Invoke-StopDemoRun -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 0
        Should -Invoke Remove-AzResourceGroup -Times 0
        Should -Invoke Get-AzResource -Times 1 -ParameterFilter { $TagName -eq 'runId' -and $TagValue -eq '202611181805' }
    }

    It 'leftover tagged resource fails' {
        $leftId = "/subscriptions/$($script:Sub)/resourceGroups/rg-other/providers/Microsoft.Network/publicIPAddresses/pip"
        Mock Get-AzResource { if ($TagName) { @([pscustomobject]@{ ResourceId = $leftId; Name = 'pip' }) } else { @() } }
        $out = @(Invoke-StopDemoRun -RunId '202611181805' -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 1
        $text = ($out | Out-String)
        $text | Should -Match 'pip'
        $text | Should -Not -Match $script:Sub
        $text | Should -Match '<sub>'
    }

    It 'reads the run id from run.json and removes the file on success' {
        @{ RunId = '202611181805' } | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        $code = Invoke-StopDemoRun -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 0
        Test-Path (Join-Path $script:out 'run.json') | Should -BeFalse
    }

    It 'keeps run.json when its RunId differs' {
        @{ RunId = '202611190000' } | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        $null = Invoke-StopDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        Test-Path (Join-Path $script:out 'run.json') | Should -BeTrue
    }

    It 'group lookup failure stops teardown' {
        @{ RunId = '202611181805' } | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        Mock Get-AzResourceGroup { throw "AuthorizationFailed 403 on /subscriptions/$($script:Sub)" }
        $out = @(Invoke-StopDemoRun -RunId '202611181805' -OutDir $script:out 6>&1)
        $out[-1] | Should -Be 1
        ($out | Out-String) | Should -Not -Match $script:Sub
        Should -Invoke Remove-AzResourceGroup -Times 0
        Test-Path (Join-Path $script:out 'run.json') | Should -BeTrue
    }

    It 'group still present after delete fails' {
        Mock Remove-AzResourceGroup { }
        $code = Invoke-StopDemoRun -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 1
    }

    It 'a false from Remove-AzResourceGroup fails' {
        Mock Remove-AzResourceGroup { $false }
        $code = Invoke-StopDemoRun -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 1
    }

    It 'null Az context fails before any call' {
        Mock Get-AzContext { $null }
        $code = Invoke-StopDemoRun -RunId '202611181805' -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 1
        Should -Invoke Get-AzResourceGroup -Times 0
    }

    It 'keeps run.json when the leftover check fails' {
        @{ RunId = '202611181805' } | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        Mock Get-AzResource { if ($TagName) { @([pscustomobject]@{ ResourceId = '/x'; Name = 'x' }) } else { @() } }
        $code = Invoke-StopDemoRun -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 1
        Test-Path (Join-Path $script:out 'run.json') | Should -BeTrue
    }

    It 'fails when no run id is available' {
        $code = Invoke-StopDemoRun -OutDir $script:out 6>&1 | Select-Object -Last 1
        $code | Should -Be 1
        Should -Invoke Remove-AzResourceGroup -Times 0
    }
}
