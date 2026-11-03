BeforeAll {
    $script:StubNames = 'Get-AzResourceGroupDeployment', 'Get-AzResourceGroupDeploymentOperation'
    Set-Item -Path 'function:global:Get-AzResourceGroupDeployment' -Value ([scriptblock]::Create('param($ResourceGroupName, $Name)'))
    Set-Item -Path 'function:global:Get-AzResourceGroupDeploymentOperation' -Value ([scriptblock]::Create('param($ResourceGroupName, $DeploymentName)'))
    . $PSScriptRoot/../lib/Ownership.ps1
    function script:Id($Name, $Type = 'Microsoft.Network/virtualNetworks') { "/subscriptions/x/resourceGroups/rg/providers/$Type/$Name" }
    function script:Res($Name, $Type = 'Microsoft.Network/virtualNetworks') {
        [pscustomobject]@{ Name = $Name; ResourceType = $Type; Id = (Id $Name $Type) }
    }
}

AfterAll { foreach ($n in $script:StubNames) { Remove-Item "function:global:$n" -ErrorAction SilentlyContinue } }

Describe 'Find-UnownedResource' {
    It 'flags a tagged resource absent from the deployment record' {
        $inv = @((Res 'vnet-gnp'), (Res 'vm-traffic' 'Microsoft.Compute/virtualMachines'))
        $r = @(Find-UnownedResource -Inventory $inv -ExpectedId @(Id 'vnet-gnp'))
        $r.Name | Should -Be 'vm-traffic'
        $r[0].ResourceType | Should -Be 'Microsoft.Compute/virtualMachines'
        $r[0].Id | Should -Match 'vm-traffic$'
    }

    It 'declared resources are not flagged (case-insensitive ids)' {
        $inv = @((Res 'VNET-GNP'), (Res 'StgNP202611181805' 'Microsoft.Storage/storageAccounts'))
        @(Find-UnownedResource -Inventory $inv -ExpectedId @((Id 'vnet-gnp'), (Id 'stgnp202611181805' 'Microsoft.Storage/storageAccounts'))).Count | Should -Be 0
    }

    It 'a same-named resource of another type is flagged' {
        $inv = @((Res 'vnet-gnp' 'Microsoft.Network/networkInterfaces'))
        @(Find-UnownedResource -Inventory $inv -ExpectedId @(Id 'vnet-gnp')).Count | Should -Be 1
    }

    It 'reads ResourceId when there is no Id' {
        $inv = @([pscustomobject]@{ Name = 'vnet-gnp'; ResourceType = 'Microsoft.Network/virtualNetworks'; ResourceId = (Id 'vnet-gnp') })
        @(Find-UnownedResource -Inventory $inv -ExpectedId @(Id 'vnet-gnp')).Count | Should -Be 0
    }

    It 'empty inventory is an error' {
        { Find-UnownedResource -Inventory @() -ExpectedId @(Id 'vnet-gnp') } | Should -Throw 'Empty inventory'
    }
}

Describe 'Get-DeclaredResourceId' {
    BeforeEach {
        Mock Get-AzResourceGroupDeployment { [pscustomobject]@{ ProvisioningState = 'Succeeded' } }
        Mock Get-AzResourceGroupDeploymentOperation { @([pscustomobject]@{ TargetResource = (Id 'vnet-gnp') }, [pscustomobject]@{ TargetResource = $null }, [pscustomobject]@{ TargetResource = (Id 'vnet-gnp') }) }
    }

    It 'returns the unique target resource ids of a succeeded deployment' {
        @(Get-DeclaredResourceId -ResourceGroupName rg -DeploymentName declared-1) | Should -Be @(Id 'vnet-gnp')
    }

    It 'throws when the deployment record cannot be read' {
        Mock Get-AzResourceGroupDeployment { throw 'DeploymentNotFound' }
        { Get-DeclaredResourceId -ResourceGroupName rg -DeploymentName declared-1 } | Should -Throw '*Deployment record declared-1 not readable*'
    }

    It 'throws when the deployment did not succeed' {
        Mock Get-AzResourceGroupDeployment { [pscustomobject]@{ ProvisioningState = 'Failed' } }
        { Get-DeclaredResourceId -ResourceGroupName rg -DeploymentName declared-1 } | Should -Throw '*is Failed, not Succeeded*'
    }

    It 'throws when the record lists no resources' {
        Mock Get-AzResourceGroupDeploymentOperation { @([pscustomobject]@{ TargetResource = $null }) }
        { Get-DeclaredResourceId -ResourceGroupName rg -DeploymentName declared-1 } | Should -Throw '*lists no resources*'
    }
}
