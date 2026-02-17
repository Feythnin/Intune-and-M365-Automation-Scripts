<#
.SYNOPSIS
    Documents all Exchange Online transport rules with conditions, actions, and status.

.DESCRIPTION
    Generates a comprehensive report of all mail flow (transport) rules configured
    in Exchange Online. Useful for compliance documentation, security audits, and
    understanding mail flow behavior.

.PARAMETER ExportPath
    Optional CSV export path.

.PARAMETER IncludeDisabled
    Include disabled rules in the report. By default, only enabled rules are shown.

.EXAMPLE
    .\Get-TransportRuleReport.ps1

.EXAMPLE
    .\Get-TransportRuleReport.ps1 -IncludeDisabled -ExportPath ".\transport-rules.csv"

.NOTES
    Requires: ExchangeOnlineManagement module
    Permissions: Exchange Administrator or equivalent
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ExportPath,

    [Parameter()]
    [switch]$IncludeDisabled
)

#Requires -Modules ExchangeOnlineManagement

try {
    $null = Get-OrganizationConfig -ErrorAction Stop
} catch {
    Write-Error "Not connected to Exchange Online. Run Connect-ExchangeOnline first."
    exit 1
}

Write-Host "Querying transport rules..." -ForegroundColor Cyan

try {
    $rules = Get-TransportRule

    if (-not $IncludeDisabled) {
        $rules = $rules | Where-Object State -eq "Enabled"
    }

    if ($rules.Count -eq 0) {
        Write-Host "No transport rules found." -ForegroundColor Yellow
        return
    }

    $results = $rules | ForEach-Object {
        # Build human-readable conditions
        $conditions = @()
        if ($_.FromScope) { $conditions += "From scope: $($_.FromScope)" }
        if ($_.SentToScope) { $conditions += "Sent to scope: $($_.SentToScope)" }
        if ($_.FromAddressContainsWords) { $conditions += "From contains: $($_.FromAddressContainsWords -join ', ')" }
        if ($_.SubjectContainsWords) { $conditions += "Subject contains: $($_.SubjectContainsWords -join ', ')" }
        if ($_.SubjectOrBodyContainsWords) { $conditions += "Subject/Body contains: $($_.SubjectOrBodyContainsWords -join ', ')" }
        if ($_.SenderDomainIs) { $conditions += "Sender domain: $($_.SenderDomainIs -join ', ')" }
        if ($_.RecipientDomainIs) { $conditions += "Recipient domain: $($_.RecipientDomainIs -join ', ')" }
        if ($_.HasClassification) { $conditions += "Classification: $($_.HasClassification)" }
        if ($_.AttachmentHasExecutableContent) { $conditions += "Attachment has executable content" }
        if ($_.AttachmentSizeOver) { $conditions += "Attachment size over: $($_.AttachmentSizeOver)" }
        if ($_.SCLOver) { $conditions += "SCL over: $($_.SCLOver)" }
        if ($_.HeaderContainsMessageHeader) { $conditions += "Header '$($_.HeaderContainsMessageHeader)' contains: $($_.HeaderContainsWords -join ', ')" }

        # Build human-readable actions
        $actions = @()
        if ($_.AddToRecipients) { $actions += "Add recipients: $($_.AddToRecipients -join ', ')" }
        if ($_.BlindCopyTo) { $actions += "BCC to: $($_.BlindCopyTo -join ', ')" }
        if ($_.CopyTo) { $actions += "CC to: $($_.CopyTo -join ', ')" }
        if ($_.RedirectMessageTo) { $actions += "Redirect to: $($_.RedirectMessageTo -join ', ')" }
        if ($_.RejectMessageReasonText) { $actions += "Reject with: $($_.RejectMessageReasonText)" }
        if ($_.DeleteMessage) { $actions += "Delete message" }
        if ($_.PrependSubject) { $actions += "Prepend subject: $($_.PrependSubject)" }
        if ($_.SetSCL) { $actions += "Set SCL: $($_.SetSCL)" }
        if ($_.ApplyHtmlDisclaimerText) { $actions += "Add disclaimer" }
        if ($_.ModerateMessageByUser) { $actions += "Moderate by: $($_.ModerateMessageByUser -join ', ')" }
        if ($_.SetHeaderName) { $actions += "Set header '$($_.SetHeaderName)': $($_.SetHeaderValue)" }
        if ($_.RemoveHeader) { $actions += "Remove header: $($_.RemoveHeader)" }
        if ($_.ApplyClassification) { $actions += "Apply classification: $($_.ApplyClassification)" }
        if ($_.StopRuleProcessing) { $actions += "Stop processing more rules" }

        [PSCustomObject]@{
            Priority       = $_.Priority
            Name           = $_.Name
            State          = $_.State
            Mode           = $_.Mode
            Conditions     = if ($conditions.Count -gt 0) { $conditions -join "; " } else { "None specified" }
            Actions        = if ($actions.Count -gt 0) { $actions -join "; " } else { "None specified" }
            Exceptions     = if (
                $_.ExceptIfFromScope -or
                $_.ExceptIfSentToScope -or
                $_.ExceptIfSenderDomainIs -or
                $_.ExceptIfRecipientDomainIs -or
                $_.ExceptIfFromAddressContainsWords -or
                $_.ExceptIfSubjectContainsWords -or
                $_.ExceptIfSubjectOrBodyContainsWords -or
                $_.ExceptIfFromMemberOf -or
                $_.ExceptIfSentToMemberOf -or
                $_.ExceptIfAttachmentHasExecutableContent -or
                $_.ExceptIfAttachmentSizeOver -or
                $_.ExceptIfHeaderContainsMessageHeader -or
                $_.ExceptIfHasClassification -or
                $_.ExceptIfSCLOver
            ) { "Has exceptions" } else { "None" }
            Comments       = $_.Comments
            WhenChanged    = if ($_.WhenChanged) { $_.WhenChanged.ToString("yyyy-MM-dd") } else { "Unknown" }
        }
    } | Sort-Object Priority

    # === Summary ===
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  TRANSPORT RULE REPORT" -ForegroundColor Cyan
    Write-Host "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $enabledCount = ($results | Where-Object State -eq "Enabled").Count
    $disabledCount = ($results | Where-Object State -eq "Disabled").Count
    Write-Host "Total rules: $($results.Count)" -ForegroundColor White
    Write-Host "  Enabled:  $enabledCount" -ForegroundColor Green
    Write-Host "  Disabled: $disabledCount" -ForegroundColor Gray

    # Display each rule
    foreach ($rule in $results) {
        $color = if ($rule.State -eq "Enabled") { "White" } else { "Gray" }
        Write-Host "`n[$($rule.Priority)] $($rule.Name) ($($rule.State))" -ForegroundColor $color
        Write-Host "  Conditions: $($rule.Conditions)" -ForegroundColor Gray
        Write-Host "  Actions:    $($rule.Actions)" -ForegroundColor Gray
        if ($rule.Exceptions -ne "None") {
            Write-Host "  Exceptions: $($rule.Exceptions)" -ForegroundColor Yellow
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
    Write-Error "Failed to generate transport rule report: $_"
    exit 1
}
