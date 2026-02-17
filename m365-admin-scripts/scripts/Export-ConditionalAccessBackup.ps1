<#
.SYNOPSIS
    Exports all Conditional Access policies as individual JSON files for backup.

.DESCRIPTION
    Retrieves all Conditional Access policies and saves each as a separate JSON file
    with full configuration details. Creates a manifest file with export metadata.
    Useful for disaster recovery, tenant migration, and change tracking.

.PARAMETER OutputDirectory
    Directory to save the backup files. Defaults to ".\CA-Backup_<timestamp>".

.PARAMETER IncludeDisabled
    Include disabled policies in the export. By default, only enabled and report-only policies are exported.

.EXAMPLE
    .\Export-ConditionalAccessBackup.ps1
    Exports to a timestamped directory in the current folder.

.EXAMPLE
    .\Export-ConditionalAccessBackup.ps1 -OutputDirectory "C:\Backups\CA" -IncludeDisabled

.NOTES
    Requires: Microsoft.Graph.Identity.SignIns module
    Permissions: Policy.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputDirectory,

    [Parameter()]
    [switch]$IncludeDisabled
)

#Requires -Modules Microsoft.Graph.Identity.SignIns

$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

# Set default output directory with timestamp
if (-not $OutputDirectory) {
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $OutputDirectory = ".\CA-Backup_$timestamp"
}

Write-Host "Querying Conditional Access policies..." -ForegroundColor Cyan

try {
    $policies = Get-MgIdentityConditionalAccessPolicy -All

    if (-not $IncludeDisabled) {
        $policies = $policies | Where-Object { $_.State -ne "disabled" }
    }

    if ($policies.Count -eq 0) {
        Write-Host "No Conditional Access policies found to export." -ForegroundColor Yellow
        return
    }

    Write-Host "Found $($policies.Count) policies to export." -ForegroundColor Cyan

    # Create output directory
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    $exportedFiles = [System.Collections.Generic.List[PSCustomObject]]::new()
    $enabledCount = 0
    $reportOnlyCount = 0
    $disabledCount = 0

    foreach ($policy in $policies) {
        # Sanitize policy name for filename
        $safeName = $policy.DisplayName -replace '[\\/:*?"<>|]', '_' -replace '\s+', '_'
        if ($safeName.Length -gt 80) {
            $safeName = $safeName.Substring(0, 80)
        }

        $statePrefix = switch ($policy.State) {
            "enabled" { "Enabled" }
            "enabledForReportingButNotEnforced" { "ReportOnly" }
            "disabled" { "Disabled" }
            default { $policy.State }
        }

        switch ($policy.State) {
            "enabled" { $enabledCount++ }
            "enabledForReportingButNotEnforced" { $reportOnlyCount++ }
            "disabled" { $disabledCount++ }
        }

        $fileName = "${statePrefix}_${safeName}_$($policy.Id).json"
        $filePath = Join-Path $OutputDirectory $fileName

        # Get raw policy as JSON via Graph request for full fidelity
        $rawPolicy = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$($policy.Id)"

        $rawPolicy | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8

        $exportedFiles.Add([PSCustomObject]@{
            PolicyName = $policy.DisplayName
            PolicyId   = $policy.Id
            State      = $policy.State
            FileName   = $fileName
        })

        Write-Host "  Exported: $($policy.DisplayName) ($statePrefix)" -ForegroundColor Gray
    }

    # Create manifest
    $manifest = [PSCustomObject]@{
        ExportDate       = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        TenantId         = $context.TenantId
        Account          = $context.Account
        TotalPolicies    = $policies.Count
        EnabledCount     = $enabledCount
        ReportOnlyCount  = $reportOnlyCount
        DisabledCount    = $disabledCount
        IncludeDisabled  = $IncludeDisabled.IsPresent
        Files            = $exportedFiles
    }

    $manifestPath = Join-Path $OutputDirectory "_manifest.json"
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestPath -Encoding UTF8

    # === Dashboard ===
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  CONDITIONAL ACCESS BACKUP" -ForegroundColor Cyan
    Write-Host "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "Policies exported: $($policies.Count)" -ForegroundColor White
    Write-Host "  Enabled:     $enabledCount" -ForegroundColor Green
    if ($reportOnlyCount -gt 0) {
        Write-Host "  Report-only: $reportOnlyCount" -ForegroundColor Yellow
    }
    if ($disabledCount -gt 0) {
        Write-Host "  Disabled:    $disabledCount" -ForegroundColor Gray
    }
    Write-Host "`nOutput directory: $((Resolve-Path $OutputDirectory).Path)" -ForegroundColor Green
    Write-Host "Manifest: _manifest.json" -ForegroundColor Green

    return $exportedFiles

} catch {
    Write-Error "Failed to export Conditional Access policies: $_"
    exit 1
}
