# Intune & M365 Automation Scripts

PowerShell toolkits for managing Microsoft Intune and Microsoft 365 environments at scale. Built for IT administrators and MSP engineers who manage endpoints and tenants across multiple client organizations.

## Why This Exists

Clicking through admin portals works fine for one device or one user. It doesn't work when you're managing hundreds of endpoints and accounts across multiple organizations. These scripts automate the repetitive tasks that eat up an admin's day — compliance reporting, stale device cleanup, license auditing, bulk user onboarding, and more.

## Requirements

- PowerShell 7+
- [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation)
- [Exchange Online PowerShell Module](https://learn.microsoft.com/en-us/powershell/exchange/exchange-online-powershell) (for M365 admin scripts)
- Appropriate permissions in Microsoft Entra ID

```powershell
# Graph modules (Intune + Entra ID)
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.DeviceManagement -Scope CurrentUser
Install-Module Microsoft.Graph.Users -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser

# Exchange Online
Install-Module ExchangeOnlineManagement -Scope CurrentUser
```

## Toolkits

### Intune Automation Toolkit

Scripts for device management, compliance reporting, and endpoint lifecycle automation.

| Script | Description |
|--------|-------------|
| [`Get-StaleDevices.ps1`](intune-automation-toolkit/scripts/Get-StaleDevices.ps1) | Finds devices that haven't checked in within a configurable number of days |
| [`Get-ComplianceReport.ps1`](intune-automation-toolkit/scripts/Get-ComplianceReport.ps1) | Generates a compliance status report across all managed devices |
| [`Get-AppDeploymentStatus.ps1`](intune-automation-toolkit/scripts/Get-AppDeploymentStatus.ps1) | Reports on application installation success/failure rates |
| [`Remove-StaleDevices.ps1`](intune-automation-toolkit/scripts/Remove-StaleDevices.ps1) | Removes or retires stale devices with safety checks and logging |
| [`Get-AutopilotStatus.ps1`](intune-automation-toolkit/scripts/Get-AutopilotStatus.ps1) | Reports on Autopilot deployment profile assignments and enrollment status |
| [`Export-DeviceInventory.ps1`](intune-automation-toolkit/scripts/Export-DeviceInventory.ps1) | Exports full device inventory with hardware details to CSV |

### M365 Administration Scripts

Scripts for Exchange Online, licensing, and Entra ID user management.

| Script | Description |
|--------|-------------|
| [`Get-SharedMailboxReport.ps1`](m365-admin-scripts/scripts/Get-SharedMailboxReport.ps1) | Audits all shared mailboxes with permissions, sizes, and delegate access |
| [`Get-LicenseReport.ps1`](m365-admin-scripts/scripts/Get-LicenseReport.ps1) | Reports on M365 license assignments, usage, and available counts |
| [`Get-MailboxPermissionAudit.ps1`](m365-admin-scripts/scripts/Get-MailboxPermissionAudit.ps1) | Full audit of mailbox permissions (Full Access, Send As, Send on Behalf) |
| [`New-BulkUserOnboard.ps1`](m365-admin-scripts/scripts/New-BulkUserOnboard.ps1) | Onboards users from CSV — creates accounts, assigns licenses, adds to groups |
| [`Get-InactiveUserReport.ps1`](m365-admin-scripts/scripts/Get-InactiveUserReport.ps1) | Finds users who haven't signed in within a configurable threshold |
| [`Get-TransportRuleReport.ps1`](m365-admin-scripts/scripts/Get-TransportRuleReport.ps1) | Documents all Exchange transport rules with conditions and actions |

## Quick Start

### Connect to Services

```powershell
# Microsoft Graph (for Intune and Entra ID scripts)
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All", "DeviceManagementConfiguration.Read.All", "User.Read.All", "Directory.Read.All", "AuditLog.Read.All"

# Exchange Online (for mailbox and transport rule scripts)
Connect-ExchangeOnline -UserPrincipalName admin@contoso.com
```

### Intune Examples

```powershell
# Find devices inactive for 60+ days, export to CSV
.\intune-automation-toolkit\scripts\Get-StaleDevices.ps1 -InactiveDays 60 -ExportPath ".\reports\stale.csv"

# Compliance report filtered to Windows
.\intune-automation-toolkit\scripts\Get-ComplianceReport.ps1 -OSFilter "Windows"

# Check failed app deployments
.\intune-automation-toolkit\scripts\Get-AppDeploymentStatus.ps1 -StatusFilter "Failed"

# Preview stale device cleanup (no changes made)
.\intune-automation-toolkit\scripts\Remove-StaleDevices.ps1 -InactiveDays 90 -WhatIf

# Export full device inventory
.\intune-automation-toolkit\scripts\Export-DeviceInventory.ps1 -ExportPath ".\reports\inventory.csv"
```

### M365 Examples

```powershell
# License usage summary
.\m365-admin-scripts\scripts\Get-LicenseReport.ps1

# Audit all mailbox permissions
.\m365-admin-scripts\scripts\Get-MailboxPermissionAudit.ps1 -ExportPath ".\reports\permissions.csv"

# Find inactive licensed users (potential cost savings)
.\m365-admin-scripts\scripts\Get-InactiveUserReport.ps1 -InactiveDays 90 -LicensedOnly

# Preview bulk user onboarding (no changes made)
.\m365-admin-scripts\scripts\New-BulkUserOnboard.ps1 -CsvPath ".\new-users.csv" -WhatIf

# Shared mailbox audit with sizes
.\m365-admin-scripts\scripts\Get-SharedMailboxReport.ps1 -IncludeSize -ExportPath ".\reports\shared.csv"
```

## Project Structure

```
.
├── intune-automation-toolkit/
│   ├── scripts/          # Intune management scripts
│   ├── docs/SETUP.md     # Detailed setup and permissions guide
│   ├── examples/         # Sample output
│   ├── LICENSE
│   └── README.md
├── m365-admin-scripts/
│   ├── scripts/          # M365 administration scripts
│   ├── docs/SETUP.md     # Detailed setup and permissions guide
│   ├── examples/         # Sample output and CSV templates
│   ├── LICENSE
│   └── README.md
└── README.md
```

## Notes

- All destructive operations (`Remove-StaleDevices`, `New-BulkUserOnboard`) support `-WhatIf` and require explicit confirmation
- Designed for multi-tenant MSP use — disconnect and reconnect between tenants
- No client data, credentials, or tenant-specific information is included in this repository
- Tested against Microsoft Graph PowerShell SDK v2.x and Exchange Online Management v3.x

## License

MIT License — see [LICENSE](intune-automation-toolkit/LICENSE) for details.

## Author

Built by an IT professional managing Intune and M365 environments across multiple MSP client tenants.
