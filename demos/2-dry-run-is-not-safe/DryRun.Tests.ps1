# On-stage suite. Outside ./tests on purpose: CI does not run it, its red is intended.
BeforeAll {
    . $PSScriptRoot/../../lib/DryRunGuard.ps1
    . $PSScriptRoot/../../lib/ToolVersion.ps1
    Write-DemoToolVersion -Demo Demo2
    function script:Get-Unguarded($Path) {
        $hits = @(Find-UnguardedMutation -Path (Join-Path $PSScriptRoot $Path))
        ($hits | ForEach-Object { "line $($_.Line): $($_.Command)" }) -join '; '
    }
}

Describe 'Dry-run guard' {
    It 'Deploy-Example.ps1 has no unguarded mutation' {
        Get-Unguarded 'Deploy-Example.ps1' | Should -BeNullOrEmpty
    }

    It 'Deploy-Example.Fixed.ps1 has no unguarded mutation' {
        Get-Unguarded 'Deploy-Example.Fixed.ps1' | Should -BeNullOrEmpty
    }
}
