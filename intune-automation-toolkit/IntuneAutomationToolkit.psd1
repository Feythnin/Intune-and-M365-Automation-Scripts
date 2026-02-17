@{
    RootModule        = 'IntuneAutomationToolkit.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a3c7e8f1-4b2d-4e6a-9f0c-1d2e3f4a5b6c'
    Author            = 'IT Professional'
    CompanyName       = 'Community'
    Copyright         = '(c) 2025 MIT License. All rights reserved.'
    Description       = 'PowerShell scripts for managing and automating Microsoft Intune environments at scale. Includes compliance reporting, stale device cleanup, app deployment tracking, configuration profile auditing, patch compliance, BitLocker status, Autopilot management, and proactive remediation monitoring.'

    PowerShellVersion = '7.0'

    RequiredModules   = @(
        'Microsoft.Graph.Authentication'
        'Microsoft.Graph.DeviceManagement'
    )

    FunctionsToExport = @()
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('Intune', 'DeviceManagement', 'Compliance', 'Endpoint', 'Autopilot', 'BitLocker', 'MEM', 'MSP', 'Automation', 'Graph')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ProjectUri   = 'https://github.com/yourusername/microsoft-scripts'
            ReleaseNotes = 'Initial release — 11 Intune management scripts.'
        }
    }
}
