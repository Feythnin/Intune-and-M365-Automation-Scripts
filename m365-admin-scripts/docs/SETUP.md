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
Install-Module Microsoft.Graph.Reports -Scope CurrentUser
Install-Module Microsoft.Graph.Groups -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.SignIns -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.Governance -Scope CurrentUser
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
| Get-ServiceHealthDashboard | Microsoft Graph | ServiceHealth.Read.All |
| Get-MFAStatusReport | Microsoft Graph | UserAuthenticationMethod.Read.All, User.Read.All, AuditLog.Read.All |
| Get-GuestAccessAudit | Microsoft Graph | User.Read.All, AuditLog.Read.All, GroupMember.Read.All |
| Get-AdminRoleReport | Microsoft Graph | RoleManagement.Read.Directory, Directory.Read.All, AuditLog.Read.All, UserAuthenticationMethod.Read.All |
| Get-ConditionalAccessReport | Microsoft Graph | Policy.Read.All, Directory.Read.All |
| Export-ConditionalAccessBackup | Microsoft Graph | Policy.Read.All |
| Get-TeamsGovernanceReport | Microsoft Graph | Group.Read.All, Reports.Read.All, TeamSettings.Read.All |
| Invoke-UserOffboard | Microsoft Graph + Exchange | User.ReadWrite.All, Directory.ReadWrite.All, Group.ReadWrite.All + Exchange Admin |

## Connecting

### Exchange Online

```powershell
Connect-ExchangeOnline -UserPrincipalName admin@contoso.com
```

### Microsoft Graph

```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All", "AuditLog.Read.All", "ServiceHealth.Read.All", "UserAuthenticationMethod.Read.All", "Policy.Read.All", "RoleManagement.Read.Directory", "Group.ReadWrite.All", "Reports.Read.All", "TeamSettings.Read.All"
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
