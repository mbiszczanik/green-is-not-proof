BeforeAll {
    . $PSScriptRoot/../lib/Mask.ps1
    # Built at runtime so the tracked tree holds no GUID literal.
    $script:sub = '1b2c3d4e' + '-0000-4000-8000-' + '123456789abc'
    $script:other = '9f8e7d6c' + '-0000-4000-8000-' + '0123456789ab'
}

Describe 'ConvertTo-MaskedText' {
    It 'masks resource id' {
        ConvertTo-MaskedText -Text "/subscriptions/$sub/resourceGroups/x" -SubscriptionId $sub |
            Should -Be '/subscriptions/<sub>/resourceGroups/x'
    }
    It 'masks a bare subscription id' {
        ConvertTo-MaskedText -Text "The subscription '$sub' was not found." -SubscriptionId $sub |
            Should -Be "The subscription '<sub>' was not found."
    }
    It 'masks upper-case form' {
        ConvertTo-MaskedText -Text "id $($sub.ToUpper())" -SubscriptionId $sub | Should -Be 'id <sub>'
    }
    It 'leaves other GUIDs' {
        ConvertTo-MaskedText -Text "id $other" -SubscriptionId $sub | Should -Be "id $other"
    }
    It 'returns text unchanged for an empty subscription id' {
        ConvertTo-MaskedText -Text 'abc' -SubscriptionId '' | Should -Be 'abc'
    }
}

Describe 'Write-DemoOutput' {
    It 'writes the object as masked table text' {
        $o = [pscustomobject]@{ Id = "/subscriptions/$sub/x" }
        $out = (Write-DemoOutput -InputObject $o -SubscriptionId $sub) -join "`n"
        $out | Should -Not -Match $sub
        $out | Should -Match '<sub>'
    }
    It 'long id is masked in table output' {
        $long = "/subscriptions/$sub/resourceGroups/" + ('x' * 220) + '/providers/p'
        $o = [pscustomobject]@{ Id = $long; Name = 'n' }
        $out = (Write-DemoOutput -InputObject $o -SubscriptionId $sub) -join "`n"
        $out | Should -Not -Match $sub
        $out | Should -Not -Match $sub.Substring(0, 8)
        $out | Should -Match '<sub>'
    }
    It 'empty subscription id is rejected' {
        { Write-DemoOutput -InputObject 'x' -SubscriptionId '' } | Should -Throw
    }
}
