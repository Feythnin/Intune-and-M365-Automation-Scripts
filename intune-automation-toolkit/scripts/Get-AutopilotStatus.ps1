<#
.SYNOPSIS
    Reports on Windows Autopilot deployment profiles, device assignments, and enrollment status.

.DESCRIPTION
    Queries Autopilot device identities and deployment profiles to provide a 
    comprehensive view of Autopilot readiness and enrollment state across the tenant.

.PARAMETER ExportPath
    Optional path to export results as CSV.

.PARAMETER ShowUnassigned
    Show only devices without a deployment profile assigned.

.EXAMPLE
    .\Get-AutopilotStatus.ps1
    Shows all Autopilot devices and their profile assignments.

.EXAMPLE
    .\Get-AutopilotStatus.ps1 -ShowUnassigned -ExportPath ".\unassigned.csv"

.NOTES
    Requires: Microsoft.Graph.DeviceManagement module
    Permissions: DeviceManagementServiceConfig.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ExportPath,

    [Parameter()]
    [switch]$ShowUnassigned
)

#Requires -Modules Microsoft.Graph.DeviceManagement

$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

Write-Host "Querying Autopilot devices and profiles..." -ForegroundColor Cyan

try {
    # Get Autopilot devices
    $autopilotDevices = Get-MgDeviceManagementWindowsAutopilotDeviceIdentity -All

    if ($autopilotDevices.Count -eq 0) {
        Write-Host "No Autopilot devices found in this tenant." -ForegroundColor Yellow
        return
    }

    # Get deployment profiles for reference
    $profiles = Get-MgDeviceManagementWindowsAutopilotDeploymentProfile -All
    $profileLookup = @{}
    foreach ($profile in $profiles) {
        $profileLookup[$profile.Id] = $profile.DisplayName
    }

    # Build results
    $results = $autopilotDevices | ForEach-Object {
        $profileName = if ($_.DeploymentProfileAssignmentStatus -eq "assigned" -and $_.DeploymentProfileAssignedDateTime) {
            if ($profileLookup.ContainsKey($_.DeploymentProfileId)) {
                $profileLookup[$_.DeploymentProfileId]
            } else {
                "Assigned (unknown profile)"
            }
        } else {
            "Not Assigned"
        }

        [PSCustomObject]@{
            SerialNumber             = $_.SerialNumber
            Model                    = $_.Model
            Manufacturer             = $_.Manufacturer
            GroupTag                 = $_.GroupTag
            ProfileName              = $profileName
            ProfileAssignmentStatus  = $_.DeploymentProfileAssignmentStatus
            ProfileAssignedDate      = if ($_.DeploymentProfileAssignedDateTime) {
                $_.DeploymentProfileAssignedDateTime.ToString("yyyy-MM-dd")
            } else { "N/A" }
            EnrollmentState          = $_.EnrollmentState
            LastContactedDateTime    = if ($_.LastContactedDateTime) {
                $_.LastContactedDateTime.ToString("yyyy-MM-dd HH:mm")
            } else { "Never" }
            AddressableUserName      = $_.AddressableUserName
            UserPrincipalName        = $_.UserPrincipalName
            DeviceId                 = $_.Id
        }
    }

    # Filter unassigned if requested
    if ($ShowUnassigned) {
        $results = $results | Where-Object { $_.ProfileAssignmentStatus -ne "assigned" }
    }

    # Summary
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  AUTOPILOT STATUS REPORT" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "Total Autopilot Devices: $($autopilotDevices.Count)" -ForegroundColor White
    Write-Host "Deployment Profiles: $($profiles.Count)" -ForegroundColor White

    # Assignment summary
    $assigned = ($results | Where-Object ProfileAssignmentStatus -eq "assigned").Count
    $notAssigned = $results.Count - $assigned
    Write-Host "`nProfile Assignment:" -ForegroundColor Cyan
    Write-Host "  Assigned:     $assigned" -ForegroundColor Green
    Write-Host "  Not Assigned: $notAssigned" -ForegroundColor $(if ($notAssigned -gt 0) { "Yellow" } else { "Green" })

    # Enrollment state summary
    Write-Host "`nEnrollment States:" -ForegroundColor Cyan
    $results | Group-Object EnrollmentState | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor White
    }

    # List profiles
    if ($profiles.Count -gt 0) {
        Write-Host "`nDeployment Profiles:" -ForegroundColor Cyan
        foreach ($profile in $profiles) {
            Write-Host "  - $($profile.DisplayName)" -ForegroundColor White
        }
    }

    # Show results table
    $results | Format-Table SerialNumber, Model, GroupTag, ProfileName, ProfileAssignmentStatus, EnrollmentState, LastContactedDateTime -AutoSize

    # Export
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
    Write-Error "Failed to query Autopilot status: $_"
    exit 1
}
