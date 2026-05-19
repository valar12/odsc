@{
    RootModule = 'odscex.psm1'
    ModuleVersion = '0.6.2'
    CompatiblePSEditions = @('Core', 'Desktop')
    PowerShellVersion = '5.1'
    RequiredModules = @('MSAL.PS')
    GUID = '2e9994d4-02bc-48b0-bd8b-83825fdd340c'
    Author = 'Manuel Fombuena <mfombuena@innovara.tech>'
    Copyright = '(c) 2024 Innovara Ltd. All rights reserved.'
    Description = 'PowerShell module to manage SharePoint shortcuts in OneDrive for individual users and organization-scale desired-state assignments.'
    PrivateData = @{
        PSData = @{
            Tags = @('onedrive', 'sharepoint', 'shortcuts')
            LicenseUri = 'https://github.com/innovara/odscex/blob/main/LICENSE.md'
            ProjectUri = 'https://github.com/innovara/odscex'
            ExternalModuleDependencies = @('MSAL.PS')
        }
    }
}
