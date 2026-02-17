# 🖥️ Intune Automation Toolkit

A collection of PowerShell scripts for managing and automating Microsoft Intune environments at scale. Built for IT administrators and MSP engineers who manage endpoints across multiple client tenants.

## Why This Exists

Clicking through the Intune portal works fine for one device. It doesn't work when you're managing hundreds of endpoints across multiple organizations. These scripts automate the repetitive tasks that eat up an admin's day — compliance reporting, stale device cleanup, app deployment tracking, and Autopilot management.

## Requirements

- PowerShell 7+
- [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation)
- Appropriate permissions in Microsoft Entra ID (Intune Administrator or equivalent)

```powershell
# Install the Graph modules you'll need
Install-Module Microsoft.Graph.Intune -Scope CurrentUser
Install-Module Microsoft.Graph.DeviceManagement -Scope CurrentUser
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

## Scripts

| Script | Description |
|--------|-------------|
| `Get-StaleDevices.ps1` | Finds devices that haven't checked in within a configurable number of days |
| `Get-ComplianceReport.ps1` | Generates a compliance status report across all managed devices |
| `Get-AppDeploymentStatus.ps1` | Reports on application installation success/failure rates |
| `Remove-StaleDevices.ps1` | Removes or retires stale devices with safety checks and logging |
| `Get-AutopilotStatus.ps1` | Reports on Autopilot deployment profile assignments and enrollment status |
| `Export-DeviceInventory.ps1` | Exports full device inventory with hardware details to CSV |

## Usage

### Connect to Microsoft Graph

All scripts require an authenticated Graph session. Connect first:

```powershell
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All", "DeviceManagementConfiguration.Read.All"
```

### Find Stale Devices

```powershell
# Find devices inactive for 30+ days (default)
.\scripts\Get-StaleDevices.ps1

# Custom threshold - find devices inactive for 60+ days
.\scripts\Get-StaleDevices.ps1 -InactiveDays 60

# Export results to CSV
.\scripts\Get-StaleDevices.ps1 -InactiveDays 45 -ExportPath ".\reports\stale-devices.csv"
```

### Generate Compliance Report

```powershell
# Full compliance report
.\scripts\Get-ComplianceReport.ps1

# Filter by OS
.\scripts\Get-ComplianceReport.ps1 -OSFilter "Windows"

# Export to CSV
.\scripts\Get-ComplianceReport.ps1 -ExportPath ".\reports\compliance.csv"
```

### Check App Deployment Status

```powershell
# All app deployments
.\scripts\Get-AppDeploymentStatus.ps1

# Specific app
.\scripts\Get-AppDeploymentStatus.ps1 -AppName "Microsoft 365 Apps"

# Only show failures
.\scripts\Get-AppDeploymentStatus.ps1 -StatusFilter "Failed"
```

### Clean Up Stale Devices

```powershell
# Preview what would be removed (WhatIf mode - no changes made)
.\scripts\Remove-StaleDevices.ps1 -InactiveDays 90 -WhatIf

# Actually retire stale devices (with confirmation prompts)
.\scripts\Remove-StaleDevices.ps1 -InactiveDays 90 -Action Retire

# Delete stale devices with logging
.\scripts\Remove-StaleDevices.ps1 -InactiveDays 90 -Action Delete -LogPath ".\logs\cleanup.log"
```

## Project Structure

```
intune-automation-toolkit/
├── scripts/
│   ├── Get-StaleDevices.ps1
│   ├── Get-ComplianceReport.ps1
│   ├── Get-AppDeploymentStatus.ps1
│   ├── Remove-StaleDevices.ps1
│   ├── Get-AutopilotStatus.ps1
│   └── Export-DeviceInventory.ps1
├── docs/
│   └── SETUP.md
├── examples/
│   └── sample-output.md
├── LICENSE
└── README.md
```

## Notes

- All destructive operations (Remove-StaleDevices) support `-WhatIf` and require explicit confirmation
- Scripts are designed to work across multiple tenants — disconnect and reconnect to Graph between tenants
- No client data, credentials, or tenant-specific information is included in this repository
- Tested against Microsoft Graph PowerShell SDK v2.x

## License

MIT License — see [LICENSE](LICENSE) for details.

## Author

Built by an IT professional managing Intune deployments across multiple MSP client environments. These scripts reflect real-world automation patterns for endpoint management at scale.
