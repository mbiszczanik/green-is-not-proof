<#
.SYNOPSIS
Creates the rogue VM for demo 0, outside the declared deployment, in an existing demo run.
.DESCRIPTION
Run after scripts/Start-DemoRun.ps1, whose cost guard already priced this VM. Creates vm-traffic
(Standard_B2ts_v2, Ubuntu 22.04, no public IP, boot diagnostics off, SSH key generated into out/) and its NIC in
the run's subnet, with the run's canonical tags copied on, so a tag audit counts it as the project's own. Nothing
here is part of infra/declared.bicep, so its deployment record does not list it. Needs out/run.json of the run.
The VM gets a free auto-shutdown schedule 3 hours ahead (UTC), so a forgotten teardown stops paying for compute.
.EXAMPLE
./scripts/New-RogueResource.ps1
#>
[CmdletBinding()]
param(
    [string]$OutDir
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot/../lib/RunContext.ps1
. $PSScriptRoot/../lib/Mask.ps1

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

function Invoke-NewRogueResource {
    <#
    .SYNOPSIS
    Creates the rogue VM and returns 0, or 1 on any failure.
    .EXAMPLE
    $code = Invoke-NewRogueResource -OutDir ./out
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param([Parameter(Mandatory)][string]$OutDir, [datetime]$Now = (Get-Date))
    $sub = ''
    try {
        $ctx = Get-AzContext
        if (-not $ctx) { Write-Host 'Run Connect-AzAccount first'; return 1 }
        $sub = $ctx.Subscription.Id
        $run = Read-DemoRun -OutDir $OutDir
        if (-not $run) { throw 'No out/run.json. Run scripts/Start-DemoRun.ps1 first.' }
        Assert-DemoRunSubscription -Run $run -Current $sub
        if ($run.PSObject.Properties['RogueVmName'] -and $run.RogueVmName) { throw "Run $($run.RunId) already has the rogue VM $($run.RogueVmName)" }
        if (-not ($run.PSObject.Properties['VnetName'] -and $run.VnetName)) { throw "run.json of run $($run.RunId) has no VnetName; the declared deployment did not finish" }

        $rg = $run.ResourceGroup
        $vmName = 'vm-traffic'
        $tag = Get-DemoTag -RunId $run.RunId
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $rg -Name $run.VnetName
        $pubKey = New-DemoSshKey -Path (Join-Path $OutDir 'demo_key')
        $nic = New-AzNetworkInterface -ResourceGroupName $rg -Name 'vm-traffic-nic' -Location $run.Location -SubnetId $vnet.Subnets[0].Id -Tag $tag
        $secret = [securestring]::new()
        foreach ($c in ([guid]::NewGuid().ToString('N') + 'Aa1!').ToCharArray()) { $secret.AppendChar($c) }
        $cred = [pscredential]::new('demoadmin', $secret)
        $vm = New-AzVMConfig -VMName $vmName -VMSize 'Standard_B2ts_v2'
        $vm = Set-AzVMOperatingSystem -VM $vm -Linux -ComputerName $vmName -Credential $cred -DisablePasswordAuthentication
        $vm = Add-AzVMSshPublicKey -VM $vm -KeyData $pubKey -Path '/home/demoadmin/.ssh/authorized_keys'
        $vm = Set-AzVMSourceImage -VM $vm -PublisherName 'Canonical' -Offer '0001-com-ubuntu-server-jammy' -Skus '22_04-lts-gen2' -Version 'latest'
        $vm = Set-AzVMBootDiagnostic -VM $vm -Disable
        $vm = Add-AzVMNetworkInterface -VM $vm -Id $nic.Id
        $vm = Set-AzVMOSDisk -VM $vm -CreateOption FromImage -StorageAccountType StandardSSD_LRS
        $null = New-AzVM -ResourceGroupName $rg -Location $run.Location -VM $vm -Tag $tag
        $run | Add-Member -NotePropertyName RogueVmName -NotePropertyValue $vmName -Force
        $run | ConvertTo-Json | Set-Content -Path (Join-Path $OutDir 'run.json') -Encoding utf8

        $shutdown = $Now.ToUniversalTime().AddHours(3).ToString('HHmm')
        $vmId = "/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.Compute/virtualMachines/$vmName"
        $schedule = @{
            status               = 'Enabled'
            taskType             = 'ComputeVmShutdownTask'
            dailyRecurrence      = @{ time = $shutdown }
            timeZoneId           = 'UTC'
            targetResourceId     = $vmId
            notificationSettings = @{ status = 'Disabled' }
        }
        try {
            $null = New-AzResource -ResourceId "/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.DevTestLab/schedules/shutdown-computevm-$vmName" -Location $run.Location -Properties $schedule -Tag $tag -Force
        }
        catch { throw "$vmName was created but its auto-shutdown schedule was not: $($_.Exception.Message). Tear the run down when done." }
        Write-Host "Created $vmName in $rg outside the declared deployment, with the run's tags; auto-shutdown at $shutdown UTC"
        return 0
    }
    catch {
        Write-Host (ConvertTo-SafeText -Text "New-RogueResource failed: $($_.Exception.Message)" -SubscriptionId $sub)
        return 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '../out' }
    $code = Invoke-NewRogueResource -OutDir $OutDir
    if ($code -ne 0) { exit 1 }
}
