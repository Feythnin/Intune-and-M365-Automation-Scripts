<#
.SYNOPSIS
    Reports on BitLocker encryption status and recovery key escrow for Windows devices.

.DESCRIPTION
    Queries all Windows managed devices for their encryption status and checks
    whether BitLocker recovery keys have been escrowed to Entra ID. Identifies
    unencrypted devices and devices missing recovery key backup.

.PARAMETER ExportPath
    Optional CSV export path.

.PARAMETER UnencryptedOnly
    Only show devices that are not encrypted.

.EXAMPLE
    .\Get-BitLockerStatus.ps1
    Shows encryption status for all Windows devices.

.EXAMPLE
    .\Get-BitLockerStatus.ps1 -UnencryptedOnly -ExportPath ".\reports\unencrypted.csv"

.NOTES
    Requires: Microsoft.Graph.DeviceManagement module
    Permissions: DeviceManagementManagedDevices.Read.All, BitLockerKey.Read.All
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ExportPath,

    [Parameter()]
    [switch]$UnencryptedOnly
)

#Requires -Modules Microsoft.Graph.DeviceManagement

$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

Write-Host "Querying BitLocker encryption status..." -ForegroundColor Cyan

try {
    # Get all Windows managed devices
    $allDevices = Get-MgDeviceManagementManagedDevice -All | Where-Object {
        $_.OperatingSystem -eq "Windows"
    }

    if ($allDevices.Count -eq 0) {
        Write-Host "No Windows managed devices found." -ForegroundColor Yellow
        return
    }

    Write-Host "Found $($allDevices.Count) Windows devices. Checking encryption and recovery keys..." -ForegroundColor Cyan

    # Get Entra device objects to check for escrowed recovery keys
    $recoveryKeyDevices = @{}
    try {
        $entraDevices = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/informationProtection/bitlocker/recoveryKeys?`$select=id,deviceId,createdDateTime" -OutputType PSObject
        if ($entraDevices.value) {
            foreach ($key in $entraDevices.value) {
                $recoveryKeyDevices[$key.deviceId] = $key.createdDateTime
            }
            Write-Host "Found recovery keys for $($recoveryKeyDevices.Count) device(s)." -ForegroundColor Cyan
        }
    } catch {
        Write-Host "Could not query BitLocker recovery keys. Ensure BitLockerKey.Read.All permission is granted." -ForegroundColor Yellow
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($device in $allDevices) {
        $hasRecoveryKey = $recoveryKeyDevices.ContainsKey($device.AzureAdDeviceId)
        $keyEscrowDate = if ($hasRecoveryKey) {
            try { ([datetime]$recoveryKeyDevices[$device.AzureAdDeviceId]).ToString("yyyy-MM-dd") } catch { "Yes" }
        } else { "None" }

        $result = [PSCustomObject]@{
            DeviceName        = $device.DeviceName
            UserPrincipalName = $device.UserPrincipalName
            OSVersion         = $device.OsVersion
            IsEncrypted       = $device.IsEncrypted
            ComplianceState   = $device.ComplianceState
            HasRecoveryKey    = $hasRecoveryKey
            KeyEscrowDate     = $keyEscrowDate
            Model             = $device.Model
            Manufacturer      = $device.Manufacturer
            SerialNumber      = $device.SerialNumber
            LastSync          = if ($device.LastSyncDateTime) { $device.LastSyncDateTime.ToString("yyyy-MM-dd HH:mm") } else { "Never" }
            EnrollmentDate    = if ($device.EnrolledDateTime) { $device.EnrolledDateTime.ToString("yyyy-MM-dd") } else { "Unknown" }
        }

        $results.Add($result)
    }

    if ($UnencryptedOnly) {
        $results = [System.Collections.Generic.List[PSCustomObject]]::new(
            [PSCustomObject[]]($results | Where-Object IsEncrypted -ne $true)
        )
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new(
        [PSCustomObject[]]($results | Sort-Object IsEncrypted, DeviceName)
    )

    # === Dashboard ===
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  BITLOCKER STATUS REPORT" -ForegroundColor Cyan
    Write-Host "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $totalDevices = $allDevices.Count
    $encrypted = ($allDevices | Where-Object IsEncrypted -eq $true).Count
    $unencrypted = $totalDevices - $encrypted
    $encryptionRate = if ($totalDevices -gt 0) { [math]::Round(($encrypted / $totalDevices) * 100, 1) } else { 0 }
    $allResultsUnfiltered = [System.Collections.Generic.List[PSCustomObject]]::new(
        [PSCustomObject[]]($allDevices | ForEach-Object { [PSCustomObject]@{ IsEncrypted = $_.IsEncrypted; HasRecoveryKey = $recoveryKeyDevices.ContainsKey($_.AzureAdDeviceId) } })
    )
    $withKeys = ($allResultsUnfiltered | Where-Object HasRecoveryKey -eq $true).Count
    $encryptedNoKey = ($allResultsUnfiltered | Where-Object { $_.IsEncrypted -eq $true -and $_.HasRecoveryKey -eq $false }).Count

    Write-Host "Total Windows devices: $totalDevices" -ForegroundColor White
    Write-Host "Encrypted: $encrypted ($encryptionRate%)" -ForegroundColor $(if ($encryptionRate -ge 95) { "Green" } elseif ($encryptionRate -ge 80) { "Yellow" } else { "Red" })

    if ($unencrypted -gt 0) {
        Write-Host "NOT encrypted: $unencrypted" -ForegroundColor Red
    }

    Write-Host "Recovery keys escrowed: $withKeys" -ForegroundColor White

    if ($encryptedNoKey -gt 0) {
        Write-Host "Encrypted WITHOUT recovery key: $encryptedNoKey" -ForegroundColor Yellow
    }

    # Show unencrypted devices
    $unencryptedDevices = $results | Where-Object IsEncrypted -ne $true
    if ($unencryptedDevices.Count -gt 0) {
        Write-Host "`nUnencrypted Devices:" -ForegroundColor Red
        $unencryptedDevices | Format-Table DeviceName, UserPrincipalName, OSVersion, ComplianceState, LastSync -AutoSize
    }

    # Show encrypted devices missing recovery keys
    $missingKeys = $results | Where-Object { $_.IsEncrypted -eq $true -and $_.HasRecoveryKey -eq $false }
    if ($missingKeys.Count -gt 0 -and $missingKeys.Count -le 20) {
        Write-Host "Encrypted Devices Missing Recovery Key:" -ForegroundColor Yellow
        $missingKeys | Format-Table DeviceName, UserPrincipalName, OSVersion -AutoSize
    } elseif ($missingKeys.Count -gt 20) {
        Write-Host "$($missingKeys.Count) encrypted devices missing recovery keys — export to CSV for details." -ForegroundColor Yellow
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
    Write-Error "Failed to generate BitLocker status report: $_"
    exit 1
}
