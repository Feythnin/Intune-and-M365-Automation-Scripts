<#
.SYNOPSIS
    Reports on Windows update compliance including OS versions and patch status.

.DESCRIPTION
    Queries all Windows managed devices for their current OS build versions and
    compares against the fleet. Identifies devices running outdated builds and
    shows update ring assignments. Useful for patch management reporting and
    compliance tracking.

.PARAMETER ExportPath
    Optional CSV export path.

.PARAMETER MinBuild
    Optional minimum acceptable OS build number (e.g., "10.0.19045.3803").
    Devices below this build are flagged as outdated.

.EXAMPLE
    .\Get-WindowsUpdateCompliance.ps1
    Shows OS version distribution for all Windows devices.

.EXAMPLE
    .\Get-WindowsUpdateCompliance.ps1 -MinBuild "10.0.22631.3007" -ExportPath ".\reports\update-compliance.csv"

.NOTES
    Requires: Microsoft.Graph.DeviceManagement module
    Permissions: DeviceManagementManagedDevices.Read.All, DeviceManagementConfiguration.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ExportPath,

    [Parameter()]
    [string]$MinBuild
)

#Requires -Modules Microsoft.Graph.DeviceManagement

$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

Write-Host "Querying Windows device update compliance..." -ForegroundColor Cyan

try {
    # Get all Windows managed devices
    $allDevices = Get-MgDeviceManagementManagedDevice -All | Where-Object {
        $_.OperatingSystem -eq "Windows"
    }

    if ($allDevices.Count -eq 0) {
        Write-Host "No Windows managed devices found." -ForegroundColor Yellow
        return
    }

    Write-Host "Found $($allDevices.Count) Windows devices." -ForegroundColor Cyan

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($device in $allDevices) {
        $isOutdated = $false
        if ($MinBuild -and $device.OsVersion) {
            try {
                $isOutdated = [version]$device.OsVersion -lt [version]$MinBuild
            } catch {
                $isOutdated = $false
            }
        }

        # Parse the build for grouping
        $osBuild = $device.OsVersion
        $majorBuild = if ($osBuild -match '^\d+\.\d+\.\d+') { $Matches[0] } else { $osBuild }

        $daysSinceSync = if ($device.LastSyncDateTime) {
            ((Get-Date) - $device.LastSyncDateTime).Days
        } else { $null }

        $results.Add([PSCustomObject]@{
            DeviceName        = $device.DeviceName
            UserPrincipalName = $device.UserPrincipalName
            OSVersion         = $osBuild
            MajorBuild        = $majorBuild
            ComplianceState   = $device.ComplianceState
            IsEncrypted       = $device.IsEncrypted
            IsOutdated        = $isOutdated
            LastSync          = if ($device.LastSyncDateTime) { $device.LastSyncDateTime.ToString("yyyy-MM-dd HH:mm") } else { "Never" }
            DaysSinceSync     = if ($daysSinceSync) { $daysSinceSync } else { "Never" }
            Model             = $device.Model
            Manufacturer      = $device.Manufacturer
            SerialNumber      = $device.SerialNumber
        })
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new(
        [PSCustomObject[]]($results | Sort-Object OSVersion)
    )

    # === Dashboard ===
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  WINDOWS UPDATE COMPLIANCE" -ForegroundColor Cyan
    Write-Host "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "Total Windows devices: $($results.Count)" -ForegroundColor White

    if ($MinBuild) {
        $outdatedCount = ($results | Where-Object IsOutdated -eq $true).Count
        $currentCount = $results.Count - $outdatedCount
        $patchRate = if ($results.Count -gt 0) { [math]::Round(($currentCount / $results.Count) * 100, 1) } else { 0 }

        Write-Host "Minimum build: $MinBuild" -ForegroundColor White
        Write-Host "  Current:  $currentCount ($patchRate%)" -ForegroundColor Green
        Write-Host "  Outdated: $outdatedCount" -ForegroundColor $(if ($outdatedCount -gt 0) { "Red" } else { "Green" })
    }

    # OS version distribution
    Write-Host "`nOS Build Distribution:" -ForegroundColor Cyan
    $results | Group-Object MajorBuild | Sort-Object { try { [version]$_.Name } catch { $_.Name } } -Descending | ForEach-Object {
        $pct = [math]::Round(($_.Count / $results.Count) * 100, 1)
        Write-Host "  $($_.Name): $($_.Count) devices ($pct%)" -ForegroundColor White
    }

    # Compliance breakdown
    Write-Host "`nCompliance State:" -ForegroundColor Cyan
    $results | Group-Object ComplianceState | Sort-Object Count -Descending | ForEach-Object {
        $color = switch ($_.Name) {
            "compliant" { "Green" }
            "noncompliant" { "Red" }
            default { "Yellow" }
        }
        Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor $color
    }

    # Encryption status
    $encrypted = ($results | Where-Object IsEncrypted -eq $true).Count
    $encryptionRate = if ($results.Count -gt 0) { [math]::Round(($encrypted / $results.Count) * 100, 1) } else { 0 }
    Write-Host "`nEncrypted: $encrypted / $($results.Count) ($encryptionRate%)" -ForegroundColor White

    # Stale sync devices
    $staleSyncDevices = $results | Where-Object { $_.DaysSinceSync -ne "Never" -and [int]$_.DaysSinceSync -gt 14 }
    if ($staleSyncDevices.Count -gt 0) {
        Write-Host "`nDevices not synced in 14+ days: $($staleSyncDevices.Count)" -ForegroundColor Yellow
    }

    # Show outdated devices
    if ($MinBuild) {
        $outdated = $results | Where-Object IsOutdated -eq $true
        if ($outdated.Count -gt 0) {
            Write-Host "`nOutdated Devices:" -ForegroundColor Red
            $outdated | Format-Table DeviceName, UserPrincipalName, OSVersion, LastSync -AutoSize
        }
    } else {
        $results | Format-Table DeviceName, UserPrincipalName, OSVersion, ComplianceState, LastSync -AutoSize
    }

    # Export
    if ($ExportPath) {
        $exportDir = Split-Path $ExportPath -Parent
        if ($exportDir -and -not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }
        $results | Export-Csv -Path $ExportPath -NoTypeInformation
        Write-Host "Report exported to: $ExportPath" -ForegroundColor Green
    }

    return $results

} catch {
    Write-Error "Failed to generate Windows update compliance report: $_"
    exit 1
}
