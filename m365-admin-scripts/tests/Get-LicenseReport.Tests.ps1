BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelper.ps1')
    $scriptPath = Join-Path $PSScriptRoot '..' 'scripts' 'Get-LicenseReport.ps1'
}

Describe 'Get-LicenseReport' {

    BeforeAll {
        Mock Get-MgContext { [PSCustomObject]@{ TenantId = 'test-tenant-id' } }

        Mock Get-MgSubscribedSku {
            @(
                [PSCustomObject]@{
                    SkuPartNumber    = 'SPE_E3'
                    SkuId            = 'sku-001'
                    PrepaidUnits     = [PSCustomObject]@{ Enabled = 100 }
                    ConsumedUnits    = 87
                    CapabilityStatus = 'Enabled'
                }
                [PSCustomObject]@{
                    SkuPartNumber    = 'EXCHANGESTANDARD'
                    SkuId            = 'sku-002'
                    PrepaidUnits     = [PSCustomObject]@{ Enabled = 25 }
                    ConsumedUnits    = 22
                    CapabilityStatus = 'Enabled'
                }
                [PSCustomObject]@{
                    SkuPartNumber    = 'POWER_BI_PRO'
                    SkuId            = 'sku-003'
                    PrepaidUnits     = [PSCustomObject]@{ Enabled = 20 }
                    ConsumedUnits    = 8
                    CapabilityStatus = 'Enabled'
                }
                [PSCustomObject]@{
                    SkuPartNumber    = 'VISIOCLIENT'
                    SkuId            = 'sku-004'
                    PrepaidUnits     = [PSCustomObject]@{ Enabled = 5 }
                    ConsumedUnits    = 5
                    CapabilityStatus = 'Enabled'
                }
            )
        }

        Mock Export-Csv {}
        Mock New-Item {}
        Mock Test-Path { $true }
    }

    Context 'Full license summary' {
        BeforeAll {
            $results = Invoke-ScriptUnderTest -ScriptPath $scriptPath
        }

        It 'returns all SKUs' {
            $results | Should -HaveCount 4
        }

        It 'maps SKU part numbers to friendly names' {
            ($results | Where-Object License -eq 'Microsoft 365 E3') | Should -HaveCount 1
            ($results | Where-Object License -eq 'Exchange Online Plan 1') | Should -HaveCount 1
            ($results | Where-Object License -eq 'Power BI Pro') | Should -HaveCount 1
            ($results | Where-Object License -eq 'Visio Plan 2') | Should -HaveCount 1
        }

        It 'calculates available licenses correctly' {
            $e3 = $results | Where-Object SkuPartNumber -eq 'SPE_E3'
            $e3.Available | Should -Be 13
        }

        It 'calculates usage percentage' {
            $e3 = $results | Where-Object SkuPartNumber -eq 'SPE_E3'
            $e3.UsagePercent | Should -Be '87.0%'
        }

        It 'result objects have expected properties' {
            $results[0].PSObject.Properties.Name | Should -Contain 'License'
            $results[0].PSObject.Properties.Name | Should -Contain 'Total'
            $results[0].PSObject.Properties.Name | Should -Contain 'Assigned'
            $results[0].PSObject.Properties.Name | Should -Contain 'Available'
            $results[0].PSObject.Properties.Name | Should -Contain 'UsagePercent'
            $results[0].PSObject.Properties.Name | Should -Contain 'Status'
        }
    }

    Context 'SkuFilter parameter' {
        BeforeAll {
            $results = Invoke-ScriptUnderTest -ScriptPath $scriptPath -Parameters @{ SkuFilter = 'SPE_E3' }
        }

        It 'filters to matching SKUs only' {
            $results | Should -HaveCount 1
            $results[0].SkuPartNumber | Should -Be 'SPE_E3'
        }
    }

    Context 'CSV export' {
        It 'calls Export-Csv when ExportPath is provided' {
            Invoke-ScriptUnderTest -ScriptPath $scriptPath -Parameters @{ ExportPath = 'TestDrive:\licenses.csv' }
            Should -Invoke Export-Csv -Times 1
        }
    }
}
