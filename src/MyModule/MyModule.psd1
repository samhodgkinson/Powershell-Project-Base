@{
    RootModule        = 'MyModule.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '49c1b8e7-8aae-447c-a22d-b0a0a7f3d36a'
    Author            = 'Your Name'
    CompanyName       = 'Your Company'
    Copyright         = '(c) 2026. All rights reserved.'
    Description       = 'A PowerShell module — replace this description.'
    PowerShellVersion = '7.2'

    FunctionsToExport = @('Get-Example')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('Template')
            LicenseUri   = 'https://github.com/samhodgkinson/powershell-project-base/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/samhodgkinson/powershell-project-base'
            ReleaseNotes = 'Initial release'
        }
    }
}
