<#
.SYNOPSIS
    Reports on Intune application deployment status across managed devices.

.DESCRIPTION
    Queries Microsoft Graph for app installation statuses, showing which apps
    succeeded, failed, or are pending across your managed device fleet.
    Useful for tracking rollouts and identifying deployment issues.

.PARAMETER AppName
    Optional filter to check status of a specific application.

.PARAMETER StatusFilter
    Optional filter by installation status: Installed, Failed, Pending, NotInstalled

.PARAMETER ExportPath
    Optional path to export results as CSV.

.EXAMPLE
    .\Get-AppDeploymentStatus.ps1
    Shows deployment status for all managed apps.

.EXAMPLE
    .\Get-AppDeploymentStatus.ps1 -AppName "Microsoft 365 Apps" -StatusFilter "Failed"

.NOTES
    Requires: Microsoft.Graph.DeviceManagement module
    Permissions: DeviceManagementApps.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$AppName,

    [Parameter()]
    [ValidateSet("Installed", "Failed", "Pending", "NotInstalled")]
    [string]$StatusFilter,

    [Parameter()]
    [string]$ExportPath
)

#Requires -Modules Microsoft.Graph.DeviceManagement

$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

Write-Host "Querying application deployments..." -ForegroundColor Cyan

try {
    # Get all managed apps
    $apps = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps?`$filter=isAssigned eq true&`$select=id,displayName,productVersion,publisher" -OutputType PSObject

    if (-not $apps.value -or $apps.value.Count -eq 0) {
        Write-Host "No assigned applications found." -ForegroundColor Yellow
        return
    }

    $appList = $apps.value

    # Filter by name if specified
    if ($AppName) {
        $appList = $appList | Where-Object { $_.displayName -like "*$AppName*" }
        if ($appList.Count -eq 0) {
            Write-Host "No apps found matching '$AppName'." -ForegroundColor Yellow
            return
        }
    }

    Write-Host "Found $($appList.Count) assigned application(s). Checking deployment status...`n" -ForegroundColor Cyan

    $allResults = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($app in $appList) {
        Write-Host "  Checking: $($app.displayName)..." -ForegroundColor Gray

        try {
            # Get device install statuses for this app
            $statusUri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$($app.id)/deviceStatuses"
            $statuses = Invoke-MgGraphRequest -Method GET -Uri $statusUri -OutputType PSObject

            if ($statuses.value) {
                foreach ($status in $statuses.value) {
                    $allResults.Add([PSCustomObject]@{
                        AppName          = $app.displayName
                        AppVersion       = $app.productVersion
                        Publisher        = $app.publisher
                        DeviceName       = $status.deviceName
                        UserPrincipal    = $status.userPrincipalName
                        InstallState     = $status.installState
                        ErrorCode        = $status.errorCode
                        LastModified     = if ($status.lastSyncDateTime) {
                            $status.lastSyncDateTime
                        } else { "Unknown" }
                    })
                }
            }
        } catch {
            Write-Host "    Could not retrieve status for $($app.displayName): $_" -ForegroundColor Yellow
        }

        # Throttle to avoid hitting rate limits
        Start-Sleep -Milliseconds 300
    }

    if ($allResults.Count -eq 0) {
        Write-Host "No deployment status data available." -ForegroundColor Yellow
        return
    }

    # Apply status filter
    if ($StatusFilter) {
        $filterMap = @{
            "Installed"    = "installed"
            "Failed"       = "failed"
            "Pending"      = "pendingInstall"
            "NotInstalled" = "notInstalled"
        }
        $allResults = $allResults | Where-Object { $_.InstallState -eq $filterMap[$StatusFilter] }
    }

    # === Summary ===
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  APP DEPLOYMENT REPORT" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # Per-app summary
    $appGroups = $allResults | Group-Object AppName
    foreach ($group in $appGroups) {
        $total = $group.Count
        $installed = ($group.Group | Where-Object InstallState -eq "installed").Count
        $failed = ($group.Group | Where-Object InstallState -eq "failed").Count
        $pending = ($group.Group | Where-Object InstallState -like "*pending*").Count
        $successRate = if ($total -gt 0) { [math]::Round(($installed / $total) * 100, 1) } else { 0 }

        Write-Host "$($group.Name)" -ForegroundColor White
        Write-Host "  Installed: $installed | Failed: $failed | Pending: $pending | Success Rate: $successRate%" -ForegroundColor $(
            if ($failed -gt 0) { "Yellow" } else { "Green" }
        )
    }

    # Show failures detail
    $failures = $allResults | Where-Object InstallState -eq "failed"
    if ($failures.Count -gt 0) {
        Write-Host "`nFailed Installations:" -ForegroundColor Red
        $failures | Format-Table AppName, DeviceName, UserPrincipal, ErrorCode -AutoSize
    }

    # Export
    if ($ExportPath) {
        $exportDir = Split-Path $ExportPath -Parent
        if ($exportDir -and -not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }
        $allResults | Export-Csv -Path $ExportPath -NoTypeInformation
        Write-Host "`nFull report exported to: $ExportPath" -ForegroundColor Green
    }

    return $allResults

} catch {
    Write-Error "Failed to query app deployment status: $_"
    exit 1
}
