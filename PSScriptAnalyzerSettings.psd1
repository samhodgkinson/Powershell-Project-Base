@{
    Severity     = @('Error', 'Warning', 'Information')
    ExcludeRules = @(
        # Enforcing column-alignment on ALL assignment statements produces excessive
        # noise in practice. Hashtable alignment is handled by the editor formatter.
        'PSAlignAssignmentStatement'

        # UTF-8 BOM is not required by modern PowerShell (7+) or tooling.
        'PSUseBOMForUnicodeEncodedFile'

        # Source manifest intentionally uses FunctionsToExport = @('*') for
        # development. Invoke-Build Build writes the explicit list to .build/
        # without modifying this source file.
        'PSUseToExportFieldsInManifest'
    )
    Rules        = @{
        PSUseConsistentIndentation          = @{
            Enable          = $true
            Kind            = 'space'
            IndentationSize = 4
        }
        PSUseConsistentWhitespace           = @{
            Enable                          = $true
            CheckInnerBrace                 = $true
            CheckOpenBrace                  = $true
            CheckOpenParen                  = $true
            CheckOperator                   = $true
            CheckPipe                       = $true
            CheckPipeForRedundantWhitespace = $true
            CheckSeparator                  = $true
            CheckParameter                  = $false
        }
        PSAvoidUsingCmdletAliases           = @{
            AllowList = @()
        }
    }
}
