BeforeAll {
    . $PSScriptRoot/../lib/DryRunGuard.ps1
    $script:Demo = Join-Path $PSScriptRoot '../demos/2-dry-run-is-not-safe'
    function script:New-Fixture($Name, $Body) {
        $p = Join-Path $TestDrive $Name
        Set-Content -LiteralPath $p -Value $Body
        $p
    }
}

Describe 'Find-UnguardedMutation' {
    It 'flags register outside guard' {
        $r = @(Find-UnguardedMutation -Path (Join-Path $Demo 'Deploy-Example.ps1'))
        $r.Count | Should -Be 1
        $r[0].Command | Should -Be 'Register-AzResourceProvider'
        $r[0].Line | Should -BeOfType [int]
    }

    It 'fixed script is clean' {
        @(Find-UnguardedMutation -Path (Join-Path $Demo 'Deploy-Example.Fixed.ps1')).Count | Should -Be 0
    }

    It 'accepts early return guard' {
        $p = New-Fixture 'early.ps1' @'
param([switch]$DryRun)
if ($DryRun) { Write-Output 'skip'; return }
New-AzResourceGroup -Name rg -Location westeurope
'@
        @(Find-UnguardedMutation -Path $p).Count | Should -Be 0
    }

    It 'accepts negated else guard' {
        $p = New-Fixture 'negated.ps1' @'
param([switch]$DryRun)
if (-not $DryRun) { Remove-AzResourceGroup -Name rg -Force }
if (!$WhatIfPreference) { Set-AzResource -ResourceId x -Force }
if ($DryRun) { Write-Output 'skip' } else { Stop-AzVM -Name vm -ResourceGroupName rg }
'@
        @(Find-UnguardedMutation -Path $p).Count | Should -Be 0
    }

    It 'flags a call in the dry-run branch' {
        $p = New-Fixture 'wrongbranch.ps1' @'
param([switch]$DryRun)
if ($DryRun) { New-AzResourceGroup -Name rg -Location westeurope }
'@
        @(Find-UnguardedMutation -Path $p).Command | Should -Be 'New-AzResourceGroup'
    }

    It 'ignores read verbs' {
        $p = New-Fixture 'read.ps1' @'
Get-AzResource -Name x
Test-AzResourceGroup -Name rg
'@
        @(Find-UnguardedMutation -Path $p).Count | Should -Be 0
    }

    It 'parse error throws' {
        $p = New-Fixture 'broken.ps1' 'if ($x { New-AzResourceGroup'
        { Find-UnguardedMutation -Path $p } | Should -Throw 'Parse error in*'
    }
}

Describe 'Find-UnguardedMutation fails red when unsure' {
    It 'reports <Name>' -ForEach @(
        @{ Name = 'compound dry in then, call in else'; Body = 'if ($DryRun -and $Force) { ''skip'' } else { New-AzX }'; Cmd = 'New-AzX' }
        @{ Name = 'compound early return'; Body = "if (`$DryRun -and `$Force) { return }`nNew-AzX"; Cmd = 'New-AzX' }
        @{ Name = 'not-or compound'; Body = 'if (-not $DryRun -or $Force) { New-AzX }'; Cmd = 'New-AzX' }
        @{ Name = 'not over compound'; Body = 'if (-not ($DryRun -and $Force)) { New-AzX }'; Cmd = 'New-AzX' }
        @{ Name = 'dry and not other'; Body = 'if ($DryRun -and -not $Force) { ''x'' } else { New-AzX }'; Cmd = 'New-AzX' }
        @{ Name = 'elseif after unknown'; Body = 'if ($DryRun -and $Force) {} elseif ($x) { New-AzX }'; Cmd = 'New-AzX' }
        @{ Name = 'dynamic invocation'; Body = '& $cmd'; Cmd = '<dynamic>' }
        @{ Name = 'module-qualified name'; Body = 'Az.Resources\New-AzResourceGroup -Name rg'; Cmd = 'Az.Resources\New-AzResourceGroup' }
        @{ Name = 'Restart verb'; Body = 'Restart-AzVM -Name vm'; Cmd = 'Restart-AzVM' }
        @{ Name = 'Invoke verb'; Body = 'Invoke-AzRestMethod -Path x'; Cmd = 'Invoke-AzRestMethod' }
    ) {
        $p = New-Fixture 'unsure.ps1' $Body
        @(Find-UnguardedMutation -Path $p).Command | Should -Be $Cmd
    }

    It 'accepts parenthesised exact forms' {
        $p = New-Fixture 'paren.ps1' "if ((`$DryRun)) { 'x' } else { New-AzX }`nif (!(`$WhatIfPreference)) { Remove-AzX }"
        @(Find-UnguardedMutation -Path $p).Count | Should -Be 0
    }

    It 'accepts elseif after an exact dry clause' {
        $p = New-Fixture 'elseif.ps1' 'if ($DryRun) { ''x'' } elseif ($y) { New-AzX }'
        @(Find-UnguardedMutation -Path $p).Count | Should -Be 0
    }
}
