# Setup Guide

## Prerequisites

### PowerShell 7+

```powershell
$PSVersionTable.PSVersion
```

### Required Modules

```powershell
# Exchange Online
Install-Module ExchangeOnlineManagement -Scope CurrentUser

# Microsoft Graph
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.Users -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
```

### Permissions

| Script | Service | Required Permission |
|--------|---------|-------------------|
| Get-SharedMailboxReport | Exchange Online | Exchange Administrator |
| Get-LicenseReport | Microsoft Graph | Directory.Read.All |
| Get-MailboxPermissionAudit | Exchange Online | Exchange Administrator |
| New-BulkUserOnboard | Microsoft Graph | User.ReadWrite.All, Directory.ReadWrite.All |
| Get-InactiveUserReport | Microsoft Graph | User.Read.All, AuditLog.Read.All |
| Get-TransportRuleReport | Exchange Online | Exchange Administrator |

## Connecting

### Exchange Online

```powershell
Connect-ExchangeOnline -UserPrincipalName admin@contoso.com
```

### Microsoft Graph

```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All", "AuditLog.Read.All"
```

### Multi-Tenant (MSP)

```powershell
# Client A
Connect-ExchangeOnline -UserPrincipalName admin@clienta.com
# Run scripts...
Disconnect-ExchangeOnline -Confirm:$false

# Client B
Connect-ExchangeOnline -UserPrincipalName admin@clientb.com
```

## Folder Setup

```powershell
New-Item -ItemType Directory -Path ".\reports" -Force
New-Item -ItemType Directory -Path ".\logs" -Force
```

## CSV Template for Bulk Onboarding

See `examples/new-users-template.csv` for the required format.
