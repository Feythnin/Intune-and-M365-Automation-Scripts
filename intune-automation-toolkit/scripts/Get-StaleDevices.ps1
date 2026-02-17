<#
.SYNOPSIS
    Identifies Intune-managed devices that haven't checked in within a specified number of days.

.DESCRIPTION
    Queries Microsoft Graph for all managed devices and filters by last sync date.
    Useful for identifying devices that may be lost, decommissioned, or out of compliance.
    Supports filtering by OS and exporting results to CSV.

.PARAMETER InactiveDays
    Number of days since last sync to consider a device stale. Default: 30

.PARAMETER OSFilter
    Optional filter by operating system. Values: Windows, macOS, iOS, Android

.PARAMETER ExportPath
    Optional path to export results as CSV.

.EXAMPLE
    .\Get-StaleDevices.ps1
    Returns all devices inactive for 30+ days.

.EXAMPLE
    .\Get-StaleDevices.ps1 -InactiveDays 60 -OSFilter "Windows" -ExportPath ".\stale.csv"
    Returns Windows devices inactive for 60+ days and exports to CSV.

.NOTES
    Requires: Microsoft.Graph.DeviceManagement module
    Permissions: DeviceManagementManagedDevices.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [int]$InactiveDays = 30,

    [Parameter()]
    [ValidateSet("Windows", "macOS", "iOS", "Android")]
    [string]$OSFilter,

    [Parameter()]
    [string]$ExportPath
)

#Requires -Modules Microsoft.Graph.DeviceManagement

# Verify Graph connection
$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

Write-Host "Querying managed devices..." -ForegroundColor Cyan

$cutoffDate = (Get-Date).AddDays(-$InactiveDays)

try {
    # Pull all managed devices
    $allDevices = Get-MgDeviceManagementManagedDevice -All

    # Filter to stale devices
    $staleDevices = $allDevices | Where-Object {
        $_.LastSyncDateTime -and $_.LastSyncDateTime -lt $cutoffDate
    }

    # Apply OS filter if specified
    if ($OSFilter) {
        $staleDevices = $staleDevices | Where-Object {
            $_.OperatingSystem -like "*$OSFilter*"
        }
    }

    if ($staleDevices.Count -eq 0) {
        Write-Host "No stale devices found (inactive > $InactiveDays days)." -ForegroundColor Green
        return
    }

    # Build results
    $results = $staleDevices | ForEach-Object {
        $daysSinceSync = ((Get-Date) - $_.LastSyncDateTime).Days

        [PSCustomObject]@{
            DeviceName       = $_.DeviceName
            UserPrincipalName = $_.UserPrincipalName
            OperatingSystem  = $_.OperatingSystem
            OSVersion        = $_.OsVersion
            ComplianceState  = $_.ComplianceState
            LastSync         = $_.LastSyncDateTime.ToString("yyyy-MM-dd")
            DaysSinceSync    = $daysSinceSync
            SerialNumber     = $_.SerialNumber
            Model            = $_.Model
            Manufacturer     = $_.Manufacturer
            DeviceId         = $_.Id
            EnrollmentType   = $_.DeviceEnrollmentType
        }
    } | Sort-Object DaysSinceSync -Descending

    # Display summary
    Write-Host "`nFound $($results.Count) stale devices (inactive > $InactiveDays days)" -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Yellow

    # Group by OS for summary
    $results | Group-Object OperatingSystem | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count) devices" -ForegroundColor White
    }

    # Display table
    $results | Format-Table DeviceName, UserPrincipalName, OperatingSystem, LastSync, DaysSinceSync, ComplianceState -AutoSize

    # Export if requested
    if ($ExportPath) {
        $exportDir = Split-Path $ExportPath -Parent
        if ($exportDir -and -not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }
        $results | Export-Csv -Path $ExportPath -NoTypeInformation
        Write-Host "Results exported to: $ExportPath" -ForegroundColor Green
    }

    return $results

} catch {
    Write-Error "Failed to query devices: $_"
    exit 1
}
