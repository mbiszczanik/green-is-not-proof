function Test-DryRunCondition {
    # Returns 'Dry' (true means dry-run), 'NotDry' (negated), or $null when the condition ignores the switches.
    param([System.Management.Automation.Language.Ast]$Condition)
    $isVar = { param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.VariablePath.UserPath -in @('DryRun', 'WhatIfPreference') }
    if (-not $Condition.Find($isVar, $true)) { return $null }
    $negated = { param($n) $n -is [System.Management.Automation.Language.UnaryExpressionAst] -and $n.TokenKind -in @('Not', 'Exclaim') -and $n.Child.Find($isVar, $true) }
    if ($Condition.Find($negated, $true)) { 'NotDry' } else { 'Dry' }
}

function Test-CallGuarded {
    param([System.Management.Automation.Language.CommandAst]$Call)
    $offset = $Call.Extent.StartOffset
    for ($node = $Call.Parent; $node; $node = $node.Parent) {
        # a) call sits in the branch that runs when not dry-run
        if ($node -is [System.Management.Automation.Language.IfStatementAst]) {
            $earlierDry = $false
            foreach ($clause in $node.Clauses) {
                $kind = Test-DryRunCondition -Condition $clause.Item1
                $inBody = $offset -ge $clause.Item2.Extent.StartOffset -and $offset -lt $clause.Item2.Extent.EndOffset
                if ($inBody -and ($kind -eq 'NotDry' -or $earlierDry)) { return $true }
                if ($kind -eq 'Dry') { $earlierDry = $true }
            }
            $else = $node.ElseClause
            if ($else -and $earlierDry -and $offset -ge $else.Extent.StartOffset -and $offset -lt $else.Extent.EndOffset) { return $true }
        }
        # b) an earlier `if ($DryRun) { ...; return|exit|break }` in this or an enclosing block
        if ($node -is [System.Management.Automation.Language.StatementBlockAst] -or $node -is [System.Management.Automation.Language.NamedBlockAst]) {
            foreach ($stmt in $node.Statements) {
                if ($stmt.Extent.StartOffset -ge $offset -or $stmt -isnot [System.Management.Automation.Language.IfStatementAst]) { continue }
                if ($stmt.ElseClause -or $stmt.Clauses.Count -ne 1) { continue }
                if ((Test-DryRunCondition -Condition $stmt.Clauses[0].Item1) -ne 'Dry') { continue }
                $exits = $stmt.Clauses[0].Item2.Statements | Where-Object {
                    $_ -is [System.Management.Automation.Language.ReturnStatementAst] -or
                    $_ -is [System.Management.Automation.Language.ExitStatementAst] -or
                    $_ -is [System.Management.Automation.Language.BreakStatementAst]
                }
                if ($exits) { return $true }
            }
        }
    }
    $false
}

function Find-UnguardedMutation {
    <#
    .SYNOPSIS
    Finds state-changing Az calls in a script that a dry-run guard does not cover. Never runs the script.
    .DESCRIPTION
    Parses the script and checks every command named <MutatingVerb>-Az*. A call is guarded when it sits in the
    non-dry branch of an if on $DryRun or $WhatIfPreference, or follows an early `if ($DryRun) { ...; return }`.
    A parse error throws, so a script that cannot be read is never reported clean.
    .EXAMPLE
    Find-UnguardedMutation -Path ./Deploy.ps1
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [string[]]$MutatingVerb = @('New', 'Set', 'Remove', 'Register', 'Update', 'Start', 'Stop', 'Add', 'Install')
    )
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) { throw "Parse error in ${Path}: $($errors[0].Message)" }
    $pattern = '^(' + (($MutatingVerb | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')-Az'
    $calls = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
    $hits = foreach ($call in $calls) {
        $name = $call.GetCommandName()
        if ($name -and $name -match $pattern -and -not (Test-CallGuarded -Call $call)) {
            [pscustomobject]@{ Line = [int]$call.Extent.StartLineNumber; Command = $name }
        }
    }
    @(@($hits) | Where-Object { $_ } | Sort-Object -Property Line)
}
