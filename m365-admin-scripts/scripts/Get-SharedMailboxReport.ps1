<#
.SYNOPSIS
    Audits all shared mailboxes with permissions, delegates, and optional size reporting.

.DESCRIPTION
    Generates a comprehensive report of all shared mailboxes in the Exchange Online
    tenant, including who has Full Access, Send As, and Send on Behalf permissions.
    Optionally includes mailbox size data (slower due to per-mailbox queries).

.PARAMETER ExportPath
    Optional CSV export path.

.PARAMETER IncludeSize
    Include mailbox size statistics. This is slower as it queries each mailbox individually.

.EXAMPLE
    .\Get-SharedMailboxReport.ps1 -IncludeSize -ExportPath ".\shared-mailboxes.csv"

.NOTES
    Requires: ExchangeOnlineManagement module
    Permissions: Exchange Administrator or equivalent
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ExportPath,

    [Parameter()]
    [switch]$IncludeSize
)

#Requires -Modules ExchangeOnlineManagement

# Verify Exchange connection
try {
    $null = Get-OrganizationConfig -ErrorAction Stop
} catch {
    Write-Error "Not connected to Exchange Online. Run Connect-ExchangeOnline first."
    exit 1
}

Write-Host "Querying shared mailboxes..." -ForegroundColor Cyan

try {
    $sharedMailboxes = Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited

    if ($sharedMailboxes.Count -eq 0) {
        Write-Host "No shared mailboxes found." -ForegroundColor Yellow
        return
    }

    Write-Host "Found $($sharedMailboxes.Count) shared mailboxes. Gathering details...`n" -ForegroundColor Cyan

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $counter = 0

    foreach ($mbx in $sharedMailboxes) {
        $counter++
        Write-Progress -Activity "Processing shared mailboxes" -Status "$counter of $($sharedMailboxes.Count): $($mbx.DisplayName)" -PercentComplete (($counter / $sharedMailboxes.Count) * 100)

        # Get Full Access permissions (exclude self and system accounts)
        $fullAccess = Get-MailboxPermission -Identity $mbx.PrimarySmtpAddress |
            Where-Object {
                $_.AccessRights -contains "FullAccess" -and
                $_.User -notlike "NT AUTHORITY\*" -and
                $_.User -notlike "S-1-5-*" -and
                $_.User -ne $mbx.PrimarySmtpAddress -and
                -not $_.IsInherited
            } | ForEach-Object { $_.User }

        # Get Send As permissions
        $sendAs = Get-RecipientPermission -Identity $mbx.PrimarySmtpAddress |
            Where-Object {
                $_.Trustee -notlike "NT AUTHORITY\*" -and
                $_.Trustee -ne $mbx.PrimarySmtpAddress
            } | ForEach-Object { $_.Trustee }

        # Get Send on Behalf
        $sendOnBehalf = $mbx.GrantSendOnBehalfTo | ForEach-Object {
            try { (Get-Mailbox $_ -ErrorAction SilentlyContinue).PrimarySmtpAddress } catch { $_ }
        }

        $result = [PSCustomObject]@{
            DisplayName       = $mbx.DisplayName
            EmailAddress      = $mbx.PrimarySmtpAddress
            FullAccess        = ($fullAccess -join "; ")
            FullAccessCount   = ($fullAccess | Measure-Object).Count
            SendAs            = ($sendAs -join "; ")
            SendAsCount       = ($sendAs | Measure-Object).Count
            SendOnBehalf      = ($sendOnBehalf -join "; ")
            SendOnBehalfCount = ($sendOnBehalf | Measure-Object).Count
            HiddenFromGAL     = $mbx.HiddenFromAddressListsEnabled
            WhenCreated       = $mbx.WhenCreated.ToString("yyyy-MM-dd")
        }

        # Optional: get mailbox size
        if ($IncludeSize) {
            try {
                $stats = Get-MailboxStatistics -Identity $mbx.PrimarySmtpAddress -ErrorAction SilentlyContinue
                $result | Add-Member -NotePropertyName "TotalSize" -NotePropertyValue $stats.TotalItemSize.Value.ToString()
                $result | Add-Member -NotePropertyName "ItemCount" -NotePropertyValue $stats.ItemCount
            } catch {
                $result | Add-Member -NotePropertyName "TotalSize" -NotePropertyValue "Error"
                $result | Add-Member -NotePropertyName "ItemCount" -NotePropertyValue "Error"
            }
        }

        $results.Add($result)
    }

    Write-Progress -Activity "Processing shared mailboxes" -Completed

    # === Summary ===
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  SHARED MAILBOX REPORT" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "Total Shared Mailboxes: $($results.Count)" -ForegroundColor White

    $noPermissions = ($results | Where-Object { $_.FullAccessCount -eq 0 -and $_.SendAsCount -eq 0 -and $_.SendOnBehalfCount -eq 0 }).Count
    if ($noPermissions -gt 0) {
        Write-Host "Mailboxes with NO delegates: $noPermissions" -ForegroundColor Yellow
    }

    $hiddenCount = ($results | Where-Object HiddenFromGAL -eq $true).Count
    Write-Host "Hidden from GAL: $hiddenCount" -ForegroundColor White

    # Display table
    $results | Format-Table DisplayName, EmailAddress, FullAccessCount, SendAsCount, SendOnBehalfCount -AutoSize

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
    Write-Error "Failed to generate shared mailbox report: $_"
    exit 1
}
