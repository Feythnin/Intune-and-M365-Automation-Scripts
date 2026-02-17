<#
.SYNOPSIS
    Exports a complete inventory of all Intune-managed devices to CSV.

.DESCRIPTION
    Pulls comprehensive device information from Microsoft Graph including hardware
    specs, OS details, compliance status, encryption state, and enrollment info.
    Designed for asset management, audit preparation, and capacity planning.

.PARAMETER ExportPath
    Path for the CSV export. Default: .\DeviceInventory_<date>.csv

.PARAMETER OSFilter
    Optional filter by operating system.

.EXAMPLE
    .\Export-DeviceInventory.ps1
    Exports full inventory to default path.

.EXAMPLE
    .\Export-DeviceInventory.ps1 -ExportPath ".\reports\inventory.csv" -OSFilter "Windows"

.NOTES
    Requires: Microsoft.Graph.DeviceManagement module
    Permissions: DeviceManagementManagedDevices.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ExportPath = ".\DeviceInventory_$(Get-Date -Format 'yyyyMMdd').csv",

    [Parameter()]
    [ValidateSet("Windows", "macOS", "iOS", "Android")]
    [string]$OSFilter
)

#Requires -Modules Microsoft.Graph.DeviceManagement

$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

Write-Host "Pulling device inventory from Intune..." -ForegroundColor Cyan

try {
    $devices = Get-MgDeviceManagementManagedDevice -All

    if ($OSFilter) {
        $devices = $devices | Where-Object { $_.OperatingSystem -like "*$OSFilter*" }
    }

    if ($devices.Count -eq 0) {
        Write-Host "No devices found." -ForegroundColor Yellow
        return
    }

    $inventory = $devices | ForEach-Object {
        [PSCustomObject]@{
            DeviceName             = $_.DeviceName
            UserPrincipalName      = $_.UserPrincipalName
            UserDisplayName        = $_.UserDisplayName
            OperatingSystem        = $_.OperatingSystem
            OSVersion              = $_.OsVersion
            Model                  = $_.Model
            Manufacturer           = $_.Manufacturer
            SerialNumber           = $_.SerialNumber
            ComplianceState        = $_.ComplianceState
            IsEncrypted            = $_.IsEncrypted
            IsSupervised           = $_.IsSupervised
            DeviceEnrollmentType   = $_.DeviceEnrollmentType
            ManagementAgent        = $_.ManagementAgent
            EnrolledDateTime       = if ($_.EnrolledDateTime) { $_.EnrolledDateTime.ToString("yyyy-MM-dd") } else { "" }
            LastSyncDateTime       = if ($_.LastSyncDateTime) { $_.LastSyncDateTime.ToString("yyyy-MM-dd HH:mm") } else { "Never" }
            TotalStorageSpaceGB    = if ($_.TotalStorageSpaceInBytes) { [math]::Round($_.TotalStorageSpaceInBytes / 1GB, 1) } else { "" }
            FreeStorageSpaceGB     = if ($_.FreeStorageSpaceInBytes) { [math]::Round($_.FreeStorageSpaceInBytes / 1GB, 1) } else { "" }
            StorageUsedPercent     = if ($_.TotalStorageSpaceInBytes -and $_.TotalStorageSpaceInBytes -gt 0) {
                [math]::Round((($_.TotalStorageSpaceInBytes - $_.FreeStorageSpaceInBytes) / $_.TotalStorageSpaceInBytes) * 100, 1)
            } else { "" }
            WiFiMacAddress         = $_.WiFiMacAddress
            EthernetMacAddress     = $_.EthernetMacAddress
            AzureADDeviceId        = $_.AzureADDeviceId
            IntuneDeviceId         = $_.Id
        }
    } | Sort-Object DeviceName

    # Summary
    Write-Host "`nInventory Summary" -ForegroundColor Cyan
    Write-Host "=================" -ForegroundColor Cyan
    Write-Host "Total devices: $($inventory.Count)" -ForegroundColor White

    $inventory | Group-Object OperatingSystem | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor White
    }

    Write-Host "`nTop Manufacturers:" -ForegroundColor Cyan
    $inventory | Group-Object Manufacturer | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count) devices" -ForegroundColor Gray
    }

    # Low storage warning
    $lowStorage = $inventory | Where-Object { $_.StorageUsedPercent -ne "" -and $_.StorageUsedPercent -gt 90 }
    if ($lowStorage.Count -gt 0) {
        Write-Host "`nWARNING: $($lowStorage.Count) devices with >90% storage used:" -ForegroundColor Red
        $lowStorage | Format-Table DeviceName, UserPrincipalName, TotalStorageSpaceGB, FreeStorageSpaceGB, StorageUsedPercent -AutoSize
    }

    # Export
    $exportDir = Split-Path $ExportPath -Parent
    if ($exportDir -and -not (Test-Path $exportDir)) {
        New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
    }
    $inventory | Export-Csv -Path $ExportPath -NoTypeInformation
    Write-Host "`nInventory exported to: $ExportPath" -ForegroundColor Green

    return $inventory

} catch {
    Write-Error "Failed to export device inventory: $_"
    exit 1
}
