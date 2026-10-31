<#
.SYNOPSIS
Builds one demo run's Azure resources after the cost guard approves it, and writes out/run.json.
.DESCRIPTION
Order: Az context check, cost guard (2 hours, limit 2 EUR), resource group, Log Analytics workspace,
storage account with a blob diagnostic setting, VNet with subnet snet-app, then the rogue VM
(vm-traffic, Standard_B1s, Ubuntu 22.04, no public IP, SSH key generated into out/). The VM uses a
New-AzVMConfig chain so the key and image are explicit. It is absent from config/demo-manifest.psd1.
run.json holds raw ids (out/ is gitignored); console output masks the subscription id.
The current subscription must match GNP_SUBSCRIPTION_ID or ~/.config/green-is-not-proof/subscription.txt,
and a leftover out/run.json from an untorn run stops the start.
.EXAMPLE
./scripts/Start-DemoRun.ps1 -Location swedencentral
#>
[CmdletBinding()]
param(
    [string]$Location = 'swedencentral',
    [string]$RunId,
    [string]$OutDir
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot/../lib/RunContext.ps1
. $PSScriptRoot/../lib/Mask.ps1
. $PSScriptRoot/../lib/CostGuard.ps1

function New-DemoSshKey {
    <#
    .SYNOPSIS
    Generates an ed25519 key pair in a folder and returns the public key text.
    .EXAMPLE
    New-DemoSshKey -Path ./out/demo_key
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal helper.')]
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$Path)
    foreach ($f in $Path, "$Path.pub") { if (Test-Path $f) { Remove-Item $f -Force } }
    & ssh-keygen -q -t ed25519 -N '' -C demo -f $Path | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'ssh-keygen failed' }
    (Get-Content "$Path.pub" -Raw).Trim()
}

function Invoke-StartDemoRun {
    <#
    .SYNOPSIS
    Runs the setup and returns 0 on success or 1 on any failure (nothing is created when the guard fails).
    .EXAMPLE
    $code = Invoke-StartDemoRun -RunId (New-DemoRunId) -Location swedencentral -OutDir ./out
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [string]$Location = 'swedencentral',
        [string]$RunId,
        [Parameter(Mandatory)][string]$OutDir
    )
    $sub = ''
    $run = $null
    try {
        $ctx = Get-AzContext
        if (-not $ctx) { Write-Host 'Run Connect-AzAccount first'; return 1 }
        $sub = $ctx.Subscription.Id
        Assert-DemoSubscription -Expected (Get-DemoExpectedSubscriptionId) -Current $sub
        if (-not $RunId) { $RunId = New-DemoRunId }
        if ($RunId -notmatch '^\d{12}$') { throw "RunId must be 12 digits (yyyyMMddHHmm), got '$RunId'" }
        $runFile = Join-Path $OutDir 'run.json'
        if (Test-Path -LiteralPath $runFile) {
            $prev = (Get-Content -LiteralPath $runFile -Raw | ConvertFrom-Json).RunId
            Write-Host "A previous run ($prev) was not torn down. Run scripts/Stop-DemoRun.ps1 first."
            return 1
        }

        $items = (Import-PowerShellDataFile $PSScriptRoot/../config/demo-resources.psd1).Items
        $estimate = Get-DemoRunCostEstimate -Items $items -Region $Location -Hours 2
        Assert-DemoRunBudget -Estimate $estimate
        Write-Host ("Cost guard passed: {0} EUR for 2 hours" -f $estimate.TotalEur)

        $tag = Get-DemoTag -RunId $RunId
        $rg = Get-DemoResourceGroupName -RunId $RunId
        $storageName = "stgnp$RunId"
        $vnetName = 'vnet-gnp'
        $vmName = 'vm-traffic'

        if (Test-DemoResourceGroup -Name $rg) { throw "Resource group $rg already exists; refusing to reuse it" }
        $null = New-Item -ItemType Directory -Force -Path $OutDir
        $null = New-AzResourceGroup -Name $rg -Location $Location -Tag $tag
        # Written right after the group exists so a later failure still leaves a record for teardown.
        $run = [ordered]@{ RunId = $RunId; SubscriptionId = $sub; ResourceGroup = $rg; Location = $Location }
        $run | ConvertTo-Json | Set-Content -Path $runFile -Encoding utf8
        $workspace = New-AzOperationalInsightsWorkspace -ResourceGroupName $rg -Name "log-gnp-$RunId" -Location $Location -Sku PerGB2018 -Tag $tag
        $run.WorkspaceId = $workspace.ResourceId
        $run | ConvertTo-Json | Set-Content -Path $runFile -Encoding utf8
        $storage = New-AzStorageAccount -ResourceGroupName $rg -Name $storageName -Location $Location -SkuName Standard_LRS -Kind StorageV2 -Tag $tag
        $run.StorageAccountName = $storageName
        $run | ConvertTo-Json | Set-Content -Path $runFile -Encoding utf8
        $log = New-AzDiagnosticSettingLogSettingsObject -Enabled $true -CategoryGroup allLogs
        $null = New-AzDiagnosticSetting -Name 'diag-to-log' -ResourceId "$($storage.Id)/blobServices/default" -WorkspaceId $workspace.ResourceId -Log $log

        $subnet = New-AzVirtualNetworkSubnetConfig -Name 'snet-app' -AddressPrefix '10.10.1.0/24'
        $vnet = New-AzVirtualNetwork -ResourceGroupName $rg -Name $vnetName -Location $Location -AddressPrefix '10.10.0.0/16' -Subnet $subnet -Tag $tag
        $run.VnetName = $vnetName
        $run | ConvertTo-Json | Set-Content -Path $runFile -Encoding utf8

        $pubKey = New-DemoSshKey -Path (Join-Path $OutDir 'demo_key')
        $nic = New-AzNetworkInterface -ResourceGroupName $rg -Name 'vm-traffic-nic' -Location $Location -SubnetId $vnet.Subnets[0].Id -Tag $tag
        $secret = [securestring]::new()
        foreach ($c in ([guid]::NewGuid().ToString('N') + 'Aa1!').ToCharArray()) { $secret.AppendChar($c) }
        $cred = [pscredential]::new('demoadmin', $secret)
        $vm = New-AzVMConfig -VMName $vmName -VMSize 'Standard_B1s'
        $vm = Set-AzVMOperatingSystem -VM $vm -Linux -ComputerName $vmName -Credential $cred -DisablePasswordAuthentication
        $vm = Add-AzVMSshPublicKey -VM $vm -KeyData $pubKey -Path '/home/demoadmin/.ssh/authorized_keys'
        $vm = Set-AzVMSourceImage -VM $vm -PublisherName 'Canonical' -Offer '0001-com-ubuntu-server-jammy' -Skus '22_04-lts-gen2' -Version 'latest'
        $vm = Add-AzVMNetworkInterface -VM $vm -Id $nic.Id
        $vm = Set-AzVMOSDisk -VM $vm -CreateOption FromImage -StorageAccountType StandardSSD_LRS
        $null = New-AzVM -ResourceGroupName $rg -Location $Location -VM $vm -Tag $tag

        $run.RogueVmName = $vmName
        $run | ConvertTo-Json | Set-Content -Path $runFile -Encoding utf8
        Write-Host (([pscustomobject]$run | Write-DemoOutput -SubscriptionId $sub))
        return 0
    }
    catch {
        $msg = ConvertTo-MaskedText -Text "Start-DemoRun failed: $($_.Exception.Message)" -SubscriptionId $sub
        Write-Host $msg
        if ($run) { Write-Host (ConvertTo-MaskedText -Text "Partial run: $($run.ResourceGroup) exists. Run scripts/Stop-DemoRun.ps1 -RunId $RunId to tear it down." -SubscriptionId $sub) }
        return 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '../out' }
    $code = Invoke-StartDemoRun -Location $Location -RunId $RunId -OutDir $OutDir
    if ($code -ne 0) { exit 1 }
}
