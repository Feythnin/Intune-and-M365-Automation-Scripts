<#
.SYNOPSIS
    Full audit of mailbox permissions including Full Access, Send As, and Send on Behalf.

.DESCRIPTION
    Scans all user and shared mailboxes for delegated permissions. Essential for
    security audits, compliance reviews, and cleaning up stale permissions after
    employee offboarding.

.PARAMETER Mailbox
    Optional specific mailbox to audit. If omitted, audits all mailboxes.

.PARAMETER ExportPath
    Optional CSV export path.

.EXAMPLE
    .\Get-MailboxPermissionAudit.ps1
    Audits all mailboxes.

.EXAMPLE
    .\Get-MailboxPermissionAudit.ps1 -Mailbox "ceo@contoso.com" -ExportPath ".\audit.csv"

.NOTES
    Requires: ExchangeOnlineManagement module
    Permissions: Exchange Administrator or equivalent
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Mailbox,

    [Parameter()]
    [string]$ExportPath
)

#Requires -Modules ExchangeOnlineManagement

try {
    $null = Get-OrganizationConfig -ErrorAction Stop
} catch {
    Write-Error "Not connected to Exchange Online. Run Connect-ExchangeOnline first."
    exit 1
}

Write-Host "Starting mailbox permission audit..." -ForegroundColor Cyan

try {
    if ($Mailbox) {
        $mailboxes = @(Get-Mailbox -Identity $Mailbox)
    } else {
        $mailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox, SharedMailbox
    }

    if ($mailboxes.Count -eq 0) {
        Write-Host "No mailboxes found." -ForegroundColor Yellow
        return
    }

    Write-Host "Auditing $($mailboxes.Count) mailboxes...`n" -ForegroundColor Cyan

    $allPermissions = [System.Collections.Generic.List[PSCustomObject]]::new()
    $counter = 0

    foreach ($mbx in $mailboxes) {
        $counter++
        Write-Progress -Activity "Auditing permissions" -Status "$counter of $($mailboxes.Count): $($mbx.DisplayName)" -PercentComplete (($counter / $mailboxes.Count) * 100)

        # Full Access
        $fullAccess = Get-MailboxPermission -Identity $mbx.PrimarySmtpAddress |
            Where-Object {
                $_.AccessRights -contains "FullAccess" -and
                $_.User -notlike "NT AUTHORITY\*" -and
                $_.User -notlike "S-1-5-*" -and
                $_.User -ne $mbx.PrimarySmtpAddress -and
                -not $_.IsInherited
            }

        foreach ($perm in $fullAccess) {
            $allPermissions.Add([PSCustomObject]@{
                MailboxName    = $mbx.DisplayName
                MailboxAddress = $mbx.PrimarySmtpAddress
                MailboxType    = $mbx.RecipientTypeDetails
                PermissionType = "Full Access"
                Delegate       = $perm.User
                IsInherited    = $perm.IsInherited
            })
        }

        # Send As
        $sendAs = Get-RecipientPermission -Identity $mbx.PrimarySmtpAddress |
            Where-Object {
                $_.Trustee -notlike "NT AUTHORITY\*" -and
                $_.Trustee -ne $mbx.PrimarySmtpAddress
            }

        foreach ($perm in $sendAs) {
            $allPermissions.Add([PSCustomObject]@{
                MailboxName    = $mbx.DisplayName
                MailboxAddress = $mbx.PrimarySmtpAddress
                MailboxType    = $mbx.RecipientTypeDetails
                PermissionType = "Send As"
                Delegate       = $perm.Trustee
                IsInherited    = $false
            })
        }

        # Send on Behalf
        if ($mbx.GrantSendOnBehalfTo.Count -gt 0) {
            foreach ($delegate in $mbx.GrantSendOnBehalfTo) {
                $delegateAddress = try {
                    (Get-Mailbox $delegate -ErrorAction SilentlyContinue).PrimarySmtpAddress
                } catch { $delegate }

                $allPermissions.Add([PSCustomObject]@{
                    MailboxName    = $mbx.DisplayName
                    MailboxAddress = $mbx.PrimarySmtpAddress
                    MailboxType    = $mbx.RecipientTypeDetails
                    PermissionType = "Send on Behalf"
                    Delegate       = $delegateAddress
                    IsInherited    = $false
                })
            }
        }
    }

    Write-Progress -Activity "Auditing permissions" -Completed

    # === Summary ===
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  MAILBOX PERMISSION AUDIT" -ForegroundColor Cyan
    Write-Host "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "Mailboxes scanned: $($mailboxes.Count)" -ForegroundColor White
    Write-Host "Total permission entries: $($allPermissions.Count)" -ForegroundColor White

    if ($allPermissions.Count -gt 0) {
        # Breakdown by type
        Write-Host "`nBy Permission Type:" -ForegroundColor Cyan
        $allPermissions | Group-Object PermissionType | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor White
        }

        # Most-delegated mailboxes
        Write-Host "`nTop 10 Most-Delegated Mailboxes:" -ForegroundColor Cyan
        $allPermissions | Group-Object MailboxAddress | Sort-Object Count -Descending |
            Select-Object -First 10 | ForEach-Object {
                Write-Host "  $($_.Name): $($_.Count) delegates" -ForegroundColor White
            }

        # Users with most access
        Write-Host "`nTop 10 Users with Most Access:" -ForegroundColor Cyan
        $allPermissions | Group-Object Delegate | Sort-Object Count -Descending |
            Select-Object -First 10 | ForEach-Object {
                Write-Host "  $($_.Name): access to $($_.Count) mailboxes" -ForegroundColor White
            }

        # Display
        $allPermissions | Format-Table MailboxName, MailboxAddress, PermissionType, Delegate -AutoSize
    } else {
        Write-Host "No delegated permissions found." -ForegroundColor Green
    }

    # Export
    if ($ExportPath) {
        $exportDir = Split-Path $ExportPath -Parent
        if ($exportDir -and -not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }
        $allPermissions | Export-Csv -Path $ExportPath -NoTypeInformation
        Write-Host "Audit exported to: $ExportPath" -ForegroundColor Green
    }

    return $allPermissions

} catch {
    Write-Error "Failed to complete permission audit: $_"
    exit 1
}
