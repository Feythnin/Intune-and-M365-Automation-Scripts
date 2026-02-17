<#
.SYNOPSIS
    Reports on Intune proactive remediation script execution results.

.DESCRIPTION
    Queries all proactive remediation (device health) scripts and their per-device
    execution results. Shows detection and remediation success/failure rates per
    script package.

.PARAMETER ScriptName
    Optional filter by remediation script package name.

.PARAMETER ExportPath
    Optional CSV export path.

.EXAMPLE
    .\Get-RemediationStatus.ps1
    Shows status for all remediation scripts.

.EXAMPLE
    .\Get-RemediationStatus.ps1 -ScriptName "Stale certs" -ExportPath ".\reports\remediation.csv"

.NOTES
    Requires: Microsoft.Graph.DeviceManagement module
    Permissions: DeviceManagementConfiguration.Read.All, DeviceManagementManagedDevices.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ScriptName,

    [Parameter()]
    [string]$ExportPath
)

#Requires -Modules Microsoft.Graph.DeviceManagement

$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

Write-Host "Querying proactive remediation scripts..." -ForegroundColor Cyan

try {
    # Get all remediation script packages (health scripts)
    $scripts = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts" -OutputType PSObject

    if (-not $scripts.value -or $scripts.value.Count -eq 0) {
        Write-Host "No proactive remediation scripts found." -ForegroundColor Yellow
        return
    }

    $scriptList = $scripts.value

    if ($ScriptName) {
        $scriptList = $scriptList | Where-Object { $_.displayName -like "*$ScriptName*" }
        if ($scriptList.Count -eq 0) {
            Write-Host "No scripts found matching '$ScriptName'." -ForegroundColor Yellow
            return
        }
    }

    Write-Host "Found $($scriptList.Count) remediation script(s). Gathering results...`n" -ForegroundColor Cyan

    $allResults = [System.Collections.Generic.List[PSCustomObject]]::new()
    $scriptSummaries = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($script in $scriptList) {
        Write-Host "  Checking: $($script.displayName)..." -ForegroundColor Gray

        try {
            # Get device run states
            $statesUri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($script.id)/deviceRunStates?`$expand=managedDevice"
            $states = @()
            $nextLink = $statesUri

            do {
                $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink -OutputType PSObject
                $states += $response.value
                $nextLink = $response.'@odata.nextLink'
            } while ($nextLink)

            $detectionSuccess = 0
            $detectionFailed = 0
            $remediationSuccess = 0
            $remediationFailed = 0
            $noIssue = 0
            $pending = 0

            foreach ($state in $states) {
                switch ($state.detectionState) {
                    "success" { $detectionSuccess++ }
                    "fail" { $detectionFailed++ }
                    "scriptError" { $detectionFailed++ }
                    "notApplicable" { $noIssue++ }
                    default { $pending++ }
                }

                if ($state.remediationState) {
                    switch ($state.remediationState) {
                        "success" { $remediationSuccess++ }
                        "remediationFailed" { $remediationFailed++ }
                        "scriptError" { $remediationFailed++ }
                    }
                }

                $deviceName = if ($state.managedDevice) { $state.managedDevice.deviceName } else { "Unknown" }
                $userPrincipal = if ($state.managedDevice) { $state.managedDevice.userPrincipalName } else { "Unknown" }

                $allResults.Add([PSCustomObject]@{
                    ScriptName         = $script.displayName
                    DeviceName         = $deviceName
                    UserPrincipal      = $userPrincipal
                    DetectionState     = $state.detectionState
                    RemediationState   = $state.remediationState
                    PreRemediationOutput  = if ($state.preRemediationDetectionScriptOutput) {
                        $state.preRemediationDetectionScriptOutput.Substring(0, [math]::Min(200, $state.preRemediationDetectionScriptOutput.Length))
                    } else { "" }
                    PostRemediationOutput = if ($state.postRemediationDetectionScriptOutput) {
                        $state.postRemediationDetectionScriptOutput.Substring(0, [math]::Min(200, $state.postRemediationDetectionScriptOutput.Length))
                    } else { "" }
                    LastStateModified  = if ($state.lastStateModifiedDateTime) { $state.lastStateModifiedDateTime } else { "Unknown" }
                    ScriptId           = $script.id
                })
            }

            $scriptSummaries.Add([PSCustomObject]@{
                ScriptName          = $script.displayName
                Publisher           = if ($script.publisher) { $script.publisher } else { "Custom" }
                TotalDevices        = $states.Count
                DetectionSuccess    = $detectionSuccess
                DetectionFailed     = $detectionFailed
                NoIssue             = $noIssue
                RemediationSuccess  = $remediationSuccess
                RemediationFailed   = $remediationFailed
                Pending             = $pending
            })
        } catch {
            Write-Host "    Could not retrieve status for $($script.displayName): $_" -ForegroundColor Yellow
        }

        Start-Sleep -Milliseconds 300
    }

    # === Dashboard ===
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  PROACTIVE REMEDIATION STATUS" -ForegroundColor Cyan
    Write-Host "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "Remediation scripts: $($scriptSummaries.Count)" -ForegroundColor White

    $totalRemSuccess = ($scriptSummaries | Measure-Object -Property RemediationSuccess -Sum).Sum
    $totalRemFailed = ($scriptSummaries | Measure-Object -Property RemediationFailed -Sum).Sum
    $totalDetFailed = ($scriptSummaries | Measure-Object -Property DetectionFailed -Sum).Sum

    if ($totalRemSuccess -gt 0) {
        Write-Host "Total successful remediations: $totalRemSuccess" -ForegroundColor Green
    }
    if ($totalRemFailed -gt 0) {
        Write-Host "Total failed remediations: $totalRemFailed" -ForegroundColor Red
    }
    if ($totalDetFailed -gt 0) {
        Write-Host "Total detection failures: $totalDetFailed" -ForegroundColor Yellow
    }

    # Script summary table
    Write-Host "`nPer-Script Summary:" -ForegroundColor Cyan
    $scriptSummaries | Format-Table ScriptName, TotalDevices, DetectionSuccess, DetectionFailed, RemediationSuccess, RemediationFailed -AutoSize

    # Show failures
    $failures = $allResults | Where-Object { $_.DetectionState -eq "fail" -or $_.DetectionState -eq "scriptError" -or $_.RemediationState -eq "remediationFailed" -or $_.RemediationState -eq "scriptError" }
    if ($failures.Count -gt 0 -and $failures.Count -le 25) {
        Write-Host "Failed Executions:" -ForegroundColor Red
        $failures | Format-Table ScriptName, DeviceName, DetectionState, RemediationState -AutoSize
    } elseif ($failures.Count -gt 25) {
        Write-Host "$($failures.Count) failures found — export to CSV for full details." -ForegroundColor Red
    }

    # Export
    if ($ExportPath) {
        $exportDir = Split-Path $ExportPath -Parent
        if ($exportDir -and -not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }
        $allResults | Export-Csv -Path $ExportPath -NoTypeInformation
        Write-Host "Report exported to: $ExportPath" -ForegroundColor Green
    }

    return $allResults

} catch {
    Write-Error "Failed to generate remediation status report: $_"
    exit 1
}
