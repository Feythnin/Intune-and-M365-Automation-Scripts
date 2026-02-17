BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelper.ps1')
    $scriptPath = Join-Path $PSScriptRoot '..' 'scripts' 'Get-ComplianceReport.ps1'
}

Describe 'Get-ComplianceReport' {

    BeforeAll {
        # Define stubs for Graph cmdlets (not installed on CI runners)
        function Get-MgContext { }
        function Get-MgDeviceManagementManagedDevice { }

        # Mock Graph context check
        Mock Get-MgContext { [PSCustomObject]@{ TenantId = 'test-tenant-id' } }

        # Mock managed devices — mix of OS, compliance state, encryption
        Mock Get-MgDeviceManagementManagedDevice {
            @(
                [PSCustomObject]@{
                    DeviceName        = 'DESKTOP-WIN01'
                    UserPrincipalName = 'user1@contoso.com'
                    OperatingSystem   = 'Windows'
                    OsVersion         = '10.0.22631'
                    ComplianceState   = 'compliant'
                    IsEncrypted       = $true
                    LastSyncDateTime  = (Get-Date).AddDays(-1)
                    Model             = 'ThinkPad T14'
                    SerialNumber      = 'SN001'
                    Id                = 'device-001'
                }
                [PSCustomObject]@{
                    DeviceName        = 'DESKTOP-WIN02'
                    UserPrincipalName = 'user2@contoso.com'
                    OperatingSystem   = 'Windows'
                    OsVersion         = '10.0.19045'
                    ComplianceState   = 'noncompliant'
                    IsEncrypted       = $false
                    LastSyncDateTime  = (Get-Date).AddDays(-3)
                    Model             = 'Latitude 5530'
                    SerialNumber      = 'SN002'
                    Id                = 'device-002'
                }
                [PSCustomObject]@{
                    DeviceName        = 'MBP-MAC01'
                    UserPrincipalName = 'user3@contoso.com'
                    OperatingSystem   = 'macOS'
                    OsVersion         = '14.2'
                    ComplianceState   = 'compliant'
                    IsEncrypted       = $true
                    LastSyncDateTime  = (Get-Date).AddDays(-2)
                    Model             = 'MacBook Pro'
                    SerialNumber      = 'SN003'
                    Id                = 'device-003'
                }
                [PSCustomObject]@{
                    DeviceName        = 'IPHONE-01'
                    UserPrincipalName = 'user4@contoso.com'
                    OperatingSystem   = 'iOS'
                    OsVersion         = '17.2'
                    ComplianceState   = 'unknown'
                    IsEncrypted       = $true
                    LastSyncDateTime  = $null
                    Model             = 'iPhone 15'
                    SerialNumber      = 'SN004'
                    Id                = 'device-004'
                }
            )
        }

        Mock Export-Csv {}
        Mock New-Item {}
        Mock Test-Path { $true }
    }

    Context 'Unfiltered report' {
        BeforeAll {
            $results = Invoke-ScriptUnderTest -ScriptPath $scriptPath
        }

        It 'returns all devices' {
            $results | Should -HaveCount 4
        }

        It 'result objects have expected properties' {
            $results[0].PSObject.Properties.Name | Should -Contain 'DeviceName'
            $results[0].PSObject.Properties.Name | Should -Contain 'ComplianceState'
            $results[0].PSObject.Properties.Name | Should -Contain 'IsEncrypted'
            $results[0].PSObject.Properties.Name | Should -Contain 'OperatingSystem'
        }

        It 'maps compliance state correctly' {
            ($results | Where-Object ComplianceState -eq 'compliant') | Should -HaveCount 2
            ($results | Where-Object ComplianceState -eq 'noncompliant') | Should -HaveCount 1
        }
    }

    Context 'OS filtering' {
        BeforeAll {
            $results = Invoke-ScriptUnderTest -ScriptPath $scriptPath -Parameters @{ OSFilter = 'Windows' }
        }

        It 'filters to only Windows devices' {
            $results | Should -HaveCount 2
            $results | ForEach-Object { $_.OperatingSystem | Should -BeLike '*Windows*' }
        }
    }

    Context 'CSV export' {
        It 'calls Export-Csv when ExportPath is provided' {
            Invoke-ScriptUnderTest -ScriptPath $scriptPath -Parameters @{ ExportPath = 'TestDrive:\report.csv' }
            Should -Invoke Export-Csv -Times 1
        }
    }
}
