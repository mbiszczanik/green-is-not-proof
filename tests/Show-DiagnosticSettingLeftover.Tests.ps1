BeforeAll {
    $script:Sub = [guid]::NewGuid().ToString()
    $stubs = @{
        'Get-AzContext'            = 'param()'
        'Get-AzDiagnosticSetting'  = 'param($ResourceId)'
        'Remove-AzDiagnosticSetting' = 'param($ResourceId, $Name)'
        'Remove-AzStorageAccount'  = 'param($ResourceGroupName, $Name, [switch]$Force)'
        'New-AzStorageAccount'     = 'param($ResourceGroupName, $Name, $Location, $SkuName, $Kind, $Tag)'
    }
    foreach ($n in $stubs.Keys) {
        # Always shadow: runners with Az installed would otherwise mock real cmdlets with typed parameters.
        Set-Item -Path "function:global:$n" -Value ([scriptblock]::Create($stubs[$n]))
    }
    $script:StubNames = $stubs.Keys
    . $PSScriptRoot/../demos/1-deleted-is-not-cleaned/Show-DiagnosticSettingLeftover.ps1 -Step Show

    function script:Initialize-Mock {
        $script:Settings = @([pscustomobject]@{ Name = 'diag-to-log' })
        $script:out = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:out
        @{ RunId = '202611181805'; ResourceGroup = 'rg-gnp-202611181805'; StorageAccountName = 'stgnp202611181805'; Location = 'swedencentral' } |
            ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        Mock Get-AzContext { [pscustomobject]@{ Subscription = [pscustomobject]@{ Id = $script:Sub } } }
        Mock Get-AzDiagnosticSetting { $script:Settings }
        Mock Remove-AzDiagnosticSetting { $script:Settings = @() }
        Mock Remove-AzStorageAccount { }
        Mock New-AzStorageAccount { [pscustomobject]@{ Id = 'x' } }
    }
    function script:Step([string]$Name, [string]$RunId) {
        $res = Invoke-DiagnosticSettingLeftover -Step $Name -RunId $RunId -OutDir $script:out -RetryDelaySeconds 0 6>&1
        [pscustomobject]@{ Code = ($res | Where-Object { $_ -is [int] }); Text = ($res | Where-Object { $_ -isnot [int] } | Out-String).Trim() }
    }
}

AfterAll { foreach ($n in $script:StubNames) { Remove-Item "function:global:$n" -ErrorAction SilentlyContinue } }

Describe 'Invoke-DiagnosticSettingLeftover' {
    BeforeEach { Initialize-Mock }

    It 'Show lists the setting on the blob service' {
        $r = Step Show
        $r.Code | Should -Be 0
        $r.Text | Should -Be 'Storage stgnp202611181805 has diagnostic setting(s): diag-to-log'
        Should -Invoke Get-AzDiagnosticSetting -ParameterFilter { $ResourceId -like '*/storageAccounts/stgnp202611181805/blobServices/default' }
    }

    It 'Delete reports success' {
        $r = Step Delete
        $r.Code | Should -Be 0
        $r.Text | Should -Be 'Deleted storage account stgnp202611181805: OK'
        Should -Invoke Remove-AzStorageAccount -Times 1 -Exactly -ParameterFilter { $Name -eq 'stgnp202611181805' -and $ResourceGroupName -eq 'rg-gnp-202611181805' -and $Force }
    }

    It 'Recreate uses the same name, settings and run tags' {
        $r = Step Recreate
        $r.Code | Should -Be 0
        $r.Text | Should -Be 'Recreated storage account stgnp202611181805'
        Should -Invoke New-AzStorageAccount -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'stgnp202611181805' -and $Location -eq 'swedencentral' -and $SkuName -eq 'Standard_LRS' -and $Kind -eq 'StorageV2' -and
            $Tag.runId -eq '202611181805' -and $Tag.project -eq 'green-is-not-proof' }
    }

    It 'List after Recreate shows the old setting name' {
        $null = Step Delete
        $null = Step Recreate
        $r = Step List
        $r.Text | Should -Be 'Diagnostic settings on the NEW account: diag-to-log'
    }

    It 'Clean removes it and List shows none' {
        $r = Step Clean
        $r.Code | Should -Be 0
        $r.Text | Should -Be 'Removed 1 diagnostic setting(s)'
        Should -Invoke Remove-AzDiagnosticSetting -Times 1 -Exactly -ParameterFilter { $Name -eq 'diag-to-log' }
        (Step List).Text | Should -Be 'Diagnostic settings on the NEW account: none'
    }

    It 'every step masks ids' {
        $s = $script:Sub
        Mock Get-AzDiagnosticSetting { [pscustomobject]@{ Name = "diag-$s" } }
        foreach ($n in 'Show', 'List') { (Step $n).Text | Should -Not -Match $s }
        Mock Remove-AzStorageAccount { throw "denied on /subscriptions/$s/x" }
        $r = Step Delete
        $r.Code | Should -Be 1
        $r.Text | Should -Not -Match $s
        $r.Text | Should -Match '<sub>'
    }

    It 'stops without an Az context' {
        Mock Get-AzContext { $null }
        $r = Step Delete
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'Connect-AzAccount'
        Should -Invoke Remove-AzStorageAccount -Times 0 -Exactly
    }

    It 'fails when there is no run id and no run.json' {
        Remove-Item (Join-Path $script:out 'run.json')
        (Step Show).Code | Should -Be 1
    }

    It 'recreate retries while the name is held' {
        $script:n = 0
        Mock New-AzStorageAccount { $script:n++; if ($script:n -le 2) { throw 'StorageAccountAlreadyTaken: name in use' } }
        $r = Step Recreate
        $r.Code | Should -Be 0
        $script:n | Should -Be 3
        ([regex]::Matches($r.Text, 'Name still held by Azure, retrying')).Count | Should -Be 1
        $r.Text | Should -Match 'Recreated storage account'
    }

    It 'recreate gives up after the limit' {
        Mock New-AzStorageAccount { throw 'StorageAccountAlreadyTaken' }
        $r = Step Recreate
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'still held by Azure'
    }

    It 'recreate does not retry other errors' {
        Mock New-AzStorageAccount { throw 'quota exceeded' }
        (Step Recreate).Code | Should -Be 1
        Should -Invoke New-AzStorageAccount -Times 1 -Exactly
    }

    It 'recreate fails when run.json has no Location' {
        @{ RunId = '202611181805' } | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        $r = Step Recreate
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'no Location'
        Should -Invoke New-AzStorageAccount -Times 0 -Exactly
    }

    It 'Show prints none when there are no settings' {
        $script:Settings = @()
        (Step Show).Text | Should -Be 'Storage stgnp202611181805 has diagnostic setting(s): none'
    }

    It 'fails when -RunId differs from run.json' {
        $r = Step Recreate '202611190000'
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'not 202611190000'
        Should -Invoke New-AzStorageAccount -Times 0 -Exactly
    }
}
