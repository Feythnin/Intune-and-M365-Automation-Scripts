<#
.SYNOPSIS
    Displays Microsoft 365 service health status with active incidents and advisories.

.DESCRIPTION
    Queries the Microsoft Graph service communications API to show the current health
    status of all M365 services. Lists active incidents and advisories with impact
    descriptions and latest update text.

.PARAMETER ServiceFilter
    Optional filter by service name (e.g., "Exchange", "Teams", "SharePoint").

.PARAMETER ShowResolved
    Include resolved issues in the output. By default, only active issues are shown.

.PARAMETER ExportPath
    Optional CSV export path.

.EXAMPLE
    .\Get-ServiceHealthDashboard.ps1
    Shows current health of all M365 services.

.EXAMPLE
    .\Get-ServiceHealthDashboard.ps1 -ServiceFilter "Exchange" -ExportPath ".\health.csv"

.EXAMPLE
    .\Get-ServiceHealthDashboard.ps1 -ShowResolved

.NOTES
    Requires: Microsoft.Graph.Reports module
    Permissions: ServiceHealth.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ServiceFilter,

    [Parameter()]
    [switch]$ShowResolved,

    [Parameter()]
    [string]$ExportPath
)

#Requires -Modules Microsoft.Graph.Reports

$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

Write-Host "Querying service health status..." -ForegroundColor Cyan

try {
    # Get service health overviews
    $healthOverviews = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/admin/serviceAnnouncements/healthOverviews").value

    if ($ServiceFilter) {
        $healthOverviews = $healthOverviews | Where-Object { $_.service -like "*$ServiceFilter*" }
    }

    if ($healthOverviews.Count -eq 0) {
        Write-Host "No services found matching filter." -ForegroundColor Yellow
        return
    }

    # Get issues (incidents + advisories)
    $issues = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/admin/serviceAnnouncements/issues").value

    if ($ServiceFilter) {
        $issues = $issues | Where-Object { $_.service -like "*$ServiceFilter*" }
    }

    if (-not $ShowResolved) {
        $issues = $issues | Where-Object { $_.isResolved -eq $false }
    }

    # === Dashboard ===
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  SERVICE HEALTH DASHBOARD" -ForegroundColor Cyan
    Write-Host "  Tenant: $($context.TenantId)" -ForegroundColor Cyan
    Write-Host "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # Service status summary
    $healthyCount = ($healthOverviews | Where-Object { $_.status -eq "serviceOperational" }).Count
    $degradedCount = $healthOverviews.Count - $healthyCount
    $activeIncidents = ($issues | Where-Object { $_.classification -eq "incident" -and $_.isResolved -eq $false }).Count
    $activeAdvisories = ($issues | Where-Object { $_.classification -eq "advisory" -and $_.isResolved -eq $false }).Count

    Write-Host "Services: $($healthOverviews.Count) total" -ForegroundColor White
    Write-Host "  Healthy:  $healthyCount" -ForegroundColor Green
    if ($degradedCount -gt 0) {
        Write-Host "  Degraded: $degradedCount" -ForegroundColor Red
    } else {
        Write-Host "  Degraded: $degradedCount" -ForegroundColor White
    }
    Write-Host "Active incidents:  $activeIncidents" -ForegroundColor $(if ($activeIncidents -gt 0) { "Red" } else { "White" })
    Write-Host "Active advisories: $activeAdvisories" -ForegroundColor $(if ($activeAdvisories -gt 0) { "Yellow" } else { "White" })

    # Display service statuses
    Write-Host "`nService Statuses:" -ForegroundColor Cyan
    $healthOverviews | Sort-Object status -Descending | ForEach-Object {
        $statusColor = if ($_.status -eq "serviceOperational") { "Green" } else { "Red" }
        $statusText = switch ($_.status) {
            "serviceOperational" { "Operational" }
            "serviceDegradation" { "Degraded" }
            "serviceInterruption" { "Interruption" }
            "extendedRecovery" { "Extended Recovery" }
            "investigatingIssue" { "Investigating" }
            "restoringService" { "Restoring" }
            default { $_ }
        }
        Write-Host "  $($_.service): $statusText" -ForegroundColor $statusColor
    }

    # Build issue results
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($issue in $issues) {
        $latestUpdate = ""
        if ($issue.posts -and $issue.posts.Count -gt 0) {
            $latest = $issue.posts | Sort-Object { $_.createdDateTime } -Descending | Select-Object -First 1
            $latestUpdate = $latest.description.content -replace '<[^>]+>', '' -replace '&nbsp;', ' '
            if ($latestUpdate.Length -gt 500) {
                $latestUpdate = $latestUpdate.Substring(0, 500) + "..."
            }
        }

        $results.Add([PSCustomObject]@{
            Id              = $issue.id
            Service         = $issue.service
            Title           = $issue.title
            Classification  = $issue.classification
            Status          = if ($issue.isResolved) { "Resolved" } else { "Active" }
            Impact          = $issue.impactDescription
            StartDateTime   = if ($issue.startDateTime) { ([datetime]$issue.startDateTime).ToString("yyyy-MM-dd HH:mm") } else { "Unknown" }
            EndDateTime     = if ($issue.endDateTime) { ([datetime]$issue.endDateTime).ToString("yyyy-MM-dd HH:mm") } else { "Ongoing" }
            LatestUpdate    = $latestUpdate
        })
    }

    # Display active issues
    if ($results.Count -gt 0) {
        Write-Host "`nIssues ($($results.Count)):" -ForegroundColor Cyan
        foreach ($r in $results) {
            $color = switch ($r.Classification) {
                "incident" { "Red" }
                "advisory" { "Yellow" }
                default { "White" }
            }
            Write-Host "`n  [$($r.Classification.ToUpper())] $($r.Title)" -ForegroundColor $color
            Write-Host "    Service: $($r.Service) | Status: $($r.Status) | Started: $($r.StartDateTime)" -ForegroundColor Gray
            if ($r.Impact) {
                Write-Host "    Impact: $($r.Impact)" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "`nNo active issues." -ForegroundColor Green
    }

    # Export
    if ($ExportPath) {
        $exportDir = Split-Path $ExportPath -Parent
        if ($exportDir -and -not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }
        $results | Export-Csv -Path $ExportPath -NoTypeInformation
        Write-Host "`nReport exported to: $ExportPath" -ForegroundColor Green
    }

    return $results

} catch {
    Write-Error "Failed to retrieve service health: $_"
    exit 1
}
