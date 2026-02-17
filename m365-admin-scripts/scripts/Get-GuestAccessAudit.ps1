<#
.SYNOPSIS
    Audits guest user accounts in Entra ID with sign-in activity and staleness detection.

.DESCRIPTION
    Queries all guest users in the tenant and reports on their last sign-in activity,
    invitation state, and optionally their group/team memberships. Identifies stale
    guests who haven't signed in within a configurable threshold.

.PARAMETER StaleDays
    Days since last sign-in to consider a guest stale. Default: 90

.PARAMETER ExportPath
    Optional CSV export path.

.PARAMETER IncludeGroupMemberships
    Include group and team memberships for each guest. This is slower as it queries
    per-guest membership.

.EXAMPLE
    .\Get-GuestAccessAudit.ps1
    Audit all guests with 90-day staleness threshold.

.EXAMPLE
    .\Get-GuestAccessAudit.ps1 -StaleDays 60 -IncludeGroupMemberships -ExportPath ".\guests.csv"

.NOTES
    Requires: Microsoft.Graph.Users, Microsoft.Graph.Groups modules
    Permissions: User.Read.All, AuditLog.Read.All, GroupMember.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [int]$StaleDays = 90,

    [Parameter()]
    [string]$ExportPath,

    [Parameter()]
    [switch]$IncludeGroupMemberships
)

#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Groups

$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

Write-Host "Querying guest user accounts..." -ForegroundColor Cyan

$cutoffDate = (Get-Date).AddDays(-$StaleDays)

try {
    $guests = Get-MgUser -Filter "userType eq 'Guest'" -All -Property Id, DisplayName, UserPrincipalName, Mail, ExternalUserState, CreatedDateTime, SignInActivity, AccountEnabled, CompanyName

    if ($guests.Count -eq 0) {
        Write-Host "No guest users found." -ForegroundColor Green
        return
    }

    Write-Host "Found $($guests.Count) guest users. Processing..." -ForegroundColor Cyan

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $counter = 0

    foreach ($guest in $guests) {
        $counter++

        if ($IncludeGroupMemberships) {
            Write-Progress -Activity "Processing guests" -Status "$counter of $($guests.Count): $($guest.DisplayName)" -PercentComplete (($counter / $guests.Count) * 100)
        }

        $lastSignIn = $guest.SignInActivity.LastSignInDateTime
        $daysSince = if ($lastSignIn) {
            ((Get-Date) - $lastSignIn).Days
        } else {
            $null
        }

        $isStale = if ($lastSignIn) {
            $lastSignIn -lt $cutoffDate
        } else {
            # Never signed in — stale if created before cutoff
            $guest.CreatedDateTime -and $guest.CreatedDateTime -lt $cutoffDate
        }

        $neverSignedIn = -not $lastSignIn

        # Extract source domain from UPN or mail
        $sourceDomain = ""
        if ($guest.Mail) {
            $sourceDomain = ($guest.Mail -split "@")[-1]
        } elseif ($guest.UserPrincipalName -match "#EXT#@") {
            $upnPart = $guest.UserPrincipalName -replace "#EXT#@.*$", ""
            $sourceDomain = ($upnPart -split "_")[-1]
        }

        $result = [PSCustomObject]@{
            DisplayName       = $guest.DisplayName
            Email             = $guest.Mail
            UserPrincipalName = $guest.UserPrincipalName
            AccountEnabled    = $guest.AccountEnabled
            InvitationState   = if ($guest.ExternalUserState) { $guest.ExternalUserState } else { "Unknown" }
            CompanyName       = $guest.CompanyName
            SourceDomain      = $sourceDomain
            CreatedDate       = if ($guest.CreatedDateTime) { $guest.CreatedDateTime.ToString("yyyy-MM-dd") } else { "Unknown" }
            LastSignIn        = if ($lastSignIn) { $lastSignIn.ToString("yyyy-MM-dd") } else { "Never" }
            DaysSinceSignIn   = if ($daysSince) { $daysSince } else { "Never" }
            IsStale           = $isStale
            NeverSignedIn     = $neverSignedIn
        }

        # Optional group memberships
        if ($IncludeGroupMemberships) {
            try {
                $memberships = Get-MgUserMemberOf -UserId $guest.Id -All
                $groupNames = $memberships | Where-Object { $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.group' } |
                    ForEach-Object { $_.AdditionalProperties.displayName }
                $result | Add-Member -NotePropertyName "GroupMemberships" -NotePropertyValue ($groupNames -join "; ")
                $result | Add-Member -NotePropertyName "GroupCount" -NotePropertyValue $groupNames.Count
            } catch {
                $result | Add-Member -NotePropertyName "GroupMemberships" -NotePropertyValue "Error"
                $result | Add-Member -NotePropertyName "GroupCount" -NotePropertyValue 0
            }
        }

        $results.Add($result)
    }

    if ($IncludeGroupMemberships) {
        Write-Progress -Activity "Processing guests" -Completed
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new(
        [PSCustomObject[]]($results | Sort-Object { if ($_.DaysSinceSignIn -eq "Never") { 99999 } else { [int]$_.DaysSinceSignIn } } -Descending)
    )

    # === Dashboard ===
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  GUEST ACCESS AUDIT" -ForegroundColor Cyan
    Write-Host "  Staleness Threshold: $StaleDays days" -ForegroundColor Cyan
    Write-Host "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $totalGuests = $results.Count
    $staleGuests = ($results | Where-Object IsStale -eq $true).Count
    $neverSignedInCount = ($results | Where-Object NeverSignedIn -eq $true).Count
    $pendingInvitations = ($results | Where-Object InvitationState -eq "PendingAcceptance").Count

    Write-Host "Total guest users: $totalGuests" -ForegroundColor White

    if ($staleGuests -gt 0) {
        Write-Host "Stale guests (>$StaleDays days): $staleGuests" -ForegroundColor Yellow
    }

    if ($neverSignedInCount -gt 0) {
        Write-Host "Never signed in: $neverSignedInCount" -ForegroundColor Red
    }

    if ($pendingInvitations -gt 0) {
        Write-Host "Pending invitations: $pendingInvitations" -ForegroundColor Yellow
    }

    # Top source domains
    $domains = $results | Where-Object SourceDomain | Group-Object SourceDomain | Sort-Object Count -Descending
    if ($domains.Count -gt 0) {
        Write-Host "`nTop Source Domains:" -ForegroundColor Cyan
        $domains | Select-Object -First 10 | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Count) guests" -ForegroundColor White
        }
    }

    # Display
    $results | Format-Table DisplayName, Email, InvitationState, LastSignIn, IsStale -AutoSize

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
    Write-Error "Failed to generate guest access audit: $_"
    exit 1
}
