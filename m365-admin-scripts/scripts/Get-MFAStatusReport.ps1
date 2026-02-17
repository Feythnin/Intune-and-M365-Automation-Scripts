<#
.SYNOPSIS
    Reports on MFA registration status for all users in the tenant.

.DESCRIPTION
    Queries the Microsoft Graph authentication methods registration details report
    to identify users' MFA status, default method, and all registered methods.
    Flags users with no MFA and those relying on SMS-only for security review.

.PARAMETER ExportPath
    Optional CSV export path.

.PARAMETER IncludeGuests
    Include guest users in the report. By default, only members are shown.

.EXAMPLE
    .\Get-MFAStatusReport.ps1
    MFA status for all member users.

.EXAMPLE
    .\Get-MFAStatusReport.ps1 -IncludeGuests -ExportPath ".\mfa-report.csv"

.NOTES
    Requires: Microsoft.Graph.Users, Microsoft.Graph.Reports modules
    Permissions: UserAuthenticationMethod.Read.All, User.Read.All, AuditLog.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ExportPath,

    [Parameter()]
    [switch]$IncludeGuests
)

#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Reports

$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

Write-Host "Querying MFA registration details..." -ForegroundColor Cyan

try {
    # Bulk registration details (avoids N+1 per-user queries)
    $registrationDetails = @()
    $uri = "https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails"

    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        $registrationDetails += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)

    Write-Host "Retrieved registration details for $($registrationDetails.Count) users." -ForegroundColor Cyan

    # Get user details for display names and account status
    $users = Get-MgUser -All -Property Id, DisplayName, UserPrincipalName, AccountEnabled, UserType

    # Build lookup table
    $userLookup = @{}
    foreach ($user in $users) {
        $userLookup[$user.Id] = $user
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($reg in $registrationDetails) {
        $user = $userLookup[$reg.id]
        if (-not $user) { continue }

        # Filter guests unless requested
        if (-not $IncludeGuests -and $user.UserType -eq "Guest") { continue }

        $methods = @($reg.methodsRegistered)
        $isMfaRegistered = $reg.isMfaRegistered
        $isSmsOnly = ($methods.Count -eq 1 -and $methods -contains "mobilePhone") -or
                     ($methods.Count -eq 1 -and $methods -contains "sms")

        $results.Add([PSCustomObject]@{
            DisplayName       = $user.DisplayName
            UserPrincipalName = $user.UserPrincipalName
            AccountEnabled    = $user.AccountEnabled
            UserType          = $user.UserType
            IsMfaRegistered   = $isMfaRegistered
            DefaultMethod     = if ($reg.defaultMfaMethod) { $reg.defaultMfaMethod } else { "None" }
            MethodsRegistered = ($methods -join "; ")
            MethodCount       = $methods.Count
            IsSmsOnly         = $isSmsOnly
            IsAdmin           = $reg.isAdmin
        })
    }

    $results = $results | Sort-Object IsMfaRegistered, DisplayName

    # === Dashboard ===
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  MFA STATUS REPORT" -ForegroundColor Cyan
    Write-Host "  Tenant: $($context.TenantId)" -ForegroundColor Cyan
    Write-Host "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $totalUsers = $results.Count
    $mfaRegistered = ($results | Where-Object IsMfaRegistered -eq $true).Count
    $noMfa = ($results | Where-Object IsMfaRegistered -eq $false).Count
    $smsOnly = ($results | Where-Object IsSmsOnly -eq $true).Count
    $mfaPercent = if ($totalUsers -gt 0) { [math]::Round(($mfaRegistered / $totalUsers) * 100, 1) } else { 0 }

    Write-Host "Total users: $totalUsers" -ForegroundColor White
    Write-Host "MFA registered: $mfaRegistered ($mfaPercent%)" -ForegroundColor $(if ($mfaPercent -ge 90) { "Green" } elseif ($mfaPercent -ge 70) { "Yellow" } else { "Red" })

    if ($noMfa -gt 0) {
        Write-Host "No MFA: $noMfa" -ForegroundColor Red
    }

    if ($smsOnly -gt 0) {
        Write-Host "SMS-only MFA: $smsOnly (consider stronger methods)" -ForegroundColor Yellow
    }

    # Method breakdown
    $allMethods = $results | Where-Object { $_.MethodsRegistered } | ForEach-Object { $_.MethodsRegistered -split "; " } | Where-Object { $_ }
    if ($allMethods.Count -gt 0) {
        Write-Host "`nMethod Breakdown:" -ForegroundColor Cyan
        $allMethods | Group-Object | Sort-Object Count -Descending | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor White
        }
    }

    # Show users without MFA
    $noMfaUsers = $results | Where-Object { $_.IsMfaRegistered -eq $false -and $_.AccountEnabled -eq $true }
    if ($noMfaUsers.Count -gt 0 -and $noMfaUsers.Count -le 20) {
        Write-Host "`nEnabled users WITHOUT MFA:" -ForegroundColor Red
        $noMfaUsers | ForEach-Object {
            Write-Host "  $($_.UserPrincipalName)" -ForegroundColor Yellow
        }
    } elseif ($noMfaUsers.Count -gt 20) {
        Write-Host "`n$($noMfaUsers.Count) enabled users without MFA — export to CSV for full list." -ForegroundColor Red
    }

    # Display
    $results | Format-Table DisplayName, UserPrincipalName, AccountEnabled, IsMfaRegistered, DefaultMethod, IsSmsOnly -AutoSize

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
    Write-Error "Failed to generate MFA status report: $_"
    exit 1
}
