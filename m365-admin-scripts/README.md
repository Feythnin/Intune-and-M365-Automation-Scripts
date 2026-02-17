# 📧 M365 Administration Scripts

A collection of PowerShell scripts for managing Microsoft 365 environments, focused on Exchange Online, licensing, and Entra ID administration. Built for sysadmins and MSP engineers who need to manage M365 tenants efficiently.

## Why This Exists

M365 admin tasks are repetitive and error-prone when done manually through the portal. These scripts automate the most common workflows — mailbox auditing, license reporting, bulk user operations, and shared mailbox management — so you can manage tenants in minutes instead of hours.

## Requirements

- PowerShell 7+
- [Exchange Online PowerShell Module](https://learn.microsoft.com/en-us/powershell/exchange/exchange-online-powershell)
- [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation)

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
Install-Module Microsoft.Graph.Users -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
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

## Usage

### Connect to Services

Most scripts need Exchange Online, Graph, or both:

```powershell
# Exchange Online
Connect-ExchangeOnline -UserPrincipalName admin@contoso.com

# Microsoft Graph
Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All", "AuditLog.Read.All"
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

## Project Structure

```
m365-admin-scripts/
├── scripts/
│   ├── Get-SharedMailboxReport.ps1
│   ├── Get-LicenseReport.ps1
│   ├── Get-MailboxPermissionAudit.ps1
│   ├── New-BulkUserOnboard.ps1
│   ├── Get-InactiveUserReport.ps1
│   └── Get-TransportRuleReport.ps1
├── docs/
│   └── SETUP.md
├── examples/
│   ├── sample-output.md
│   └── new-users-template.csv
├── LICENSE
└── README.md
```

## Notes

- All destructive operations support `-WhatIf` and require confirmation
- Designed for multi-tenant MSP use — disconnect and reconnect between tenants
- No client data, credentials, or tenant-specific information is included
- Tested against Exchange Online Management v3.x and Graph SDK v2.x

## License

MIT License — see [LICENSE](LICENSE) for details.

## Author

Built by an IT professional managing M365 environments across multiple MSP client tenants.
