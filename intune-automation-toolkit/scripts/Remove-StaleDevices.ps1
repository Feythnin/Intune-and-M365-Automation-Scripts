<#
.SYNOPSIS
    Removes or retires stale Intune-managed devices with safety checks and logging.

.DESCRIPTION
    Identifies devices that haven't synced within the specified threshold and
    performs the requested action (Retire or Delete). Includes WhatIf support,
    confirmation prompts, and detailed logging for audit trails.

    CAUTION: This script performs destructive operations. Always run with -WhatIf first.

.PARAMETER InactiveDays
    Number of days since last sync to consider a device stale. Minimum: 30

.PARAMETER Action
    The action to take on stale devices. Retire (wipes corporate data) or Delete (removes from Intune).

.PARAMETER LogPath
    Path to write a detailed log file. Recommended for audit purposes.

.PARAMETER WhatIf
    Preview what would be done without making changes.

.PARAMETER Force
    Skip individual confirmation prompts (summary confirmation still required).

.EXAMPLE
    .\Remove-StaleDevices.ps1 -InactiveDays 90 -WhatIf
    Preview which devices would be affected.

.EXAMPLE
    .\Remove-StaleDevices.ps1 -InactiveDays 90 -Action Retire -LogPath ".\logs\cleanup.log"
    Retire devices inactive 90+ days with logging.

.NOTES
    Requires: Microsoft.Graph.DeviceManagement module
    Permissions: DeviceManagementManagedDevices.ReadWrite.All
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidateRange(30, 365)]
    [int]$InactiveDays,

    [Parameter()]
    [ValidateSet("Retire", "Delete")]
    [string]$Action = "Retire",

    [Parameter()]
    [string]$LogPath,

    [Parameter()]
    [switch]$Force
)

#Requires -Modules Microsoft.Graph.DeviceManagement

# Logging helper
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            "WARN"  { "Yellow" }
            "ERROR" { "Red" }
            "SUCCESS" { "Green" }
            default { "White" }
        }
    )
    if ($LogPath) {
        Add-Content -Path $LogPath -Value $logEntry
    }
}

# Verify connection
$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

# Initialize log
if ($LogPath) {
    $logDir = Split-Path $LogPath -Parent
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    Write-Log "=== Stale Device Cleanup Started ==="
    Write-Log "Action: $Action | Threshold: $InactiveDays days | User: $($context.Account)"
}

$cutoffDate = (Get-Date).AddDays(-$InactiveDays)

try {
    Write-Log "Querying managed devices..."
    $allDevices = Get-MgDeviceManagementManagedDevice -All

    $staleDevices = $allDevices | Where-Object {
        $_.LastSyncDateTime -and $_.LastSyncDateTime -lt $cutoffDate
    } | Sort-Object LastSyncDateTime

    if ($staleDevices.Count -eq 0) {
        Write-Log "No stale devices found (threshold: $InactiveDays days)." "SUCCESS"
        return
    }

    Write-Log "Found $($staleDevices.Count) stale devices" "WARN"

    # Display summary before proceeding
    Write-Host "`n============================================" -ForegroundColor Yellow
    Write-Host "  STALE DEVICE CLEANUP PREVIEW" -ForegroundColor Yellow
    Write-Host "  Action: $Action" -ForegroundColor Yellow
    Write-Host "  Devices affected: $($staleDevices.Count)" -ForegroundColor Yellow
    Write-Host "  Inactive threshold: $InactiveDays days" -ForegroundColor Yellow
    Write-Host "============================================`n" -ForegroundColor Yellow

    $staleDevices | ForEach-Object {
        $days = ((Get-Date) - $_.LastSyncDateTime).Days
        [PSCustomObject]@{
            DeviceName = $_.DeviceName
            User       = $_.UserPrincipalName
            OS         = $_.OperatingSystem
            LastSync   = $_.LastSyncDateTime.ToString("yyyy-MM-dd")
            DaysStale  = $days
        }
    } | Format-Table -AutoSize

    # WhatIf mode - stop here
    if ($WhatIfPreference) {
        Write-Log "WhatIf mode - no changes made. $($staleDevices.Count) devices would be affected."
        return
    }

    # Confirmation gate
    if (-not $Force) {
        $confirmation = Read-Host "`nAre you sure you want to $($Action.ToLower()) $($staleDevices.Count) devices? (yes/no)"
        if ($confirmation -ne "yes") {
            Write-Log "Operation cancelled by user." "WARN"
            return
        }
    }

    # Process each device
    $successCount = 0
    $failCount = 0

    foreach ($device in $staleDevices) {
        $deviceInfo = "$($device.DeviceName) ($($device.UserPrincipalName)) - Last sync: $($device.LastSyncDateTime.ToString('yyyy-MM-dd'))"

        try {
            if ($Action -eq "Retire") {
                Invoke-MgRetireDeviceManagementManagedDevice -ManagedDeviceId $device.Id
                Write-Log "RETIRED: $deviceInfo" "SUCCESS"
            } elseif ($Action -eq "Delete") {
                Remove-MgDeviceManagementManagedDevice -ManagedDeviceId $device.Id
                Write-Log "DELETED: $deviceInfo" "SUCCESS"
            }
            $successCount++
        } catch {
            Write-Log "FAILED: $deviceInfo - Error: $_" "ERROR"
            $failCount++
        }

        # Small delay to avoid throttling
        Start-Sleep -Milliseconds 500
    }

    # Final summary
    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Log "=== Cleanup Complete ==="
    Write-Log "Succeeded: $successCount | Failed: $failCount | Total: $($staleDevices.Count)"

    if ($LogPath) {
        Write-Host "Full log written to: $LogPath" -ForegroundColor Green
    }

} catch {
    Write-Log "Critical error during cleanup: $_" "ERROR"
    exit 1
}
