<#
.SYNOPSIS
    Reports on Intune app protection (MAM) policy assignments and compliance status.

.DESCRIPTION
    Queries all app protection policies for iOS and Android, showing their
    configuration, assignment targets, and per-user compliance status. Useful
    for BYOD environments to verify MAM policy coverage.

.PARAMETER Platform
    Optional filter by platform: iOS, Android, or Windows.

.PARAMETER ExportPath
    Optional CSV export path.

.EXAMPLE
    .\Get-AppProtectionReport.ps1
    Shows all app protection policies and their status.

.EXAMPLE
    .\Get-AppProtectionReport.ps1 -Platform "iOS" -ExportPath ".\reports\app-protection.csv"

.NOTES
    Requires: Microsoft.Graph.DeviceManagement module
    Permissions: DeviceManagementApps.Read.All, DeviceManagementConfiguration.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("iOS", "Android", "Windows")]
    [string]$Platform,

    [Parameter()]
    [string]$ExportPath
)

#Requires -Modules Microsoft.Graph.DeviceManagement

$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

Write-Host "Querying app protection policies..." -ForegroundColor Cyan

try {
    # Get iOS managed app policies
    $iosPolicies = @()
    $androidPolicies = @()
    $windowsPolicies = @()

    if (-not $Platform -or $Platform -eq "iOS") {
        try {
            $iosResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/deviceAppManagement/iosManagedAppProtections" -OutputType PSObject
            $iosPolicies = $iosResponse.value
        } catch {
            Write-Host "Could not retrieve iOS policies." -ForegroundColor Yellow
        }
    }

    if (-not $Platform -or $Platform -eq "Android") {
        try {
            $androidResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/deviceAppManagement/androidManagedAppProtections" -OutputType PSObject
            $androidPolicies = $androidResponse.value
        } catch {
            Write-Host "Could not retrieve Android policies." -ForegroundColor Yellow
        }
    }

    if (-not $Platform -or $Platform -eq "Windows") {
        try {
            $windowsResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/deviceAppManagement/windowsManagedAppProtections" -OutputType PSObject
            $windowsPolicies = $windowsResponse.value
        } catch {
            # Windows MAM policies may not exist in all tenants
        }
    }

    $allPolicies = @()
    foreach ($p in $iosPolicies) { $allPolicies += [PSCustomObject]@{ Policy = $p; Platform = "iOS" } }
    foreach ($p in $androidPolicies) { $allPolicies += [PSCustomObject]@{ Policy = $p; Platform = "Android" } }
    foreach ($p in $windowsPolicies) { $allPolicies += [PSCustomObject]@{ Policy = $p; Platform = "Windows" } }

    if ($allPolicies.Count -eq 0) {
        Write-Host "No app protection policies found." -ForegroundColor Yellow
        return
    }

    Write-Host "Found $($allPolicies.Count) app protection policy/policies. Gathering details...`n" -ForegroundColor Cyan

    $policySummaries = [System.Collections.Generic.List[PSCustomObject]]::new()
    $allUserStatuses = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($entry in $allPolicies) {
        $policy = $entry.Policy
        $platform = $entry.Platform

        Write-Host "  Checking: $($policy.displayName) ($platform)..." -ForegroundColor Gray

        # Build settings summary
        $settings = @()
        if ($policy.pinRequired) { $settings += "PIN required" }
        if ($policy.fingerprintBlocked -eq $false) { $settings += "Biometrics allowed" }
        if ($policy.dataBackupBlocked) { $settings += "Backup blocked" }
        if ($policy.managedBrowserToOpenLinksRequired) { $settings += "Managed browser required" }
        if ($policy.saveAsBlocked) { $settings += "Save-as blocked" }
        if ($policy.periodOfflineBeforeWipeIsEnforced) { $settings += "Offline wipe: $($policy.periodOfflineBeforeWipeIsEnforced)" }
        if ($policy.minimumRequiredOsVersion) { $settings += "Min OS: $($policy.minimumRequiredOsVersion)" }
        if ($policy.minimumRequiredAppVersion) { $settings += "Min app version: $($policy.minimumRequiredAppVersion)" }

        # Determine the correct endpoint for deployment summary
        $platformPath = switch ($platform) {
            "iOS" { "iosManagedAppProtections" }
            "Android" { "androidManagedAppProtections" }
            "Windows" { "windowsManagedAppProtections" }
        }

        # Get deployment summary
        $deployedUsers = 0
        $appliedUsers = 0
        $failedUsers = 0

        try {
            $summary = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/deviceAppManagement/$platformPath/$($policy.id)/deploymentSummary" -OutputType PSObject
            $deployedUsers = $summary.configurationDeployedUserCount
            $appliedUsers = $summary.configurationAppliedUserCount
            $failedUsers = $summary.configurationDeploymentSummaryPerApp | ForEach-Object { $_.failedUserCount } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
            if (-not $failedUsers) { $failedUsers = 0 }
        } catch {
            # Deployment summary may not be available
        }

        $policySummaries.Add([PSCustomObject]@{
            PolicyName      = $policy.displayName
            Platform        = $platform
            IsAssigned      = $policy.isAssigned
            DeployedUsers   = $deployedUsers
            AppliedUsers    = $appliedUsers
            FailedUsers     = $failedUsers
            KeySettings     = if ($settings.Count -gt 0) { $settings -join "; " } else { "Default" }
            CreatedDate     = if ($policy.createdDateTime) { ([datetime]$policy.createdDateTime).ToString("yyyy-MM-dd") } else { "Unknown" }
            LastModified    = if ($policy.lastModifiedDateTime) { ([datetime]$policy.lastModifiedDateTime).ToString("yyyy-MM-dd") } else { "Unknown" }
            PolicyId        = $policy.id
        })

        # Get per-user statuses
        try {
            $userStatuses = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/deviceAppManagement/$platformPath/$($policy.id)/userStatuses" -OutputType PSObject
            if ($userStatuses.value) {
                foreach ($us in $userStatuses.value) {
                    $allUserStatuses.Add([PSCustomObject]@{
                        PolicyName     = $policy.displayName
                        Platform       = $platform
                        UserName       = $us.userDisplayName
                        UserPrincipal  = $us.userPrincipalName
                        AppCount       = if ($us.appliedPolicies) { $us.appliedPolicies.Count } else { 0 }
                        LastSync       = if ($us.lastReportedDateTime) { $us.lastReportedDateTime } else { "Unknown" }
                    })
                }
            }
        } catch {
            # User status endpoint may not be available for all policy types
        }

        Start-Sleep -Milliseconds 300
    }

    # === Dashboard ===
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  APP PROTECTION POLICY REPORT" -ForegroundColor Cyan
    Write-Host "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "Total policies: $($policySummaries.Count)" -ForegroundColor White

    # Platform breakdown
    $policySummaries | Group-Object Platform | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count) policy/policies" -ForegroundColor White
    }

    $totalDeployed = ($policySummaries | Measure-Object -Property DeployedUsers -Sum).Sum
    $totalFailed = ($policySummaries | Measure-Object -Property FailedUsers -Sum).Sum
    $unassigned = ($policySummaries | Where-Object IsAssigned -eq $false).Count

    Write-Host "Total users covered: $totalDeployed" -ForegroundColor White

    if ($totalFailed -gt 0) {
        Write-Host "Users with failures: $totalFailed" -ForegroundColor Red
    }

    if ($unassigned -gt 0) {
        Write-Host "Unassigned policies: $unassigned" -ForegroundColor Yellow
    }

    # Policy summary table
    $policySummaries | Format-Table PolicyName, Platform, IsAssigned, DeployedUsers, AppliedUsers, FailedUsers, KeySettings -AutoSize

    # Export
    if ($ExportPath) {
        $exportDir = Split-Path $ExportPath -Parent
        if ($exportDir -and -not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }

        # Export user statuses if available, otherwise policy summaries
        if ($allUserStatuses.Count -gt 0) {
            $allUserStatuses | Export-Csv -Path $ExportPath -NoTypeInformation
        } else {
            $policySummaries | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        Write-Host "Report exported to: $ExportPath" -ForegroundColor Green
    }

    return $policySummaries

} catch {
    Write-Error "Failed to generate app protection report: $_"
    exit 1
}
