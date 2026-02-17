<#
.SYNOPSIS
    Finds Entra ID users who haven't signed in within a configurable threshold.

.DESCRIPTION
    Queries Microsoft Graph sign-in activity data to identify inactive user accounts.
    Useful for license optimization, security reviews, and offboarding cleanup.

.PARAMETER InactiveDays
    Days since last sign-in to consider inactive. Default: 90

.PARAMETER LicensedOnly
    Only include users who have licenses assigned (skip service accounts, etc).

.PARAMETER ExportPath
    Optional CSV export path.

.EXAMPLE
    .\Get-InactiveUserReport.ps1 -InactiveDays 90 -LicensedOnly

.NOTES
    Requires: Microsoft.Graph.Users module
    Permissions: User.Read.All, AuditLog.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [int]$InactiveDays = 90,

    [Parameter()]
    [switch]$LicensedOnly,

    [Parameter()]
    [string]$ExportPath
)

#Requires -Modules Microsoft.Graph.Users

$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

Write-Host "Querying user sign-in activity..." -ForegroundColor Cyan

$cutoffDate = (Get-Date).AddDays(-$InactiveDays)

try {
    $users = Get-MgUser -All -Property DisplayName, UserPrincipalName, AccountEnabled, AssignedLicenses, SignInActivity, CreatedDateTime, Department, JobTitle, UserType

    # Filter to real users (not guests unless you want them)
    $users = $users | Where-Object { $_.UserType -eq "Member" }

    if ($LicensedOnly) {
        $users = $users | Where-Object { $_.AssignedLicenses.Count -gt 0 }
    }

    # Find inactive users
    $inactiveUsers = $users | Where-Object {
        $lastSignIn = $_.SignInActivity.LastSignInDateTime

        if (-not $lastSignIn) {
            # Never signed in — check if account is old enough
            $_.CreatedDateTime -and $_.CreatedDateTime -lt $cutoffDate
        } else {
            $lastSignIn -lt $cutoffDate
        }
    }

    if ($inactiveUsers.Count -eq 0) {
        Write-Host "No inactive users found (threshold: $InactiveDays days)." -ForegroundColor Green
        return
    }

    $results = $inactiveUsers | ForEach-Object {
        $lastSignIn = $_.SignInActivity.LastSignInDateTime
        $daysSince = if ($lastSignIn) {
            ((Get-Date) - $lastSignIn).Days
        } else {
            "Never"
        }

        [PSCustomObject]@{
            DisplayName       = $_.DisplayName
            UserPrincipalName = $_.UserPrincipalName
            AccountEnabled    = $_.AccountEnabled
            Department        = $_.Department
            JobTitle          = $_.JobTitle
            LicenseCount      = $_.AssignedLicenses.Count
            LastSignIn        = if ($lastSignIn) { $lastSignIn.ToString("yyyy-MM-dd") } else { "Never" }
            DaysSinceSignIn   = $daysSince
            AccountCreated    = if ($_.CreatedDateTime) { $_.CreatedDateTime.ToString("yyyy-MM-dd") } else { "Unknown" }
        }
    } | Sort-Object { if ($_.DaysSinceSignIn -eq "Never") { 99999 } else { [int]$_.DaysSinceSignIn } } -Descending

    # === Summary ===
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  INACTIVE USER REPORT" -ForegroundColor Cyan
    Write-Host "  Threshold: $InactiveDays days" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "Total inactive users: $($results.Count)" -ForegroundColor Yellow

    $neverSignedIn = ($results | Where-Object LastSignIn -eq "Never").Count
    if ($neverSignedIn -gt 0) {
        Write-Host "Never signed in: $neverSignedIn" -ForegroundColor Red
    }

    $enabledInactive = ($results | Where-Object AccountEnabled -eq $true).Count
    Write-Host "Enabled but inactive: $enabledInactive" -ForegroundColor Yellow

    $licensedInactive = ($results | Where-Object LicenseCount -gt 0).Count
    if ($licensedInactive -gt 0) {
        Write-Host "Licensed but inactive: $licensedInactive (potential cost savings)" -ForegroundColor Yellow
    }

    $disabledWithLicense = ($results | Where-Object { $_.AccountEnabled -eq $false -and $_.LicenseCount -gt 0 }).Count
    if ($disabledWithLicense -gt 0) {
        Write-Host "Disabled WITH licenses still assigned: $disabledWithLicense (wasting licenses!)" -ForegroundColor Red
    }

    # Department breakdown
    $deptGroups = $results | Where-Object Department | Group-Object Department | Sort-Object Count -Descending
    if ($deptGroups.Count -gt 0) {
        Write-Host "`nBy Department:" -ForegroundColor Cyan
        $deptGroups | Select-Object -First 10 | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor White
        }
    }

    # Display
    $results | Format-Table DisplayName, UserPrincipalName, AccountEnabled, LicenseCount, LastSignIn, DaysSinceSignIn -AutoSize

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
    Write-Error "Failed to generate inactive user report: $_"
    exit 1
}
