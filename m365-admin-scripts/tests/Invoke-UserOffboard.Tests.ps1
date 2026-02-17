BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelper.ps1')
    $scriptPath = Join-Path $PSScriptRoot '..' 'scripts' 'Invoke-UserOffboard.ps1'
}

Describe 'Invoke-UserOffboard' {

    BeforeAll {
        # Define stubs for Graph/Exchange cmdlets (not installed on CI runners)
        function Get-MgContext { }
        function Get-OrganizationConfig { }
        function Get-MgUser { }
        function Update-MgUser { }
        function Invoke-MgGraphRequest { }
        function Set-Mailbox { }
        function Set-MgUserLicense { }
        function Get-MgUserMemberOf { }
        function Remove-MgGroupMemberByRef { }

        # Mock Graph context check
        Mock Get-MgContext { [PSCustomObject]@{ TenantId = 'test-tenant-id' } }

        # Mock Exchange connection check
        Mock Get-OrganizationConfig { [PSCustomObject]@{ Name = 'Contoso' } }

        # Mock user lookup
        Mock Get-MgUser {
            [PSCustomObject]@{
                Id                = 'user-001'
                DisplayName       = 'John Doe'
                UserPrincipalName = 'jdoe@contoso.com'
                AccountEnabled    = $true
                AssignedLicenses  = @(
                    [PSCustomObject]@{ SkuId = 'sku-001' }
                    [PSCustomObject]@{ SkuId = 'sku-002' }
                )
            }
        }

        # Mock all offboarding actions
        Mock Update-MgUser {}
        Mock Invoke-MgGraphRequest {}
        Mock Set-Mailbox {}
        Mock Set-MgUserLicense {}
        Mock Get-MgUserMemberOf {
            @(
                [PSCustomObject]@{
                    Id                   = 'group-001'
                    AdditionalProperties = @{
                        '@odata.type' = '#microsoft.graph.group'
                        displayName   = 'Engineering'
                    }
                }
                [PSCustomObject]@{
                    Id                   = 'group-002'
                    AdditionalProperties = @{
                        '@odata.type' = '#microsoft.graph.group'
                        displayName   = 'All Company'
                    }
                }
            )
        }
        Mock Remove-MgGroupMemberByRef {}
        Mock Start-Sleep {}

        Mock Export-Csv {}
        Mock New-Item {}
        Mock Test-Path { $true }
        Mock Add-Content {}
    }

    Context 'Single user offboarding' {
        BeforeAll {
            $results = Invoke-ScriptUnderTest -ScriptPath $scriptPath -Parameters @{
                UserPrincipalName    = 'jdoe@contoso.com'
                ConvertToSharedMailbox = $true
                ForwardingAddress    = 'manager@contoso.com'
                Force                = $true
                Confirm              = $false
            }
        }

        It 'returns a result object' {
            $results | Should -HaveCount 1
        }

        It 'reports Success status' {
            $results[0].Status | Should -Be 'Success'
        }

        It 'disables the account' {
            $results[0].DisableAccount | Should -Be 'Success'
        }

        It 'revokes sign-in sessions' {
            $results[0].RevokeSessions | Should -Be 'Success'
        }

        It 'converts mailbox to shared' {
            $results[0].ConvertMailbox | Should -Be 'Success'
        }

        It 'sets mail forwarding' {
            $results[0].SetForwarding | Should -BeLike 'Success*manager@contoso.com'
        }

        It 'removes licenses' {
            $results[0].RemoveLicenses | Should -BeLike 'Success*'
        }

        It 'tracks licenses reclaimed' {
            $results[0].LicensesReclaimed | Should -Be 2
        }

        It 'removes group memberships' {
            $results[0].RemoveGroups | Should -BeLike 'Success*'
        }

        It 'tracks groups removed' {
            $results[0].GroupsRemoved | Should -Be 2
        }

        It 'hides from GAL' {
            $results[0].HideFromGAL | Should -Be 'Success'
        }

        It 'result has expected properties' {
            $props = $results[0].PSObject.Properties.Name
            $props | Should -Contain 'UserPrincipalName'
            $props | Should -Contain 'DisplayName'
            $props | Should -Contain 'Status'
            $props | Should -Contain 'DisableAccount'
            $props | Should -Contain 'RevokeSessions'
            $props | Should -Contain 'RemoveLicenses'
            $props | Should -Contain 'ConvertMailbox'
            $props | Should -Contain 'SetForwarding'
            $props | Should -Contain 'RemoveGroups'
            $props | Should -Contain 'HideFromGAL'
        }
    }

    Context 'Without ConvertToSharedMailbox' {
        BeforeAll {
            # Reset mock call counts
            $results = Invoke-ScriptUnderTest -ScriptPath $scriptPath -Parameters @{
                UserPrincipalName = 'jdoe@contoso.com'
                Force             = $true
                Confirm           = $false
            }
        }

        It 'skips mailbox conversion when switch is not set' {
            $results[0].ConvertMailbox | Should -Be 'Skipped'
        }
    }

    Context 'User not found' {
        BeforeAll {
            Mock Get-MgUser { throw "User not found" }

            $results = Invoke-ScriptUnderTest -ScriptPath $scriptPath -Parameters @{
                UserPrincipalName = 'nobody@contoso.com'
                Force             = $true
                Confirm           = $false
            }
        }

        It 'reports Failed status when user does not exist' {
            $results[0].Status | Should -Be 'Failed'
        }

        It 'records user not found in disable step' {
            $results[0].DisableAccount | Should -BeLike '*not found*'
        }
    }
}
