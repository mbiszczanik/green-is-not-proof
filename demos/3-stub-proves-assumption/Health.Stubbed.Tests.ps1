BeforeAll { . $PSScriptRoot/Test-WorkspaceHealth.ps1 }

Describe 'Strict workspace health, hand-written stub' {
    It 'passes for a stub object that has the property filled in' {
        # The stub is what we BELIEVE Get-AzOperationalInsightsWorkspace returns.
        $stub = [pscustomobject]@{
            ProvisioningState          = 'Succeeded'
            (Get-HealthPropertyName) = @('/subscriptions/<subscription-id>/resourceGroups/rg/providers/Microsoft.Insights/privateLinkScopes/ampls')
        }
        Test-WorkspaceHealth -Workspace $stub | Should -BeTrue
    }
}
