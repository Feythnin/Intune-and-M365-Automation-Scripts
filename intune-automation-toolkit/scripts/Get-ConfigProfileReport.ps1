<#
.SYNOPSIS
    Reports on Intune device configuration profile assignments and per-device status.

.DESCRIPTION
    Queries all device configuration profiles and their assignment status across
    managed devices. Shows success, error, conflict, and pending counts per profile.
    Useful for troubleshooting profile deployment issues and identifying conflicts.

.PARAMETER ProfileName
    Optional filter by profile display name.

.PARAMETER StatusFilter
    Optional filter by assignment status: Succeeded, Error, Conflict, Pending, NotApplicable.

.PARAMETER ExportPath
    Optional CSV export path.

.EXAMPLE
    .\Get-ConfigProfileReport.ps1
    Shows status for all configuration profiles.

.EXAMPLE
    .\Get-ConfigProfileReport.ps1 -ProfileName "Wi-Fi" -StatusFilter "Error"

.EXAMPLE
    .\Get-ConfigProfileReport.ps1 -ExportPath ".\reports\config-profiles.csv"

.NOTES
    Requires: Microsoft.Graph.DeviceManagement module
    Permissions: DeviceManagementConfiguration.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ProfileName,

    [Parameter()]
    [ValidateSet("Succeeded", "Error", "Conflict", "Pending", "NotApplicable")]
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

Write-Host "Querying device configuration profiles..." -ForegroundColor Cyan

try {
    # Get all configuration profiles
    $profiles = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations" -OutputType PSObject

    if (-not $profiles.value -or $profiles.value.Count -eq 0) {
        Write-Host "No configuration profiles found." -ForegroundColor Yellow
        return
    }

    $profileList = $profiles.value

    if ($ProfileName) {
        $profileList = $profileList | Where-Object { $_.displayName -like "*$ProfileName*" }
        if ($profileList.Count -eq 0) {
            Write-Host "No profiles found matching '$ProfileName'." -ForegroundColor Yellow
            return
        }
    }

    Write-Host "Found $($profileList.Count) configuration profile(s). Checking status...`n" -ForegroundColor Cyan

    $allResults = [System.Collections.Generic.List[PSCustomObject]]::new()
    $profileSummaries = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($profile in $profileList) {
        Write-Host "  Checking: $($profile.displayName)..." -ForegroundColor Gray

        try {
            # Get device status for this profile
            $statusUri = "https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations/$($profile.id)/deviceStatuses"
            $statuses = @()
            $nextLink = $statusUri

            do {
                $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink -OutputType PSObject
                $statuses += $response.value
                $nextLink = $response.'@odata.nextLink'
            } while ($nextLink)

            $succeeded = 0
            $errors = 0
            $conflicts = 0
            $pending = 0
            $notApplicable = 0

            foreach ($status in $statuses) {
                $state = $status.status
                switch ($state) {
                    "succeeded" { $succeeded++ }
                    "error" { $errors++ }
                    "conflict" { $conflicts++ }
                    "notApplicable" { $notApplicable++ }
                    default { $pending++ }
                }

                $allResults.Add([PSCustomObject]@{
                    ProfileName    = $profile.displayName
                    ProfileType    = $profile.'@odata.type' -replace '#microsoft.graph.', ''
                    DeviceName     = $status.deviceDisplayName
                    UserPrincipal  = $status.userPrincipalName
                    Status         = $state
                    LastReported   = if ($status.lastReportedDateTime) { $status.lastReportedDateTime } else { "Unknown" }
                    ProfileId      = $profile.id
                })
            }

            $profileSummaries.Add([PSCustomObject]@{
                ProfileName    = $profile.displayName
                ProfileType    = $profile.'@odata.type' -replace '#microsoft.graph.', ''
                TotalDevices   = $statuses.Count
                Succeeded      = $succeeded
                Error          = $errors
                Conflict       = $conflicts
                Pending        = $pending
                NotApplicable  = $notApplicable
                SuccessRate    = if ($statuses.Count -gt 0) { "$([math]::Round(($succeeded / $statuses.Count) * 100, 1))%" } else { "N/A" }
            })
        } catch {
            Write-Host "    Could not retrieve status for $($profile.displayName): $_" -ForegroundColor Yellow
        }

        Start-Sleep -Milliseconds 300
    }

    # Apply status filter
    if ($StatusFilter) {
        $filterMap = @{
            "Succeeded"     = "succeeded"
            "Error"         = "error"
            "Conflict"      = "conflict"
            "Pending"       = "pending"
            "NotApplicable" = "notApplicable"
        }
        $allResults = [System.Collections.Generic.List[PSCustomObject]]::new(
            [PSCustomObject[]]($allResults | Where-Object { $_.Status -eq $filterMap[$StatusFilter] })
        )
    }

    # === Dashboard ===
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  CONFIGURATION PROFILE REPORT" -ForegroundColor Cyan
    Write-Host "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "Profiles: $($profileSummaries.Count)" -ForegroundColor White

    $totalErrors = ($profileSummaries | Measure-Object -Property Error -Sum).Sum
    $totalConflicts = ($profileSummaries | Measure-Object -Property Conflict -Sum).Sum

    if ($totalErrors -gt 0) {
        Write-Host "Total errors across all profiles: $totalErrors" -ForegroundColor Red
    }
    if ($totalConflicts -gt 0) {
        Write-Host "Total conflicts across all profiles: $totalConflicts" -ForegroundColor Yellow
    }

    # Profile summary table
    $profileSummaries | Format-Table ProfileName, TotalDevices, Succeeded, Error, Conflict, Pending, SuccessRate -AutoSize

    # Show error details
    $errorDetails = $allResults | Where-Object Status -eq "error"
    if ($errorDetails.Count -gt 0 -and $errorDetails.Count -le 30) {
        Write-Host "Error Details:" -ForegroundColor Red
        $errorDetails | Format-Table ProfileName, DeviceName, UserPrincipal, LastReported -AutoSize
    } elseif ($errorDetails.Count -gt 30) {
        Write-Host "$($errorDetails.Count) errors found — export to CSV for full details." -ForegroundColor Red
    }

    # Show conflict details
    $conflictDetails = $allResults | Where-Object Status -eq "conflict"
    if ($conflictDetails.Count -gt 0 -and $conflictDetails.Count -le 20) {
        Write-Host "Conflict Details:" -ForegroundColor Yellow
        $conflictDetails | Format-Table ProfileName, DeviceName, UserPrincipal -AutoSize
    } elseif ($conflictDetails.Count -gt 20) {
        Write-Host "$($conflictDetails.Count) conflicts found — export to CSV for full details." -ForegroundColor Yellow
    }

    # Export
    if ($ExportPath) {
        $exportDir = Split-Path $ExportPath -Parent
        if ($exportDir -and -not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }
        $allResults | Export-Csv -Path $ExportPath -NoTypeInformation
        Write-Host "Report exported to: $ExportPath" -ForegroundColor Green
    }

    return $allResults

} catch {
    Write-Error "Failed to generate configuration profile report: $_"
    exit 1
}
