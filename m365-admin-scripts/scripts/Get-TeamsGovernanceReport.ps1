<#
.SYNOPSIS
    Reports on Teams governance including activity, ownership, and guest membership.

.DESCRIPTION
    Queries all Teams-enabled groups and reports on their ownership, membership,
    activity status, and guest presence. Identifies ownerless teams and inactive
    teams for governance review.

.PARAMETER InactiveDays
    Days since last activity to consider a team inactive. Default: 90

.PARAMETER ExportPath
    Optional CSV export path.

.EXAMPLE
    .\Get-TeamsGovernanceReport.ps1
    Report on all teams with 90-day inactivity threshold.

.EXAMPLE
    .\Get-TeamsGovernanceReport.ps1 -InactiveDays 60 -ExportPath ".\teams-governance.csv"

.NOTES
    Requires: Microsoft.Graph.Groups, Microsoft.Graph.Reports modules
    Permissions: Group.Read.All, Reports.Read.All, TeamSettings.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [int]$InactiveDays = 90,

    [Parameter()]
    [string]$ExportPath
)

#Requires -Modules Microsoft.Graph.Groups, Microsoft.Graph.Reports

$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

Write-Host "Querying Teams-enabled groups..." -ForegroundColor Cyan

try {
    # Get all Teams-enabled groups
    $teams = Get-MgGroup -Filter "resourceProvisioningOptions/Any(x:x eq 'Team')" -All -Property Id, DisplayName, Visibility, CreatedDateTime, Description, Mail

    if ($teams.Count -eq 0) {
        Write-Host "No Teams found." -ForegroundColor Yellow
        return
    }

    Write-Host "Found $($teams.Count) teams. Gathering details..." -ForegroundColor Cyan

    # Try to get Teams activity report
    $activityLookup = @{}
    try {
        Write-Host "Fetching Teams activity report..." -ForegroundColor Cyan
        $activityData = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/reports/getTeamsTeamActivityDetail(period='D180')" -OutputType HttpResponseMessage
        $activityCsv = [System.IO.StreamReader]::new($activityData.Content.ReadAsStream()).ReadToEnd()
        $activityRecords = $activityCsv | ConvertFrom-Csv

        foreach ($record in $activityRecords) {
            $teamId = $record.'Team Id'
            if ($teamId) {
                $activityLookup[$teamId] = $record
            }
        }
        Write-Host "Activity data loaded for $($activityLookup.Count) teams." -ForegroundColor Cyan
    } catch {
        Write-Host "Could not retrieve Teams activity report. Activity data will be unavailable." -ForegroundColor Yellow
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $counter = 0
    $cutoffDate = (Get-Date).AddDays(-$InactiveDays)

    foreach ($team in $teams) {
        $counter++
        Write-Progress -Activity "Processing teams" -Status "$counter of $($teams.Count): $($team.DisplayName)" -PercentComplete (($counter / $teams.Count) * 100)

        # Get owners and members
        $owners = @()
        $members = @()
        $guests = @()

        try {
            $teamOwners = Get-MgGroupOwner -GroupId $team.Id -All
            $owners = $teamOwners | ForEach-Object { $_.AdditionalProperties.displayName }
        } catch { }

        try {
            $teamMembers = Get-MgGroupMember -GroupId $team.Id -All
            foreach ($member in $teamMembers) {
                $memberType = $member.AdditionalProperties.'@odata.type'
                if ($memberType -eq '#microsoft.graph.user') {
                    $userType = $member.AdditionalProperties.userType
                    if ($userType -eq "Guest") {
                        $guests += $member.AdditionalProperties.displayName
                    } else {
                        $members += $member.AdditionalProperties.displayName
                    }
                }
            }
        } catch { }

        # Get channel count
        $channelCount = 0
        try {
            $channels = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/teams/$($team.Id)/channels" -ErrorAction SilentlyContinue
            $channelCount = $channels.value.Count
        } catch { }

        # Activity data
        $activity = $activityLookup[$team.Id]
        $lastActivity = "Unknown"
        $isInactive = $false

        if ($activity) {
            $lastActivityDate = $activity.'Last Activity Date'
            if ($lastActivityDate) {
                $lastActivity = $lastActivityDate
                try {
                    $actDate = [datetime]::Parse($lastActivityDate)
                    $isInactive = $actDate -lt $cutoffDate
                } catch { }
            }
        }

        $isOwnerless = $owners.Count -eq 0

        $results.Add([PSCustomObject]@{
            TeamName         = $team.DisplayName
            TeamId           = $team.Id
            Visibility       = $team.Visibility
            OwnerCount       = $owners.Count
            Owners           = ($owners -join "; ")
            MemberCount      = $members.Count
            GuestCount       = $guests.Count
            ChannelCount     = $channelCount
            CreatedDate      = if ($team.CreatedDateTime) { $team.CreatedDateTime.ToString("yyyy-MM-dd") } else { "Unknown" }
            LastActivity     = $lastActivity
            IsInactive       = $isInactive
            IsOwnerless      = $isOwnerless
            HasGuests        = $guests.Count -gt 0
        })
    }

    Write-Progress -Activity "Processing teams" -Completed

    $results = [System.Collections.Generic.List[PSCustomObject]]::new(
        [PSCustomObject[]]($results | Sort-Object TeamName)
    )

    # === Dashboard ===
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  TEAMS GOVERNANCE REPORT" -ForegroundColor Cyan
    Write-Host "  Inactivity Threshold: $InactiveDays days" -ForegroundColor Cyan
    Write-Host "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $totalTeams = $results.Count
    $publicTeams = ($results | Where-Object Visibility -eq "Public").Count
    $privateTeams = ($results | Where-Object Visibility -eq "Private").Count
    $ownerlessTeams = ($results | Where-Object IsOwnerless -eq $true).Count
    $inactiveTeams = ($results | Where-Object IsInactive -eq $true).Count
    $teamsWithGuests = ($results | Where-Object HasGuests -eq $true).Count

    Write-Host "Total teams: $totalTeams" -ForegroundColor White
    Write-Host "  Public:  $publicTeams" -ForegroundColor White
    Write-Host "  Private: $privateTeams" -ForegroundColor White

    if ($ownerlessTeams -gt 0) {
        Write-Host "Ownerless teams: $ownerlessTeams" -ForegroundColor Red
    }

    if ($inactiveTeams -gt 0) {
        Write-Host "Inactive teams (>$InactiveDays days): $inactiveTeams" -ForegroundColor Yellow
    }

    Write-Host "Teams with guests: $teamsWithGuests" -ForegroundColor White

    # Show ownerless teams
    $ownerlessNames = $results | Where-Object IsOwnerless -eq $true
    if ($ownerlessNames.Count -gt 0 -and $ownerlessNames.Count -le 15) {
        Write-Host "`nOwnerless Teams:" -ForegroundColor Red
        $ownerlessNames | ForEach-Object {
            Write-Host "  $($_.TeamName)" -ForegroundColor Yellow
        }
    }

    # Display
    $results | Format-Table TeamName, Visibility, OwnerCount, MemberCount, GuestCount, LastActivity, IsInactive, IsOwnerless -AutoSize

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
    Write-Error "Failed to generate Teams governance report: $_"
    exit 1
}
