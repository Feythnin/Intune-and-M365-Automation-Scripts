<#
.SYNOPSIS
    Reports on Microsoft 365 license assignments, usage, and availability.

.DESCRIPTION
    Queries Microsoft Graph for all subscribed SKUs and their assignment status.
    Shows total, assigned, and available license counts. Optionally provides
    per-user license assignment details for compliance and cost optimization.

.PARAMETER SkuFilter
    Optional filter by SKU part number (e.g., "ENTERPRISEPACK", "SPE_E3").

.PARAMETER Detailed
    Include per-user license assignment breakdown.

.PARAMETER ExportPath
    Optional CSV export path.

.EXAMPLE
    .\Get-LicenseReport.ps1
    Summary of all license types.

.EXAMPLE
    .\Get-LicenseReport.ps1 -Detailed -ExportPath ".\licenses.csv"

.NOTES
    Requires: Microsoft.Graph.Identity.DirectoryManagement module
    Permissions: Directory.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SkuFilter,

    [Parameter()]
    [switch]$Detailed,

    [Parameter()]
    [string]$ExportPath
)

#Requires -Modules Microsoft.Graph.Identity.DirectoryManagement

$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

Write-Host "Querying license information..." -ForegroundColor Cyan

# Common SKU friendly name mapping
$skuNames = @{
    "ENTERPRISEPACK"          = "Office 365 E3"
    "ENTERPRISEPREMIUM"       = "Office 365 E5"
    "SPE_E3"                  = "Microsoft 365 E3"
    "SPE_E5"                  = "Microsoft 365 E5"
    "BUSINESS_BASIC"          = "Microsoft 365 Business Basic"
    "O365_BUSINESS_PREMIUM"   = "Microsoft 365 Business Standard"
    "SPB"                     = "Microsoft 365 Business Premium"
    "EXCHANGESTANDARD"        = "Exchange Online Plan 1"
    "EXCHANGEENTERPRISE"      = "Exchange Online Plan 2"
    "POWER_BI_STANDARD"       = "Power BI Free"
    "POWER_BI_PRO"            = "Power BI Pro"
    "FLOW_FREE"               = "Power Automate Free"
    "TEAMS_EXPLORATORY"       = "Teams Exploratory"
    "AAD_PREMIUM"             = "Entra ID P1"
    "AAD_PREMIUM_P2"          = "Entra ID P2"
    "INTUNE_A"                = "Microsoft Intune Plan 1"
    "EMS"                     = "Enterprise Mobility + Security E3"
    "EMSPREMIUM"              = "Enterprise Mobility + Security E5"
    "VISIOCLIENT"             = "Visio Plan 2"
    "PROJECTPREMIUM"          = "Project Plan 5"
    "WIN_DEF_ATP"             = "Microsoft Defender for Endpoint P2"
}

try {
    $subscribedSkus = Get-MgSubscribedSku -All

    if ($SkuFilter) {
        $subscribedSkus = $subscribedSkus | Where-Object { $_.SkuPartNumber -like "*$SkuFilter*" }
    }

    if ($subscribedSkus.Count -eq 0) {
        Write-Host "No subscriptions found." -ForegroundColor Yellow
        return
    }

    # === License Summary ===
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  LICENSE USAGE REPORT" -ForegroundColor Cyan
    Write-Host "  Tenant: $($context.TenantId)" -ForegroundColor Cyan
    Write-Host "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $licenseSummary = $subscribedSkus | ForEach-Object {
        $friendlyName = if ($skuNames.ContainsKey($_.SkuPartNumber)) {
            $skuNames[$_.SkuPartNumber]
        } else {
            $_.SkuPartNumber
        }

        $total = $_.PrepaidUnits.Enabled
        $assigned = $_.ConsumedUnits
        $available = $total - $assigned
        $usagePercent = if ($total -gt 0) { [math]::Round(($assigned / $total) * 100, 1) } else { 0 }

        [PSCustomObject]@{
            License       = $friendlyName
            SkuPartNumber = $_.SkuPartNumber
            Total         = $total
            Assigned      = $assigned
            Available     = $available
            UsagePercent  = "$usagePercent%"
            Status        = $_.CapabilityStatus
            SkuId         = $_.SkuId
        }
    } | Sort-Object { [int]$_.Assigned } -Descending

    # Display summary
    $licenseSummary | Format-Table License, Total, Assigned, Available, UsagePercent, Status -AutoSize

    # Highlight overallocated or near-capacity
    $warnings = $licenseSummary | Where-Object { $_.Available -le 2 -and $_.Total -gt 0 }
    if ($warnings.Count -gt 0) {
        Write-Host "WARNING: Licenses at or near capacity:" -ForegroundColor Red
        $warnings | ForEach-Object {
            Write-Host "  $($_.License): $($_.Available) remaining of $($_.Total)" -ForegroundColor Yellow
        }
    }

    # Total cost awareness
    $totalLicenses = ($licenseSummary | Measure-Object -Property Total -Sum).Sum
    $totalAssigned = ($licenseSummary | Measure-Object -Property Assigned -Sum).Sum
    $totalUnused = $totalLicenses - $totalAssigned
    Write-Host "`nTotal licenses: $totalLicenses | Assigned: $totalAssigned | Unused: $totalUnused" -ForegroundColor White

    if ($totalUnused -gt 10) {
        Write-Host "TIP: $totalUnused unused licenses across all SKUs — review for potential cost savings." -ForegroundColor Yellow
    }

    # Detailed per-user breakdown
    if ($Detailed) {
        Write-Host "`nGenerating per-user license details..." -ForegroundColor Cyan

        $users = Get-MgUser -All -Property DisplayName, UserPrincipalName, AssignedLicenses, AccountEnabled, SignInActivity

        $userLicenses = $users | Where-Object { $_.AssignedLicenses.Count -gt 0 } | ForEach-Object {
            $user = $_
            $licenseNames = $user.AssignedLicenses | ForEach-Object {
                $skuId = $_.SkuId
                $match = $licenseSummary | Where-Object { $_.SkuId -eq $skuId }
                if ($match) { $match.License } else { $skuId }
            }

            [PSCustomObject]@{
                DisplayName       = $user.DisplayName
                UserPrincipalName = $user.UserPrincipalName
                AccountEnabled    = $user.AccountEnabled
                LicenseCount      = $user.AssignedLicenses.Count
                Licenses          = ($licenseNames -join "; ")
                LastSignIn        = if ($user.SignInActivity.LastSignInDateTime) {
                    $user.SignInActivity.LastSignInDateTime.ToString("yyyy-MM-dd")
                } else { "Never" }
            }
        } | Sort-Object LicenseCount -Descending

        Write-Host "Licensed users: $($userLicenses.Count)" -ForegroundColor White

        # Export detailed report
        if ($ExportPath) {
            $exportDir = Split-Path $ExportPath -Parent
            if ($exportDir -and -not (Test-Path $exportDir)) {
                New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
            }
            $userLicenses | Export-Csv -Path $ExportPath -NoTypeInformation
            Write-Host "Detailed report exported to: $ExportPath" -ForegroundColor Green
        }

        return $userLicenses
    }

    # Export summary only
    if ($ExportPath -and -not $Detailed) {
        $exportDir = Split-Path $ExportPath -Parent
        if ($exportDir -and -not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }
        $licenseSummary | Export-Csv -Path $ExportPath -NoTypeInformation
        Write-Host "Summary exported to: $ExportPath" -ForegroundColor Green
    }

    return $licenseSummary

} catch {
    Write-Error "Failed to generate license report: $_"
    exit 1
}
