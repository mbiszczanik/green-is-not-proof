# Tools each demo depends on, and the version its result was observed with (docs/live-run-log.md). Observed = '' means
# the log records no version for that tool: the demo prints the version it finds and says it was not compared.
@{
    # No block of an Azure run records a PowerShell or Az module version.
    Demo0 = @(
        @{ Name = 'PowerShell'; Observed = '' }
        @{ Name = 'Az.Accounts'; Observed = '' }
        @{ Name = 'Az.Resources'; Observed = '' }
    )
    Demo1 = @(
        @{ Name = 'PowerShell'; Observed = '' }
        @{ Name = 'Az.Accounts'; Observed = '' }
        @{ Name = 'Az.Storage'; Observed = '' }
        @{ Name = 'Az.Monitor'; Observed = '' }
    )
    Demo2 = @(
        @{ Name = 'PowerShell'; Observed = '' }
        @{ Name = 'Pester'; Observed = '' }
    )
    Demo3 = @(
        @{ Name = 'PowerShell'; Observed = '' }
        @{ Name = 'Pester'; Observed = '' }
    )
    Demo3Live = @(
        @{ Name = 'PowerShell'; Observed = '' }
        @{ Name = 'Az.Accounts'; Observed = '' }
        @{ Name = 'Az.OperationalInsights'; Observed = '' }
    )
    # 2026-11-03, run 202611032044. Pester is the module the validators' #Requires line imports.
    Demo4 = @(
        @{ Name = 'PowerShell'; Observed = '7.6.9' }
        @{ Name = 'Pester'; Observed = '' }
    )
    Demo5 = @(
        @{ Name = 'PowerShell'; Observed = '' }
        @{ Name = 'Az.Accounts'; Observed = '' }
        @{ Name = 'Az.Compute'; Observed = '' }
    )
    # 2026-11-04, local block of demo 6.
    Demo6 = @(
        @{ Name = 'PowerShell'; Observed = '' }
        @{ Name = 'Bicep CLI'; Observed = '0.38.5' }
    )
    # 2026-11-05, local block of demo 7.
    Demo7 = @(
        @{ Name = 'PowerShell'; Observed = '7.6.9' }
        @{ Name = 'PSRule'; Observed = '2.9.0' }
        @{ Name = 'PSRule.Rules.Azure'; Observed = '1.47.0' }
        @{ Name = 'Bicep CLI'; Observed = '0.38.5' }
    )
}
