# 📧 M365 Administration Scripts

A collection of PowerShell scripts for managing Microsoft 365 environments, covering Exchange Online, licensing, Entra ID, Teams governance, security posture, and user lifecycle management. Built for sysadmins and MSP engineers who need to manage M365 tenants efficiently.

## Why This Exists

M365 admin tasks are repetitive and error-prone when done manually through the portal. These scripts automate the most common workflows — mailbox auditing, license reporting, MFA compliance, Conditional Access documentation, Teams governance, bulk user operations, and offboarding — so you can manage tenants in minutes instead of hours.

## Requirements

- PowerShell 7+
- [Exchange Online PowerShell Module](https://learn.microsoft.com/en-us/powershell/exchange/exchange-online-powershell)
- [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation)

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
Install-Module Microsoft.Graph.Users -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
Install-Module Microsoft.Graph.Reports -Scope CurrentUser
Install-Module Microsoft.Graph.Groups -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.SignIns -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.Governance -Scope CurrentUser
```

## Scripts

| Script | Description |
|--------|-------------|
| `Get-SharedMailboxReport.ps1` | Audits all shared mailboxes with permissions, sizes, and delegate access |
| `Get-LicenseReport.ps1` | Reports on M365 license assignments, usage, and available counts |
| `Get-MailboxPermissionAudit.ps1` | Full audit of mailbox permissions (Full Access, Send As, Send on Behalf) |
| `New-BulkUserOnboard.ps1` | Onboards users from CSV — creates accounts, assigns licenses, adds to groups |
| `Get-InactiveUserReport.ps1` | Finds users who haven't signed in within a configurable threshold |
| `Get-TransportRuleReport.ps1` | Documents all Exchange transport rules with conditions and actions |
| `Get-ServiceHealthDashboard.ps1` | Displays M365 service health status with active incidents and advisories |
| `Get-MFAStatusReport.ps1` | Reports on MFA registration status with method breakdown per user |
| `Get-GuestAccessAudit.ps1` | Audits guest users with sign-in activity and staleness detection |
| `Get-AdminRoleReport.ps1` | Reports on Entra ID admin role assignments with MFA and PIM status |
| `Get-ConditionalAccessReport.ps1` | Documents all Conditional Access policies with conditions and grants |
| `Export-ConditionalAccessBackup.ps1` | Exports Conditional Access policies as individual JSON backup files |
| `Get-TeamsGovernanceReport.ps1` | Reports on Teams governance — ownership, activity, and guest access |
| `Invoke-UserOffboard.ps1` | Offboards users — disables accounts, revokes sessions, reclaims licenses |

## Usage

### Connect to Services

Most scripts need Exchange Online, Graph, or both:

```powershell
# Exchange Online
Connect-ExchangeOnline -UserPrincipalName admin@contoso.com

# Microsoft Graph
Connect-MgGraph -Scopes "User.Read.All", "User.ReadWrite.All", "Directory.Read.All", "Directory.ReadWrite.All", "AuditLog.Read.All", "ServiceHealth.Read.All", "UserAuthenticationMethod.Read.All", "Policy.Read.All", "RoleManagement.Read.Directory", "Group.Read.All", "Group.ReadWrite.All", "Reports.Read.All", "TeamSettings.Read.All"
```

### Audit Shared Mailboxes

```powershell
# Full shared mailbox report
.\scripts\Get-SharedMailboxReport.ps1

# Export to CSV
.\scripts\Get-SharedMailboxReport.ps1 -ExportPath ".\reports\shared-mailboxes.csv"

# Include mailbox sizes (slower, queries each mailbox individually)
.\scripts\Get-SharedMailboxReport.ps1 -IncludeSize -ExportPath ".\reports\shared-mailboxes.csv"
```

### License Usage Report

```powershell
# Summary of all license types
.\scripts\Get-LicenseReport.ps1

# Show users with a specific SKU
.\scripts\Get-LicenseReport.ps1 -SkuFilter "ENTERPRISEPACK"

# Export detailed per-user license assignments
.\scripts\Get-LicenseReport.ps1 -Detailed -ExportPath ".\reports\licenses.csv"
```

### Permission Audit

```powershell
# Audit all mailbox permissions
.\scripts\Get-MailboxPermissionAudit.ps1

# Audit a specific mailbox
.\scripts\Get-MailboxPermissionAudit.ps1 -Mailbox "info@contoso.com"

# Export for compliance review
.\scripts\Get-MailboxPermissionAudit.ps1 -ExportPath ".\reports\permissions.csv"
```

### Bulk User Onboarding

```powershell
# Preview what would be created (WhatIf)
.\scripts\New-BulkUserOnboard.ps1 -CsvPath ".\new-users.csv" -WhatIf

# Create users with license assignment
.\scripts\New-BulkUserOnboard.ps1 -CsvPath ".\new-users.csv" -DefaultLicense "ENTERPRISEPACK"
```

CSV format:
```csv
DisplayName,UserPrincipalName,FirstName,LastName,Department,JobTitle
Jane Smith,jsmith@contoso.com,Jane,Smith,Marketing,Marketing Manager
Bob Lee,blee@contoso.com,Bob,Lee,Engineering,Developer
```

### Find Inactive Users

```powershell
# Users who haven't signed in for 90+ days
.\scripts\Get-InactiveUserReport.ps1 -InactiveDays 90

# Include licensed-only users (skip unlicensed service accounts)
.\scripts\Get-InactiveUserReport.ps1 -InactiveDays 60 -LicensedOnly

# Export for review
.\scripts\Get-InactiveUserReport.ps1 -InactiveDays 90 -ExportPath ".\reports\inactive.csv"
```

### Service Health Dashboard

```powershell
# Check all M365 service health
.\scripts\Get-ServiceHealthDashboard.ps1

# Filter to Exchange issues
.\scripts\Get-ServiceHealthDashboard.ps1 -ServiceFilter "Exchange"

# Include resolved issues
.\scripts\Get-ServiceHealthDashboard.ps1 -ShowResolved -ExportPath ".\reports\health.csv"
```

### MFA Status Report

```powershell
# MFA status for all members
.\scripts\Get-MFAStatusReport.ps1

# Include guest users
.\scripts\Get-MFAStatusReport.ps1 -IncludeGuests -ExportPath ".\reports\mfa.csv"
```

### Guest Access Audit

```powershell
# Audit guests with 90-day staleness threshold
.\scripts\Get-GuestAccessAudit.ps1

# Include group memberships (slower)
.\scripts\Get-GuestAccessAudit.ps1 -StaleDays 60 -IncludeGroupMemberships -ExportPath ".\reports\guests.csv"
```

### Admin Role Report

```powershell
# Active role assignments
.\scripts\Get-AdminRoleReport.ps1

# Include PIM eligible roles
.\scripts\Get-AdminRoleReport.ps1 -IncludePIM -ExportPath ".\reports\admin-roles.csv"
```

### Conditional Access

```powershell
# Report on enabled and report-only policies
.\scripts\Get-ConditionalAccessReport.ps1

# Include disabled policies
.\scripts\Get-ConditionalAccessReport.ps1 -IncludeDisabled -ExportPath ".\reports\ca-policies.csv"

# Backup all policies as JSON files
.\scripts\Export-ConditionalAccessBackup.ps1

# Backup to a specific directory including disabled
.\scripts\Export-ConditionalAccessBackup.ps1 -OutputDirectory "C:\Backups\CA" -IncludeDisabled
```

### Teams Governance

```powershell
# Teams governance report
.\scripts\Get-TeamsGovernanceReport.ps1

# Custom inactivity threshold
.\scripts\Get-TeamsGovernanceReport.ps1 -InactiveDays 60 -ExportPath ".\reports\teams.csv"
```

### User Offboarding

```powershell
# Preview offboarding (WhatIf)
.\scripts\Invoke-UserOffboard.ps1 -UserPrincipalName "jsmith@contoso.com" -WhatIf

# Offboard with mailbox conversion and forwarding
.\scripts\Invoke-UserOffboard.ps1 -UserPrincipalName "jsmith@contoso.com" -ConvertToSharedMailbox -ForwardingAddress "manager@contoso.com"

# Bulk offboarding from CSV
.\scripts\Invoke-UserOffboard.ps1 -CsvPath ".\offboard-users.csv" -ConvertToSharedMailbox -LogPath ".\logs\offboard.log"
```

## Project Structure

```
m365-admin-scripts/
├── scripts/
│   ├── Get-SharedMailboxReport.ps1
│   ├── Get-LicenseReport.ps1
│   ├── Get-MailboxPermissionAudit.ps1
│   ├── New-BulkUserOnboard.ps1
│   ├── Get-InactiveUserReport.ps1
│   ├── Get-TransportRuleReport.ps1
│   ├── Get-ServiceHealthDashboard.ps1
│   ├── Get-MFAStatusReport.ps1
│   ├── Get-GuestAccessAudit.ps1
│   ├── Get-AdminRoleReport.ps1
│   ├── Get-ConditionalAccessReport.ps1
│   ├── Export-ConditionalAccessBackup.ps1
│   ├── Get-TeamsGovernanceReport.ps1
│   └── Invoke-UserOffboard.ps1
├── docs/
│   └── SETUP.md
├── examples/
│   ├── sample-output.md
│   └── new-users-template.csv
├── LICENSE
└── README.md
```

## Notes

- All destructive operations (`New-BulkUserOnboard`, `Invoke-UserOffboard`) support `-WhatIf` and require confirmation
- Designed for multi-tenant MSP use — disconnect and reconnect between tenants
- No client data, credentials, or tenant-specific information is included
- Tested against Exchange Online Management v3.x and Graph SDK v2.x

## License

MIT License — see [LICENSE](LICENSE) for details.

## Author

Built by an IT professional managing M365 environments across multiple MSP client tenants.
