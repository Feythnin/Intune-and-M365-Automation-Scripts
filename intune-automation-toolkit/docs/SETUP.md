# Setup Guide

## Prerequisites

### PowerShell 7+

These scripts are built for PowerShell 7. Check your version:

```powershell
$PSVersionTable.PSVersion
```

If you need to install it: [Install PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)

### Microsoft Graph PowerShell SDK

Install the required modules:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.DeviceManagement -Scope CurrentUser
```

### Entra ID Permissions

The account you authenticate with needs appropriate roles. At minimum:

| Script | Required Permission |
|--------|-------------------|
| Get-StaleDevices | DeviceManagementManagedDevices.Read.All |
| Get-ComplianceReport | DeviceManagementManagedDevices.Read.All |
| Get-AppDeploymentStatus | DeviceManagementApps.Read.All |
| Remove-StaleDevices | DeviceManagementManagedDevices.ReadWrite.All |
| Get-AutopilotStatus | DeviceManagementServiceConfig.Read.All |
| Export-DeviceInventory | DeviceManagementManagedDevices.Read.All |

For MSP environments, you'll typically need Intune Administrator or a custom role with the above permissions in each client tenant.

## Connecting

### Single Tenant

```powershell
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All", "DeviceManagementConfiguration.Read.All", "DeviceManagementApps.Read.All", "DeviceManagementServiceConfig.Read.All"
```

### Multi-Tenant (MSP)

When managing multiple client tenants, disconnect and reconnect between each:

```powershell
# Connect to Client A
Connect-MgGraph -TenantId "client-a-tenant-id" -Scopes "DeviceManagementManagedDevices.Read.All"

# Run your scripts...

# Switch to Client B
Disconnect-MgGraph
Connect-MgGraph -TenantId "client-b-tenant-id" -Scopes "DeviceManagementManagedDevices.Read.All"
```

## Folder Setup

Create a reports folder for exports:

```powershell
New-Item -ItemType Directory -Path ".\reports" -Force
New-Item -ItemType Directory -Path ".\logs" -Force
```

## Testing

Always test with read-only scripts first (Get-StaleDevices, Get-ComplianceReport) before running anything destructive.

For Remove-StaleDevices, **always** run with `-WhatIf` first:

```powershell
.\scripts\Remove-StaleDevices.ps1 -InactiveDays 90 -WhatIf
```
