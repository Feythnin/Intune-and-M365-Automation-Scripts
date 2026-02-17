<#
.SYNOPSIS
    Onboards new users from a CSV file — creates Entra accounts, assigns licenses, and adds to groups.

.DESCRIPTION
    Reads a CSV of new employees and creates their Microsoft Entra ID accounts with
    appropriate licenses and group memberships. Includes WhatIf support, validation,
    and detailed logging.

.PARAMETER CsvPath
    Path to the CSV file with user data. Required columns: DisplayName, UserPrincipalName,
    FirstName, LastName. Optional: Department, JobTitle, UsageLocation.

.PARAMETER DefaultLicense
    SKU part number for the default license to assign (e.g., "ENTERPRISEPACK", "SPE_E3").

.PARAMETER Groups
    Array of Entra group display names to add users to.

.PARAMETER TempPassword
    Temporary password for new accounts. If not specified, a random password is generated.

.PARAMETER LogPath
    Optional log file path.

.EXAMPLE
    .\New-BulkUserOnboard.ps1 -CsvPath ".\new-users.csv" -WhatIf
    Preview what would be created.

.EXAMPLE
    .\New-BulkUserOnboard.ps1 -CsvPath ".\new-users.csv" -DefaultLicense "SPE_E3" -Groups "All Employees","VPN Users"

.NOTES
    Requires: Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement
    Permissions: User.ReadWrite.All, Directory.ReadWrite.All
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)]
    [string]$CsvPath,

    [Parameter()]
    [string]$DefaultLicense,

    [Parameter()]
    [string[]]$Groups,

    [Parameter()]
    [string]$TempPassword,

    [Parameter()]
    [string]$LogPath
)

#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Write-Host $entry -ForegroundColor $(switch ($Level) { "WARN" { "Yellow" } "ERROR" { "Red" } "SUCCESS" { "Green" } default { "White" } })
    if ($LogPath) { Add-Content -Path $LogPath -Value $entry }
}

function New-RandomPassword {
    $chars = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%"
    $password = [System.Text.StringBuilder]::new(16)
    $random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 4
    for ($i = 0; $i -lt 16; $i++) {
        $random.GetBytes($bytes)
        $index = [System.BitConverter]::ToUInt32($bytes, 0) % $chars.Length
        $null = $password.Append($chars[$index])
    }
    return $password.ToString()
}

# Verify connection
$context = Get-MgContext
if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    exit 1
}

# Validate CSV
if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV file not found: $CsvPath"
    exit 1
}

$users = Import-Csv $CsvPath

# Validate required columns
$requiredColumns = @("DisplayName", "UserPrincipalName", "FirstName", "LastName")
$csvColumns = $users[0].PSObject.Properties.Name
$missingColumns = $requiredColumns | Where-Object { $_ -notin $csvColumns }
if ($missingColumns.Count -gt 0) {
    Write-Error "CSV missing required columns: $($missingColumns -join ', ')"
    exit 1
}

# Initialize log
if ($LogPath) {
    $logDir = Split-Path $LogPath -Parent
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    Write-Log "=== Bulk User Onboarding Started ==="
    Write-Log "CSV: $CsvPath | Users: $($users.Count) | License: $DefaultLicense"
}

# Resolve license SKU
$licenseSkuId = $null
if ($DefaultLicense) {
    $sku = Get-MgSubscribedSku -All | Where-Object { $_.SkuPartNumber -eq $DefaultLicense }
    if (-not $sku) {
        Write-Error "License SKU '$DefaultLicense' not found in tenant."
        exit 1
    }
    $available = $sku.PrepaidUnits.Enabled - $sku.ConsumedUnits
    if ($available -lt $users.Count) {
        Write-Log "WARNING: Only $available licenses available for $($users.Count) users" "WARN"
    }
    $licenseSkuId = $sku.SkuId
}

# Resolve groups
$groupIds = @()
if ($Groups) {
    foreach ($groupName in $Groups) {
        $group = Get-MgGroup -Filter "displayName eq '$groupName'" -Top 1
        if ($group) {
            $groupIds += $group.Id
            Write-Log "Resolved group: $groupName -> $($group.Id)"
        } else {
            Write-Log "Group not found: $groupName" "WARN"
        }
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  BULK USER ONBOARDING" -ForegroundColor Cyan
Write-Host "  Users to create: $($users.Count)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$successCount = 0
$failCount = 0
$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($user in $users) {
    $upn = $user.UserPrincipalName
    $password = if ($TempPassword) { $TempPassword } else { New-RandomPassword }

    # Check if user already exists
    $existing = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Log "SKIPPED: $upn already exists" "WARN"
        $results.Add([PSCustomObject]@{
            UserPrincipalName = $upn
            DisplayName       = $user.DisplayName
            Status            = "Skipped - Already Exists"
            Password          = ""
        })
        continue
    }

    if ($PSCmdlet.ShouldProcess($upn, "Create user account")) {
        try {
            # Create user
            $params = @{
                DisplayName       = $user.DisplayName
                UserPrincipalName = $upn
                GivenName         = $user.FirstName
                Surname           = $user.LastName
                MailNickname      = $upn.Split("@")[0]
                AccountEnabled    = $true
                UsageLocation     = if ($user.UsageLocation) { $user.UsageLocation } else { "US" }
                PasswordProfile   = @{
                    Password                      = $password
                    ForceChangePasswordNextSignIn = $true
                }
            }

            if ($user.Department) { $params.Department = $user.Department }
            if ($user.JobTitle) { $params.JobTitle = $user.JobTitle }

            $newUser = New-MgUser @params
            Write-Log "CREATED: $upn ($($user.DisplayName))" "SUCCESS"

            # Assign license
            if ($licenseSkuId) {
                try {
                    Set-MgUserLicense -UserId $newUser.Id -AddLicenses @(@{SkuId = $licenseSkuId}) -RemoveLicenses @()
                    Write-Log "  Licensed: $DefaultLicense assigned to $upn" "SUCCESS"
                } catch {
                    Write-Log "  License assignment failed for $upn : $_" "ERROR"
                }
            }

            # Add to groups
            foreach ($gId in $groupIds) {
                try {
                    New-MgGroupMember -GroupId $gId -DirectoryObjectId $newUser.Id
                    Write-Log "  Group: Added $upn to group $gId" "SUCCESS"
                } catch {
                    Write-Log "  Group add failed for $upn : $_" "ERROR"
                }
            }

            $results.Add([PSCustomObject]@{
                UserPrincipalName = $upn
                DisplayName       = $user.DisplayName
                Status            = "Created"
                Password          = $password
            })
            $successCount++

        } catch {
            Write-Log "FAILED: $upn - $_" "ERROR"
            $results.Add([PSCustomObject]@{
                UserPrincipalName = $upn
                DisplayName       = $user.DisplayName
                Status            = "Failed - $_"
                Password          = ""
            })
            $failCount++
        }
    }

    Start-Sleep -Milliseconds 300
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Log "=== Onboarding Complete ==="
Write-Log "Created: $successCount | Failed: $failCount | Total: $($users.Count)"

# Display results with temporary passwords
if (-not $WhatIfPreference) {
    Write-Host "`nNew User Credentials (distribute securely):" -ForegroundColor Yellow
    $results | Where-Object Status -eq "Created" | Format-Table DisplayName, UserPrincipalName, Password -AutoSize
}

return $results
