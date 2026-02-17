<#
.SYNOPSIS
    Reports on all Conditional Access policies with conditions, grants, and session controls.

.DESCRIPTION
    Queries all Conditional Access policies and displays their configuration including
    included/excluded users and groups, conditions (platforms, locations, risk levels,
    client apps), grant controls, and session controls. Resolves user/group IDs to
    display names.

.PARAMETER ExportPath
    Optional CSV export path.

.PARAMETER IncludeDisabled
    Include disabled policies in the report. By default, only enabled and report-only policies are shown.

.EXAMPLE
    .\Get-ConditionalAccessReport.ps1
    Report on all enabled and report-only policies.

.EXAMPLE
    .\Get-ConditionalAccessReport.ps1 -IncludeDisabled -ExportPath ".\ca-policies.csv"

.NOTES
    Requires: Microsoft.Graph.Identity.SignIns module
    Permissions: Policy.Read.All, Directory.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ExportPath,

    [Parameter()]
    [switch]$IncludeDisabled
)

#Requires -Modules Microsoft.Graph.Identity.SignIns

$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

Write-Host "Querying Conditional Access policies..." -ForegroundColor Cyan

try {
    $policies = Get-MgIdentityConditionalAccessPolicy -All

    if (-not $IncludeDisabled) {
        $policies = $policies | Where-Object { $_.State -ne "disabled" }
    }

    if ($policies.Count -eq 0) {
        Write-Host "No Conditional Access policies found." -ForegroundColor Yellow
        return
    }

    Write-Host "Found $($policies.Count) policies. Resolving names..." -ForegroundColor Cyan

    # Build ID-to-name cache for users and groups
    $nameLookup = @{}

    function Resolve-IdToName {
        param([string]$Id)
        if ($nameLookup.ContainsKey($Id)) { return $nameLookup[$Id] }
        try {
            $obj = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directoryObjects/$Id" -ErrorAction SilentlyContinue
            $name = if ($obj.displayName) { $obj.displayName } else { $Id }
            $nameLookup[$Id] = $name
            return $name
        } catch {
            $nameLookup[$Id] = $Id
            return $Id
        }
    }

    function Resolve-IdList {
        param([array]$Ids)
        if (-not $Ids -or $Ids.Count -eq 0) { return "None" }
        $names = foreach ($id in $Ids) {
            if ($id -eq "All") { "All Users" }
            elseif ($id -eq "GuestsOrExternalUsers") { "Guests/External Users" }
            elseif ($id -eq "None") { "None" }
            else { Resolve-IdToName -Id $id }
        }
        return ($names -join "; ")
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($policy in $policies) {
        $cond = $policy.Conditions

        # Users / Groups
        $includeUsers = Resolve-IdList -Ids $cond.Users.IncludeUsers
        $excludeUsers = Resolve-IdList -Ids $cond.Users.ExcludeUsers
        $includeGroups = Resolve-IdList -Ids $cond.Users.IncludeGroups
        $excludeGroups = Resolve-IdList -Ids $cond.Users.ExcludeGroups

        # Conditions
        $platforms = if ($cond.Platforms.IncludePlatforms) { $cond.Platforms.IncludePlatforms -join ", " } else { "Any" }
        $locations = if ($cond.Locations.IncludeLocations) { $cond.Locations.IncludeLocations -join ", " } else { "Any" }
        $signInRisk = if ($cond.SignInRiskLevels) { $cond.SignInRiskLevels -join ", " } else { "Any" }
        $userRisk = if ($cond.UserRiskLevels) { $cond.UserRiskLevels -join ", " } else { "Any" }
        $clientApps = if ($cond.ClientAppTypes) { $cond.ClientAppTypes -join ", " } else { "Any" }

        # Grant controls
        $grants = @()
        if ($policy.GrantControls.BuiltInControls) { $grants += $policy.GrantControls.BuiltInControls }
        $grantOperator = if ($policy.GrantControls.Operator) { $policy.GrantControls.Operator } else { "" }
        $grantText = if ($grants.Count -gt 0) { "($grantOperator) $($grants -join ', ')" } else { "None" }

        # Session controls
        $sessions = @()
        if ($policy.SessionControls.ApplicationEnforcedRestrictions.IsEnabled) { $sessions += "App enforced restrictions" }
        if ($policy.SessionControls.CloudAppSecurity.IsEnabled) { $sessions += "Cloud App Security" }
        if ($policy.SessionControls.PersistentBrowser.IsEnabled) { $sessions += "Persistent browser: $($policy.SessionControls.PersistentBrowser.Mode)" }
        if ($policy.SessionControls.SignInFrequency.IsEnabled) { $sessions += "Sign-in frequency: $($policy.SessionControls.SignInFrequency.Value) $($policy.SessionControls.SignInFrequency.Type)" }
        $sessionText = if ($sessions.Count -gt 0) { $sessions -join "; " } else { "None" }

        $results.Add([PSCustomObject]@{
            PolicyName      = $policy.DisplayName
            State           = $policy.State
            IncludeUsers    = $includeUsers
            ExcludeUsers    = $excludeUsers
            IncludeGroups   = $includeGroups
            ExcludeGroups   = $excludeGroups
            Platforms       = $platforms
            Locations       = $locations
            SignInRisk      = $signInRisk
            UserRisk        = $userRisk
            ClientApps      = $clientApps
            GrantControls   = $grantText
            SessionControls = $sessionText
        })
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new(
        [PSCustomObject[]]($results | Sort-Object State, PolicyName)
    )

    # === Dashboard ===
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  CONDITIONAL ACCESS REPORT" -ForegroundColor Cyan
    Write-Host "  Tenant: $($context.TenantId)" -ForegroundColor Cyan
    Write-Host "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $enabledCount = ($results | Where-Object State -eq "enabled").Count
    $reportOnlyCount = ($results | Where-Object State -eq "enabledForReportingButNotEnforced").Count
    $disabledCount = ($results | Where-Object State -eq "disabled").Count
    $mfaPolicies = ($results | Where-Object { $_.GrantControls -match "mfa" }).Count

    Write-Host "Total policies: $($results.Count)" -ForegroundColor White
    Write-Host "  Enabled:     $enabledCount" -ForegroundColor Green
    if ($reportOnlyCount -gt 0) {
        Write-Host "  Report-only: $reportOnlyCount" -ForegroundColor Yellow
    }
    if ($IncludeDisabled -and $disabledCount -gt 0) {
        Write-Host "  Disabled:    $disabledCount" -ForegroundColor Gray
    }

    Write-Host "Policies requiring MFA: $mfaPolicies" -ForegroundColor White

    # Display
    foreach ($r in $results) {
        $stateColor = switch ($r.State) {
            "enabled" { "Green" }
            "enabledForReportingButNotEnforced" { "Yellow" }
            "disabled" { "Gray" }
            default { "White" }
        }
        $stateLabel = switch ($r.State) {
            "enabled" { "ON" }
            "enabledForReportingButNotEnforced" { "REPORT-ONLY" }
            "disabled" { "OFF" }
            default { $r.State }
        }

        Write-Host "`n  [$stateLabel] $($r.PolicyName)" -ForegroundColor $stateColor
        Write-Host "    Users:    Include=$($r.IncludeUsers) | Exclude=$($r.ExcludeUsers)" -ForegroundColor Gray
        Write-Host "    Groups:   Include=$($r.IncludeGroups) | Exclude=$($r.ExcludeGroups)" -ForegroundColor Gray
        Write-Host "    Grants:   $($r.GrantControls)" -ForegroundColor Gray
        if ($r.SessionControls -ne "None") {
            Write-Host "    Sessions: $($r.SessionControls)" -ForegroundColor Gray
        }
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
    Write-Error "Failed to generate Conditional Access report: $_"
    exit 1
}
