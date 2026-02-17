@{
    RootModule        = 'M365AdminScripts.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b4d8f9a2-5c3e-4f7b-a0d1-2e3f4a5b6c7d'
    Author            = 'IT Professional'
    CompanyName       = 'Community'
    Copyright         = '(c) 2025 MIT License. All rights reserved.'
    Description       = 'PowerShell scripts for managing Microsoft 365 environments. Covers Exchange Online, licensing, Entra ID, Teams governance, security posture, Conditional Access, and user lifecycle management including bulk onboarding and offboarding.'

    PowerShellVersion = '7.0'

    RequiredModules   = @(
        'Microsoft.Graph.Authentication'
        'Microsoft.Graph.Users'
        'Microsoft.Graph.Identity.DirectoryManagement'
        'Microsoft.Graph.Identity.SignIns'
        'Microsoft.Graph.Identity.Governance'
        'Microsoft.Graph.Groups'
        'Microsoft.Graph.Reports'
        'ExchangeOnlineManagement'
    )

    FunctionsToExport = @()
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('M365', 'Exchange', 'EntraID', 'Teams', 'Licensing', 'MFA', 'ConditionalAccess', 'Offboarding', 'MSP', 'Automation', 'Graph')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ProjectUri   = 'https://github.com/yourusername/microsoft-scripts'
            ReleaseNotes = 'Initial release — 14 M365 administration scripts.'
        }
    }
}
