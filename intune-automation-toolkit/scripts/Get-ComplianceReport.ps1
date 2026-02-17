<#
.SYNOPSIS
    Generates a compliance status report for all Intune-managed devices.

.DESCRIPTION
    Queries Microsoft Graph for device compliance states and generates a summary
    report with breakdowns by OS, compliance state, and policy. Useful for
    weekly reporting and audit preparation.

.PARAMETER OSFilter
    Optional filter by operating system.

.PARAMETER ExportPath
    Optional path to export the full report as CSV.

.EXAMPLE
    .\Get-ComplianceReport.ps1
    Generates a compliance summary for all devices.

.EXAMPLE
    .\Get-ComplianceReport.ps1 -OSFilter "Windows" -ExportPath ".\compliance.csv"
    Generates a Windows-only compliance report and exports to CSV.

.NOTES
    Requires: Microsoft.Graph.DeviceManagement module
    Permissions: DeviceManagementManagedDevices.Read.All, DeviceManagementConfiguration.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("Windows", "macOS", "iOS", "Android")]
    [string]$OSFilter,

    [Parameter()]
    [string]$ExportPath
)

#Requires -Modules Microsoft.Graph.DeviceManagement

$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

Write-Host "Generating compliance report..." -ForegroundColor Cyan

try {
    $allDevices = Get-MgDeviceManagementManagedDevice -All

    if ($OSFilter) {
        $allDevices = $allDevices | Where-Object {
            $_.OperatingSystem -like "*$OSFilter*"
        }
    }

    $totalDevices = $allDevices.Count

    if ($totalDevices -eq 0) {
        Write-Host "No managed devices found." -ForegroundColor Yellow
        return
    }

    # Build detailed results
    $results = $allDevices | ForEach-Object {
        [PSCustomObject]@{
            DeviceName        = $_.DeviceName
            UserPrincipalName = $_.UserPrincipalName
            OperatingSystem   = $_.OperatingSystem
            OSVersion         = $_.OsVersion
            ComplianceState   = $_.ComplianceState
            IsEncrypted       = $_.IsEncrypted
            LastSync          = if ($_.LastSyncDateTime) { $_.LastSyncDateTime.ToString("yyyy-MM-dd HH:mm") } else { "Never" }
            Model             = $_.Model
            SerialNumber      = $_.SerialNumber
            DeviceId          = $_.Id
        }
    }

    # === Summary Dashboard ===
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  COMPLIANCE REPORT" -ForegroundColor Cyan
    Write-Host "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # Overall stats
    $complianceGroups = $results | Group-Object ComplianceState
    $compliant = ($complianceGroups | Where-Object Name -eq "compliant").Count
    $nonCompliant = ($complianceGroups | Where-Object Name -eq "noncompliant").Count
    $unknown = $totalDevices - $compliant - $nonCompliant

    $complianceRate = if ($totalDevices -gt 0) { [math]::Round(($compliant / $totalDevices) * 100, 1) } else { 0 }

    Write-Host "Total Managed Devices: $totalDevices" -ForegroundColor White
    Write-Host "  Compliant:     $compliant ($complianceRate%)" -ForegroundColor Green
    Write-Host "  Non-Compliant: $nonCompliant" -ForegroundColor Red
    Write-Host "  Unknown/Other: $unknown" -ForegroundColor Yellow

    # Breakdown by OS
    Write-Host "`nBy Operating System:" -ForegroundColor Cyan
    $results | Group-Object OperatingSystem | ForEach-Object {
        $osTotal = $_.Count
        $osCompliant = ($_.Group | Where-Object ComplianceState -eq "compliant").Count
        $osRate = if ($osTotal -gt 0) { [math]::Round(($osCompliant / $osTotal) * 100, 1) } else { 0 }
        Write-Host "  $($_.Name): $osTotal devices ($osRate% compliant)" -ForegroundColor White
    }

    # Encryption status
    $encrypted = ($results | Where-Object IsEncrypted -eq $true).Count
    $encryptionRate = if ($totalDevices -gt 0) { [math]::Round(($encrypted / $totalDevices) * 100, 1) } else { 0 }
    Write-Host "`nEncryption Status:" -ForegroundColor Cyan
    Write-Host "  Encrypted: $encrypted / $totalDevices ($encryptionRate%)" -ForegroundColor White

    # List non-compliant devices
    $nonCompliantDevices = $results | Where-Object ComplianceState -eq "noncompliant"
    if ($nonCompliantDevices.Count -gt 0) {
        Write-Host "`nNon-Compliant Devices:" -ForegroundColor Red
        $nonCompliantDevices | Format-Table DeviceName, UserPrincipalName, OperatingSystem, OSVersion, LastSync -AutoSize
    }

    # Export
    if ($ExportPath) {
        $exportDir = Split-Path $ExportPath -Parent
        if ($exportDir -and -not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }
        $results | Export-Csv -Path $ExportPath -NoTypeInformation
        Write-Host "Full report exported to: $ExportPath" -ForegroundColor Green
    }

    return $results

} catch {
    Write-Error "Failed to generate compliance report: $_"
    exit 1
}
