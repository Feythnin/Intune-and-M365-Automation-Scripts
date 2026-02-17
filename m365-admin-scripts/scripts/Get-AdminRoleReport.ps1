<#
.SYNOPSIS
    Reports on Entra ID admin role assignments with MFA status and staleness detection.

.DESCRIPTION
    Queries all directory role assignments in the tenant, including permanent and
    optionally PIM-eligible assignments. Shows MFA registration status per admin,
    flags permanent Global Admins, and identifies stale admin accounts.

.PARAMETER ExportPath
    Optional CSV export path.

.PARAMETER IncludePIM
    Include PIM (Privileged Identity Management) eligible role assignments.

.EXAMPLE
    .\Get-AdminRoleReport.ps1
    Report on all active role assignments.

.EXAMPLE
    .\Get-AdminRoleReport.ps1 -IncludePIM -ExportPath ".\admin-roles.csv"

.NOTES
    Requires: Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Identity.Governance modules
    Permissions: RoleManagement.Read.Directory, Directory.Read.All, AuditLog.Read.All, UserAuthenticationMethod.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ExportPath,

    [Parameter()]
    [switch]$IncludePIM
)

#Requires -Modules Microsoft.Graph.Identity.DirectoryManagement

$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

Write-Host "Querying directory role assignments..." -ForegroundColor Cyan

try {
    # Get role definitions
    $roleDefinitions = Get-MgRoleManagementDirectoryRoleDefinition -All
    $roleLookup = @{}
    foreach ($rd in $roleDefinitions) {
        $roleLookup[$rd.Id] = $rd.DisplayName
    }

    # Get active (permanent) role assignments
    $activeAssignments = Get-MgRoleManagementDirectoryRoleAssignment -All -ExpandProperty principal

    Write-Host "Found $($activeAssignments.Count) active role assignments." -ForegroundColor Cyan

    # Get PIM eligible assignments if requested
    $eligibleAssignments = @()
    if ($IncludePIM) {
        Write-Host "Querying PIM eligible assignments..." -ForegroundColor Cyan
        try {
            $eligibleAssignments = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All
            Write-Host "Found $($eligibleAssignments.Count) PIM eligible assignments." -ForegroundColor Cyan
        } catch {
            Write-Host "Could not query PIM eligibility schedules. Ensure Microsoft.Graph.Identity.Governance module is installed and PIM is licensed." -ForegroundColor Yellow
        }
    }

    # Get MFA registration details for admins
    Write-Host "Querying MFA registration details..." -ForegroundColor Cyan
    $mfaDetails = @()
    $uri = "https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails"
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        $mfaDetails += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)

    $mfaLookup = @{}
    foreach ($mfa in $mfaDetails) {
        $mfaLookup[$mfa.id] = $mfa
    }

    # Collect unique principal IDs from assignments
    $principalIds = @($activeAssignments | ForEach-Object { $_.PrincipalId }) + @($eligibleAssignments | ForEach-Object { $_.PrincipalId })
    $principalIds = $principalIds | Select-Object -Unique

    # Get user details
    $userLookup = @{}
    foreach ($princId in $principalIds) {
        try {
            $user = Get-MgUser -UserId $princId -Property DisplayName, UserPrincipalName, AccountEnabled, SignInActivity -ErrorAction SilentlyContinue
            if ($user) {
                $userLookup[$princId] = $user
            }
        } catch {
            # Could be a service principal or group — skip
        }
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $staleDays = 90
    $cutoffDate = (Get-Date).AddDays(-$staleDays)

    # Process active assignments
    foreach ($assignment in $activeAssignments) {
        $roleName = if ($roleLookup.ContainsKey($assignment.RoleDefinitionId)) { $roleLookup[$assignment.RoleDefinitionId] } else { $assignment.RoleDefinitionId }
        $user = $userLookup[$assignment.PrincipalId]
        $mfa = $mfaLookup[$assignment.PrincipalId]

        $lastSignIn = $user.SignInActivity.LastSignInDateTime
        $daysSince = if ($lastSignIn) { ((Get-Date) - $lastSignIn).Days } else { $null }
        $isStale = if ($lastSignIn) { $lastSignIn -lt $cutoffDate } else { $true }

        $results.Add([PSCustomObject]@{
            DisplayName       = if ($user) { $user.DisplayName } else { $assignment.PrincipalId }
            UserPrincipalName = if ($user) { $user.UserPrincipalName } else { "N/A (service principal or group)" }
            RoleName          = $roleName
            AssignmentType    = "Permanent"
            AccountEnabled    = if ($user) { $user.AccountEnabled } else { "N/A" }
            IsMfaRegistered   = if ($mfa) { $mfa.isMfaRegistered } else { "Unknown" }
            DefaultMfaMethod  = if ($mfa -and $mfa.defaultMfaMethod) { $mfa.defaultMfaMethod } else { "None" }
            LastSignIn        = if ($lastSignIn) { $lastSignIn.ToString("yyyy-MM-dd") } else { "Never" }
            DaysSinceSignIn   = if ($daysSince) { $daysSince } else { "Never" }
            IsStale           = $isStale
            IsPermanentGA     = $roleName -eq "Global Administrator"
        })
    }

    # Process PIM eligible assignments
    foreach ($elig in $eligibleAssignments) {
        $roleName = if ($roleLookup.ContainsKey($elig.RoleDefinitionId)) { $roleLookup[$elig.RoleDefinitionId] } else { $elig.RoleDefinitionId }
        $user = $userLookup[$elig.PrincipalId]
        $mfa = $mfaLookup[$elig.PrincipalId]

        $lastSignIn = $user.SignInActivity.LastSignInDateTime
        $daysSince = if ($lastSignIn) { ((Get-Date) - $lastSignIn).Days } else { $null }
        $isStale = if ($lastSignIn) { $lastSignIn -lt $cutoffDate } else { $true }

        $results.Add([PSCustomObject]@{
            DisplayName       = if ($user) { $user.DisplayName } else { $elig.PrincipalId }
            UserPrincipalName = if ($user) { $user.UserPrincipalName } else { "N/A (service principal or group)" }
            RoleName          = $roleName
            AssignmentType    = "PIM Eligible"
            AccountEnabled    = if ($user) { $user.AccountEnabled } else { "N/A" }
            IsMfaRegistered   = if ($mfa) { $mfa.isMfaRegistered } else { "Unknown" }
            DefaultMfaMethod  = if ($mfa -and $mfa.defaultMfaMethod) { $mfa.defaultMfaMethod } else { "None" }
            LastSignIn        = if ($lastSignIn) { $lastSignIn.ToString("yyyy-MM-dd") } else { "Never" }
            DaysSinceSignIn   = if ($daysSince) { $daysSince } else { "Never" }
            IsStale           = $isStale
            IsPermanentGA     = $false
        })
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new(
        [PSCustomObject[]]($results | Sort-Object RoleName, AssignmentType, DisplayName)
    )

    # === Dashboard ===
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  ADMIN ROLE REPORT" -ForegroundColor Cyan
    Write-Host "  Tenant: $($context.TenantId)" -ForegroundColor Cyan
    Write-Host "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $totalAssignments = $results.Count
    $permanentCount = ($results | Where-Object AssignmentType -eq "Permanent").Count
    $pimCount = ($results | Where-Object AssignmentType -eq "PIM Eligible").Count
    $permanentGAs = ($results | Where-Object { $_.RoleName -eq "Global Administrator" -and $_.AssignmentType -eq "Permanent" }).Count
    $adminsNoMfa = ($results | Where-Object { $_.IsMfaRegistered -eq $false }).Count
    $staleAdmins = ($results | Where-Object IsStale -eq $true).Count

    Write-Host "Total role assignments: $totalAssignments" -ForegroundColor White
    Write-Host "  Permanent: $permanentCount" -ForegroundColor White
    if ($IncludePIM) {
        Write-Host "  PIM Eligible: $pimCount" -ForegroundColor White
    }

    if ($permanentGAs -gt 0) {
        Write-Host "Permanent Global Admins: $permanentGAs" -ForegroundColor Red
    }

    if ($adminsNoMfa -gt 0) {
        Write-Host "Admins without MFA: $adminsNoMfa" -ForegroundColor Red
    }

    if ($staleAdmins -gt 0) {
        Write-Host "Stale admin accounts (>$staleDays days): $staleAdmins" -ForegroundColor Yellow
    }

    # Role breakdown
    Write-Host "`nAssignments by Role:" -ForegroundColor Cyan
    $results | Group-Object RoleName | Sort-Object Count -Descending | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor White
    }

    # Display
    $results | Format-Table DisplayName, RoleName, AssignmentType, IsMfaRegistered, LastSignIn, IsStale -AutoSize

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
    Write-Error "Failed to generate admin role report: $_"
    exit 1
}
