BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelper.ps1')
    $scriptPath = Join-Path $PSScriptRoot '..' 'scripts' 'Get-InactiveUserReport.ps1'
}

Describe 'Get-InactiveUserReport' {

    BeforeAll {
        # Define stubs for Graph cmdlets (not installed on CI runners)
        function Get-MgContext { }
        function Get-MgUser { }

        Mock Get-MgContext { [PSCustomObject]@{ TenantId = 'test-tenant-id' } }

        # Mixed test users: active, inactive, never-signed-in, guest
        Mock Get-MgUser {
            @(
                # Active user — signed in yesterday
                [PSCustomObject]@{
                    DisplayName       = 'Active User'
                    UserPrincipalName = 'active@contoso.com'
                    AccountEnabled    = $true
                    AssignedLicenses  = @([PSCustomObject]@{ SkuId = 'sku1' })
                    SignInActivity    = [PSCustomObject]@{ LastSignInDateTime = (Get-Date).AddDays(-1) }
                    CreatedDateTime   = (Get-Date).AddDays(-365)
                    Department        = 'Engineering'
                    JobTitle          = 'Developer'
                    UserType          = 'Member'
                }
                # Inactive user — signed in 120 days ago
                [PSCustomObject]@{
                    DisplayName       = 'Inactive User'
                    UserPrincipalName = 'inactive@contoso.com'
                    AccountEnabled    = $true
                    AssignedLicenses  = @([PSCustomObject]@{ SkuId = 'sku1' }, [PSCustomObject]@{ SkuId = 'sku2' })
                    SignInActivity    = [PSCustomObject]@{ LastSignInDateTime = (Get-Date).AddDays(-120) }
                    CreatedDateTime   = (Get-Date).AddDays(-400)
                    Department        = 'Marketing'
                    JobTitle          = 'Manager'
                    UserType          = 'Member'
                }
                # Never signed in, old account
                [PSCustomObject]@{
                    DisplayName       = 'Never Signed In'
                    UserPrincipalName = 'never@contoso.com'
                    AccountEnabled    = $true
                    AssignedLicenses  = @([PSCustomObject]@{ SkuId = 'sku1' })
                    SignInActivity    = [PSCustomObject]@{ LastSignInDateTime = $null }
                    CreatedDateTime   = (Get-Date).AddDays(-200)
                    Department        = 'Sales'
                    JobTitle          = 'Rep'
                    UserType          = 'Member'
                }
                # Disabled user with license (wasting licenses)
                [PSCustomObject]@{
                    DisplayName       = 'Disabled Licensed'
                    UserPrincipalName = 'disabled@contoso.com'
                    AccountEnabled    = $false
                    AssignedLicenses  = @([PSCustomObject]@{ SkuId = 'sku1' })
                    SignInActivity    = [PSCustomObject]@{ LastSignInDateTime = (Get-Date).AddDays(-180) }
                    CreatedDateTime   = (Get-Date).AddDays(-500)
                    Department        = 'Marketing'
                    JobTitle          = 'Intern'
                    UserType          = 'Member'
                }
                # Guest user — should be excluded
                [PSCustomObject]@{
                    DisplayName       = 'Guest User'
                    UserPrincipalName = 'guest_ext@contoso.com'
                    AccountEnabled    = $true
                    AssignedLicenses  = @()
                    SignInActivity    = [PSCustomObject]@{ LastSignInDateTime = (Get-Date).AddDays(-200) }
                    CreatedDateTime   = (Get-Date).AddDays(-300)
                    Department        = $null
                    JobTitle          = $null
                    UserType          = 'Guest'
                }
                # Recently created, never signed in — should NOT be inactive yet
                [PSCustomObject]@{
                    DisplayName       = 'New User'
                    UserPrincipalName = 'newuser@contoso.com'
                    AccountEnabled    = $true
                    AssignedLicenses  = @([PSCustomObject]@{ SkuId = 'sku1' })
                    SignInActivity    = [PSCustomObject]@{ LastSignInDateTime = $null }
                    CreatedDateTime   = (Get-Date).AddDays(-10)
                    Department        = 'Engineering'
                    JobTitle          = 'Intern'
                    UserType          = 'Member'
                }
            )
        }

        Mock Export-Csv {}
        Mock New-Item {}
        Mock Test-Path { $true }
    }

    Context 'Default 90-day threshold' {
        BeforeAll {
            $results = Invoke-ScriptUnderTest -ScriptPath $scriptPath -Parameters @{ InactiveDays = 90 }
        }

        It 'excludes active users' {
            $results.UserPrincipalName | Should -Not -Contain 'active@contoso.com'
        }

        It 'includes inactive users past the threshold' {
            $results.UserPrincipalName | Should -Contain 'inactive@contoso.com'
        }

        It 'includes never-signed-in users with old accounts' {
            $results.UserPrincipalName | Should -Contain 'never@contoso.com'
        }

        It 'excludes guest users' {
            $results.UserPrincipalName | Should -Not -Contain 'guest_ext@contoso.com'
        }

        It 'excludes recently created never-signed-in users' {
            $results.UserPrincipalName | Should -Not -Contain 'newuser@contoso.com'
        }

        It 'shows "Never" for users who never signed in' {
            $neverUser = $results | Where-Object UserPrincipalName -eq 'never@contoso.com'
            $neverUser.LastSignIn | Should -Be 'Never'
            $neverUser.DaysSinceSignIn | Should -Be 'Never'
        }

        It 'calculates DaysSinceSignIn for inactive users' {
            $inactiveUser = $results | Where-Object UserPrincipalName -eq 'inactive@contoso.com'
            [int]$inactiveUser.DaysSinceSignIn | Should -BeGreaterOrEqual 120
        }
    }

    Context 'LicensedOnly switch' {
        BeforeAll {
            $results = Invoke-ScriptUnderTest -ScriptPath $scriptPath -Parameters @{
                InactiveDays = 90
                LicensedOnly = $true
            }
        }

        It 'only includes users with licenses' {
            $results | ForEach-Object { $_.LicenseCount | Should -BeGreaterThan 0 }
        }
    }

    Context 'Result properties' {
        BeforeAll {
            $results = Invoke-ScriptUnderTest -ScriptPath $scriptPath -Parameters @{ InactiveDays = 90 }
        }

        It 'result objects have expected properties' {
            $props = $results[0].PSObject.Properties.Name
            $props | Should -Contain 'DisplayName'
            $props | Should -Contain 'UserPrincipalName'
            $props | Should -Contain 'AccountEnabled'
            $props | Should -Contain 'LicenseCount'
            $props | Should -Contain 'LastSignIn'
            $props | Should -Contain 'DaysSinceSignIn'
        }
    }
}
