BeforeAll {
    $script:Sub = [guid]::NewGuid().ToString()
    $stubs = @{
        'Get-AzContext'                 = 'param()'
        'Get-AzResourceGroup'           = 'param($Name)'
        'New-AzResourceGroup'           = 'param($Name, $Location, $Tag)'
        'New-AzResourceGroupDeployment' = 'param($ResourceGroupName, $Name, $TemplateFile, $TemplateParameterObject)'
    }
    foreach ($n in $stubs.Keys) {
        # Always shadow: runners with Az installed would otherwise mock real cmdlets whose signatures differ by version.
        Set-Item -Path "function:global:$n" -Value ([scriptblock]::Create($stubs[$n]))
    }
    $script:StubNames = $stubs.Keys
    . $PSScriptRoot/../scripts/Start-DemoRun.ps1

    function script:Out([string]$Value) { [pscustomobject]@{ Value = $Value } }
    function script:Initialize-Mock {
        $script:Calls = [System.Collections.Generic.List[object]]::new()
        $script:out = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        Mock Get-AzContext { [pscustomobject]@{ Subscription = [pscustomobject]@{ Id = $script:Sub } } }
        Mock Get-DemoExpectedSubscriptionId { $script:Sub }
        Mock Get-AzResourceGroup { throw 'ResourceGroupNotFound: Resource group could not be found.' }
        Mock Get-DemoRunCostEstimate { $script:Calls.Add(@{ Cmd = 'cost' }); [pscustomobject]@{ TotalEur = 0.1; Lines = @(); PriceDate = '2026-11-01' } }
        Mock New-AzResourceGroup { $script:Calls.Add(@{ Cmd = 'New-AzResourceGroup'; Tag = $Tag }) }
        Mock New-AzResourceGroupDeployment {
            $script:Calls.Add(@{ Cmd = 'New-AzResourceGroupDeployment' })
            [pscustomobject]@{
                ProvisioningState = 'Succeeded'
                Outputs           = @{
                    workspaceId        = Out "/subscriptions/$($script:Sub)/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/log"
                    storageAccountName = Out 'stgnp202611181805'
                    vnetName           = Out 'vnet-gnp'
                }
            }
        }
    }
}

AfterAll { foreach ($n in $script:StubNames) { Remove-Item "function:global:$n" -ErrorAction SilentlyContinue } }

Describe 'Invoke-StartDemoRun' {
    BeforeEach { Initialize-Mock }

    It 'cost guard runs first, then the group, then one deployment' {
        $null = Invoke-StartDemoRun -RunId '202611181805' -Location swedencentral -OutDir $script:out 6>&1
        @($script:Calls.Cmd) | Should -Be @('cost', 'New-AzResourceGroup', 'New-AzResourceGroupDeployment')
    }

    It 'deploys infra/declared.bicep under the run''s deployment name with the run tags' {
        $null = Invoke-StartDemoRun -RunId '202611181805' -Location swedencentral -OutDir $script:out 6>&1
        Should -Invoke New-AzResourceGroupDeployment -Times 1 -Exactly -ParameterFilter {
            $ResourceGroupName -eq 'rg-gnp-202611181805' -and $Name -eq 'declared-202611181805' -and
            $TemplateFile -like '*infra/declared.bicep' -and $TemplateParameterObject.runId -eq '202611181805' -and
            $TemplateParameterObject.location -eq 'swedencentral' -and $TemplateParameterObject.tags.project -eq 'green-is-not-proof' -and
            $TemplateParameterObject.tags.runId -eq '202611181805'
        }
    }

    It 'a deployment that does not succeed fails and leaves a run record' {
        Mock New-AzResourceGroupDeployment { [pscustomobject]@{ ProvisioningState = 'Failed'; Outputs = @{} } }
        $res = Invoke-StartDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        $text = ($res | Where-Object { $_ -isnot [int] } | Out-String)
        $text | Should -Match 'Deployment declared-202611181805 ended Failed'
        $text | Should -Match 'Partial run: rg-gnp-202611181805 exists'
        $json = Get-Content (Join-Path $script:out 'run.json') -Raw | ConvertFrom-Json
        $json.DeploymentName | Should -Be 'declared-202611181805'
    }

    It 'a thrown deployment error fails and leaves a run record' {
        Mock New-AzResourceGroupDeployment { throw 'InvalidTemplate' }
        $res = Invoke-StartDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        (Get-Content (Join-Path $script:out 'run.json') -Raw | ConvertFrom-Json).ResourceGroup | Should -Be 'rg-gnp-202611181805'
    }

    It 'over-budget estimate creates nothing' {
        Mock Get-DemoRunCostEstimate { [pscustomobject]@{ TotalEur = 5; Lines = @(); PriceDate = '2026-11-01' } }
        $res = Invoke-StartDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        Should -Invoke New-AzResourceGroup -Times 0 -Exactly
        Test-Path (Join-Path $script:out 'run.json') | Should -BeFalse
    }

    It 'the cost guard prices the rogue VM that New-RogueResource adds later' {
        $null = Invoke-StartDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        Should -Invoke Get-DemoRunCostEstimate -Times 1 -Exactly -ParameterFilter { @($Items.ArmSkuName) -contains 'Standard_B2ts_v2' }
    }

    It 'stops before any change when there is no Az context' {
        Mock Get-AzContext { $null }
        $res = Invoke-StartDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'Connect-AzAccount'
        Should -Invoke New-AzResourceGroup -Times 0 -Exactly
    }

    It 'the resource group carries the run tags' {
        $null = Invoke-StartDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        $c = @($script:Calls | Where-Object { $_.Cmd -eq 'New-AzResourceGroup' })[0]
        $c.Tag.project | Should -Be 'green-is-not-proof'
        $c.Tag.runId | Should -Be '202611181805'
    }

    It 'run.json holds raw ids from the deployment outputs while console output is masked' {
        $res = Invoke-StartDemoRun -RunId '202611181805' -Location swedencentral -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 0 -Because ($res | Where-Object { $_ -isnot [int] } | Out-String)
        $json = Get-Content (Join-Path $script:out 'run.json') -Raw | ConvertFrom-Json
        $json.WorkspaceId | Should -Match $script:Sub
        $json.RunId | Should -Be '202611181805'
        $json.ResourceGroup | Should -Be 'rg-gnp-202611181805'
        $json.DeploymentName | Should -Be 'declared-202611181805'
        $json.StorageAccountName | Should -Be 'stgnp202611181805'
        $json.VnetName | Should -Be 'vnet-gnp'
        $json.Location | Should -Be 'swedencentral'
        $json.PSObject.Properties['RogueVmName'] | Should -BeNullOrEmpty
        $text = ($res | Where-Object { $_ -isnot [int] } | Out-String)
        $text | Should -Not -Match $script:Sub
        $text | Should -Match '<sub>'
        $text | Should -Match 'New-RogueResource\.ps1'
    }

    It 'refuses a subscription other than the configured one before the cost guard' {
        Mock Get-DemoExpectedSubscriptionId { [guid]::NewGuid().ToString() }
        $res = Invoke-StartDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        $text = ($res | Where-Object { $_ -isnot [int] } | Out-String)
        $text | Should -Match 'not the demo subscription'
        $text | Should -Not -Match $script:Sub
        Should -Invoke Get-DemoRunCostEstimate -Times 0 -Exactly
        Should -Invoke New-AzResourceGroup -Times 0 -Exactly
    }

    It 'refuses when no demo subscription is configured' {
        Mock Get-DemoExpectedSubscriptionId { '' }
        $res = Invoke-StartDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'not configured'
        Should -Invoke New-AzResourceGroup -Times 0 -Exactly
    }

    It 'writes SubscriptionId into run.json' {
        $null = Invoke-StartDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        (Get-Content (Join-Path $script:out 'run.json') -Raw | ConvertFrom-Json).SubscriptionId | Should -Be $script:Sub
    }

    It 'refuses to start while a previous run.json exists' {
        $null = New-Item -ItemType Directory -Force -Path $script:out
        @{ RunId = '202611170900' } | ConvertTo-Json | Set-Content (Join-Path $script:out 'run.json')
        $res = Invoke-StartDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'A previous run \(202611170900\) was not torn down\. Run scripts/Stop-DemoRun\.ps1 first\.'
        Should -Invoke Get-DemoRunCostEstimate -Times 0 -Exactly
        Should -Invoke New-AzResourceGroup -Times 0 -Exactly
        (Get-Content (Join-Path $script:out 'run.json') -Raw | ConvertFrom-Json).RunId | Should -Be '202611170900'
    }

    It 'stops when the resource group already exists' {
        Mock Get-AzResourceGroup { [pscustomobject]@{ ResourceGroupName = 'rg-gnp-202611181805' } }
        $res = Invoke-StartDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        ($res | Where-Object { $_ -isnot [int] } | Out-String) | Should -Match 'already exists'
        Should -Invoke New-AzResourceGroup -Times 0 -Exactly
    }

    It 'prints neither an e-mail address nor an object id from an error' {
        $mail = 'a.b' + '@' + 'example.org'
        $oid = [guid]::NewGuid().ToString()
        Mock New-AzResourceGroupDeployment { throw "AuthorizationFailed: $mail object id $oid" }
        $res = Invoke-StartDemoRun -RunId '202611181805' -OutDir $script:out 6>&1
        $text = ($res | Where-Object { $_ -isnot [int] } | Out-String)
        $text | Should -Not -Match 'example\.org'
        $text | Should -Not -Match $oid
        $text | Should -Match '<email>'
        $text | Should -Match '<guid>'
    }

    It 'rejects a run id that is not 12 digits' {
        $res = Invoke-StartDemoRun -RunId 'bad' -OutDir $script:out 6>&1
        ($res | Where-Object { $_ -is [int] }) | Should -Be 1
        Should -Invoke New-AzResourceGroup -Times 0 -Exactly
    }
}

Describe 'declared code' {
    It 'Start-DemoRun.ps1 calls no VM, NIC or other New-Az cmdlet outside the deployment' {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot/../scripts/Start-DemoRun.ps1", [ref]$null, [ref]$null)
        $names = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() })
        @($names | Where-Object { $_ -like 'New-Az*' }) | Sort-Object -Unique | Should -Be @('New-AzResourceGroup', 'New-AzResourceGroupDeployment')
    }

    It 'infra/declared.bicep declares no compute or network interface resource' {
        $text = Get-Content "$PSScriptRoot/../infra/declared.bicep" -Raw
        $text | Should -Not -Match 'Microsoft\.Compute/'
        $text | Should -Not -Match 'Microsoft\.Network/networkInterfaces'
        $text | Should -Match "name: 'diag-to-log'"
    }
}
