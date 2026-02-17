<#
.SYNOPSIS
    Offboards users by disabling accounts, revoking sessions, removing licenses, and cleaning up.

.DESCRIPTION
    Performs a complete user offboarding workflow: disables the account, revokes all
    active sessions, removes license assignments, optionally converts the mailbox to
    shared, sets mail forwarding, removes group memberships, and hides from the GAL.
    Supports single user or bulk CSV input with WhatIf and detailed logging.

.PARAMETER UserPrincipalName
    UPN of a single user to offboard.

.PARAMETER CsvPath
    Path to a CSV file with a UserPrincipalName column for bulk offboarding.

.PARAMETER ForwardingAddress
    Email address to forward the offboarded user's mail to.

.PARAMETER ConvertToSharedMailbox
    Convert the user's mailbox to a shared mailbox before removing the license.

.PARAMETER SkipGroupRemoval
    Skip removing the user from group memberships.

.PARAMETER ExportPath
    Optional CSV export path for the results.

.PARAMETER LogPath
    Optional log file path.

.PARAMETER Force
    Suppress confirmation prompts (not recommended for production use).

.EXAMPLE
    .\Invoke-UserOffboard.ps1 -UserPrincipalName "jsmith@contoso.com" -WhatIf
    Preview offboarding steps for a single user.

.EXAMPLE
    .\Invoke-UserOffboard.ps1 -CsvPath ".\offboard-users.csv" -ConvertToSharedMailbox -ForwardingAddress "manager@contoso.com"

.EXAMPLE
    .\Invoke-UserOffboard.ps1 -UserPrincipalName "jsmith@contoso.com" -ConvertToSharedMailbox -LogPath ".\logs\offboard.log"

.NOTES
    Requires: Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement, ExchangeOnlineManagement modules
    Permissions: User.ReadWrite.All, Directory.ReadWrite.All, Group.ReadWrite.All + Exchange Admin
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(ParameterSetName = "Single")]
    [string]$UserPrincipalName,

    [Parameter(ParameterSetName = "Bulk")]
    [string]$CsvPath,

    [Parameter()]
    [string]$ForwardingAddress,

    [Parameter()]
    [switch]$ConvertToSharedMailbox,

    [Parameter()]
    [switch]$SkipGroupRemoval,

    [Parameter()]
    [string]$ExportPath,

    [Parameter()]
    [string]$LogPath,

    [Parameter()]
    [switch]$Force
)

#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement, ExchangeOnlineManagement

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Write-Host $entry -ForegroundColor $(switch ($Level) { "WARN" { "Yellow" } "ERROR" { "Red" } "SUCCESS" { "Green" } default { "White" } })
    if ($LogPath) { Add-Content -Path $LogPath -Value $entry }
}

# Verify Graph connection
$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

# Verify Exchange connection
try {
    $null = Get-OrganizationConfig -ErrorAction Stop
} catch {
    Write-Error "Not connected to Exchange Online. Run Connect-ExchangeOnline first."
    exit 1
}

# Validate parameters
if (-not $UserPrincipalName -and -not $CsvPath) {
    Write-Error "Specify either -UserPrincipalName or -CsvPath."
    exit 1
}

# Build user list
$usersToProcess = @()
if ($CsvPath) {
    if (-not (Test-Path $CsvPath)) {
        Write-Error "CSV file not found: $CsvPath"
        exit 1
    }
    $csvData = Import-Csv $CsvPath
    if ("UserPrincipalName" -notin $csvData[0].PSObject.Properties.Name) {
        Write-Error "CSV missing required column: UserPrincipalName"
        exit 1
    }
    $usersToProcess = $csvData | ForEach-Object { $_.UserPrincipalName }
} else {
    $usersToProcess = @($UserPrincipalName)
}

# Initialize log
if ($LogPath) {
    $logDir = Split-Path $LogPath -Parent
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    Write-Log "=== User Offboarding Started ==="
    Write-Log "Users to process: $($usersToProcess.Count)"
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  USER OFFBOARDING" -ForegroundColor Cyan
Write-Host "  Users to process: $($usersToProcess.Count)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$successCount = 0
$partialCount = 0
$failCount = 0
$totalLicensesReclaimed = 0
$totalGroupsRemoved = 0
$mailboxesConverted = 0

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($upn in $usersToProcess) {
    Write-Log "Processing: $upn"

    # Verify user exists
    $user = $null
    try {
        $user = Get-MgUser -UserId $upn -Property Id, DisplayName, UserPrincipalName, AccountEnabled, AssignedLicenses -ErrorAction Stop
    } catch {
        Write-Log "User not found: $upn" "ERROR"
        $results.Add([PSCustomObject]@{
            UserPrincipalName     = $upn
            DisplayName           = "N/A"
            Status                = "Failed"
            DisableAccount        = "Skipped - User not found"
            RevokeSessions        = "Skipped"
            RemoveLicenses        = "Skipped"
            ConvertMailbox        = "Skipped"
            SetForwarding         = "Skipped"
            RemoveGroups          = "Skipped"
            HideFromGAL           = "Skipped"
            LicensesReclaimed     = 0
            GroupsRemoved         = 0
        })
        $failCount++
        continue
    }

    if (-not $Force -and -not $PSCmdlet.ShouldProcess($upn, "Offboard user (disable, revoke sessions, remove licenses, cleanup)")) {
        continue
    }

    $stepResults = @{
        DisableAccount    = "Skipped"
        RevokeSessions    = "Skipped"
        RemoveLicenses    = "Skipped"
        ConvertMailbox    = "Skipped"
        SetForwarding     = "Skipped"
        RemoveGroups      = "Skipped"
        HideFromGAL       = "Skipped"
    }
    $userLicenses = 0
    $userGroups = 0
    $hadFailure = $false

    # Step 1: Disable account
    try {
        Update-MgUser -UserId $user.Id -AccountEnabled:$false
        $stepResults.DisableAccount = "Success"
        Write-Log "  Disabled account: $upn" "SUCCESS"
    } catch {
        $stepResults.DisableAccount = "Failed: $_"
        Write-Log "  Failed to disable account: $upn - $_" "ERROR"
        $hadFailure = $true
    }

    # Step 2: Revoke sessions
    try {
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)/revokeSignInSessions" | Out-Null
        $stepResults.RevokeSessions = "Success"
        Write-Log "  Revoked sessions: $upn" "SUCCESS"
    } catch {
        $stepResults.RevokeSessions = "Failed: $_"
        Write-Log "  Failed to revoke sessions: $upn - $_" "ERROR"
        $hadFailure = $true
    }

    # Step 3: Convert mailbox to shared (before removing license)
    if ($ConvertToSharedMailbox) {
        try {
            Set-Mailbox -Identity $upn -Type Shared
            $stepResults.ConvertMailbox = "Success"
            $mailboxesConverted++
            Write-Log "  Converted to shared mailbox: $upn" "SUCCESS"
        } catch {
            $stepResults.ConvertMailbox = "Failed: $_"
            Write-Log "  Failed to convert mailbox: $upn - $_" "ERROR"
            $hadFailure = $true
        }
    }

    # Step 4: Set mail forwarding
    if ($ForwardingAddress) {
        try {
            Set-Mailbox -Identity $upn -ForwardingSmtpAddress "smtp:$ForwardingAddress" -DeliverToMailboxAndForward $true
            $stepResults.SetForwarding = "Success -> $ForwardingAddress"
            Write-Log "  Set forwarding to $ForwardingAddress for $upn" "SUCCESS"
        } catch {
            $stepResults.SetForwarding = "Failed: $_"
            Write-Log "  Failed to set forwarding: $upn - $_" "ERROR"
            $hadFailure = $true
        }
    }

    # Step 5: Remove licenses
    if ($user.AssignedLicenses.Count -gt 0) {
        try {
            $licenseIds = $user.AssignedLicenses | ForEach-Object { $_.SkuId }
            Set-MgUserLicense -UserId $user.Id -AddLicenses @() -RemoveLicenses $licenseIds
            $userLicenses = $licenseIds.Count
            $totalLicensesReclaimed += $userLicenses
            $stepResults.RemoveLicenses = "Success ($userLicenses removed)"
            Write-Log "  Removed $userLicenses licenses from $upn" "SUCCESS"
        } catch {
            $stepResults.RemoveLicenses = "Failed: $_"
            Write-Log "  Failed to remove licenses: $upn - $_" "ERROR"
            $hadFailure = $true
        }
    } else {
        $stepResults.RemoveLicenses = "No licenses assigned"
    }

    # Step 6: Remove group memberships
    if (-not $SkipGroupRemoval) {
        try {
            $memberships = Get-MgUserMemberOf -UserId $user.Id -All
            $groups = $memberships | Where-Object { $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.group' }

            foreach ($group in $groups) {
                try {
                    Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $user.Id
                    $userGroups++
                } catch {
                    Write-Log "  Could not remove from group $($group.AdditionalProperties.displayName): $_" "WARN"
                }
            }

            $totalGroupsRemoved += $userGroups
            $stepResults.RemoveGroups = "Success ($userGroups removed)"
            Write-Log "  Removed from $userGroups groups: $upn" "SUCCESS"
        } catch {
            $stepResults.RemoveGroups = "Failed: $_"
            Write-Log "  Failed to remove group memberships: $upn - $_" "ERROR"
            $hadFailure = $true
        }
    }

    # Step 7: Hide from GAL
    try {
        Set-Mailbox -Identity $upn -HiddenFromAddressListsEnabled $true
        $stepResults.HideFromGAL = "Success"
        Write-Log "  Hidden from GAL: $upn" "SUCCESS"
    } catch {
        $stepResults.HideFromGAL = "Failed: $_"
        Write-Log "  Failed to hide from GAL: $upn - $_" "ERROR"
        $hadFailure = $true
    }

    # Determine overall status
    $failedSteps = ($stepResults.Values | Where-Object { $_ -match "^Failed" }).Count
    if ($failedSteps -eq 0) {
        $successCount++
        $status = "Success"
    } else {
        $partialCount++
        $status = "Partial"
    }

    $results.Add([PSCustomObject]@{
        UserPrincipalName     = $upn
        DisplayName           = $user.DisplayName
        Status                = $status
        DisableAccount        = $stepResults.DisableAccount
        RevokeSessions        = $stepResults.RevokeSessions
        RemoveLicenses        = $stepResults.RemoveLicenses
        ConvertMailbox        = $stepResults.ConvertMailbox
        SetForwarding         = $stepResults.SetForwarding
        RemoveGroups          = $stepResults.RemoveGroups
        HideFromGAL           = $stepResults.HideFromGAL
        LicensesReclaimed     = $userLicenses
        GroupsRemoved         = $userGroups
    })

    Start-Sleep -Milliseconds 300
}

# === Summary ===
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Log "=== Offboarding Complete ==="
Write-Log "Succeeded: $successCount | Partial: $partialCount | Failed: $failCount | Total: $($usersToProcess.Count)"
Write-Host "Licenses reclaimed: $totalLicensesReclaimed" -ForegroundColor White
Write-Host "Groups removed: $totalGroupsRemoved" -ForegroundColor White
if ($ConvertToSharedMailbox) {
    Write-Host "Mailboxes converted to shared: $mailboxesConverted" -ForegroundColor White
}

# Display results
$results | Format-Table UserPrincipalName, DisplayName, Status, LicensesReclaimed, GroupsRemoved -AutoSize

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
