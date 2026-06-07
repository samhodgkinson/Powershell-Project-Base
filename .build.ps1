<#
.SYNOPSIS
    Invoke-Build task script for MyModule.
.DESCRIPTION
    Run tasks with: Invoke-Build [TaskName]
    Omit TaskName to run the default task: Lint -> Test -> Build -> Docs

    Tasks:
      Clean          Remove .build/ output directory
      Lint           Run PSScriptAnalyzer against src/
      Test           Run Pester 5 tests with JaCoCo + JUnit output
      Manifest       Sync FunctionsToExport in source PSD1 from Public/ (dev tool;
                     preserves comments; not called automatically by Build)
      Build          Concatenate source into a monolithic .psm1, update the built
                     manifest, validate it, and stage to .build/MyModule/
      Docs           Generate per-cmdlet markdown via platyPS and compile to MAML
      Publish        Publish to PowerShell Gallery  (PSGALLERY_API_KEY)
      PublishGitHub  Publish to GitHub Packages     (GITHUB_TOKEN, GITHUB_OWNER)
      PublishADO     Publish to ADO Artifacts        (ADO_PAT, ADO_ORG, ADO_FEED)
#>

param(
    [string] $ModuleName   = 'MyModule',
    [string] $SrcPath      = "$PSScriptRoot/src/$ModuleName",
    [string] $BuildPath    = "$PSScriptRoot/.build",
    [string] $OutputPath   = "$PSScriptRoot/.build/$ModuleName",
    [string] $TestsPath    = "$PSScriptRoot/tests",
    [string] $DocsPath     = "$PSScriptRoot/docs",
    [string] $TemplateGuid = '49c1b8e7-8aae-447c-a22d-b0a0a7f3d36a'
)

# ---------------------------------------------------------------------------
task Clean {
    if (Test-Path $BuildPath) { Remove-Item $BuildPath -Recurse -Force }
    $null = New-Item $OutputPath -ItemType Directory -Force
    Write-Build Green 'Clean complete.'
}

# ---------------------------------------------------------------------------
task Lint {
    $settings = "$PSScriptRoot/PSScriptAnalyzerSettings.psd1"
    $results  = Invoke-ScriptAnalyzer -Path $SrcPath -Settings $settings -Recurse -ReportSummary
    if ($results) {
        $results | Format-Table RuleName, Severity, ScriptName, Line, Message -AutoSize
        throw "PSScriptAnalyzer found $($results.Count) issue(s)."
    }
    Write-Build Green 'Lint passed.'
}

# ---------------------------------------------------------------------------
task Test {
    $null = New-Item $BuildPath -ItemType Directory -Force
    $config = New-PesterConfiguration
    $config.Run.Path         = $TestsPath
    $config.Run.Exit         = $true
    $config.Output.Verbosity = 'Detailed'

    $config.CodeCoverage.Enabled              = $true
    $config.CodeCoverage.Path                 = $SrcPath
    $config.CodeCoverage.UseBreakpoints       = $false   # Profiler mode: faster on large suites
    $config.CodeCoverage.OutputFormat         = 'JaCoCo'
    $config.CodeCoverage.OutputPath           = "$BuildPath/coverage.xml"
    $config.CodeCoverage.CoveragePercentTarget = 80      # Fail if coverage drops below 80%

    $config.TestResult.Enabled      = $true
    $config.TestResult.OutputFormat = 'JUnitXml'
    $config.TestResult.OutputPath   = "$BuildPath/testresults.xml"

    Invoke-Pester -Configuration $config
}

# ---------------------------------------------------------------------------
# Manifest: developer tool — syncs FunctionsToExport in the SOURCE manifest from
# Public/ contents. Uses regex replacement to preserve comments. Not called by
# Build (Build never touches source files).
task Manifest {
    $manifestPath = "$SrcPath/$ModuleName.psd1"
    $data         = Import-PowerShellDataFile -Path $manifestPath

    if ($data.GUID -eq $TemplateGuid) {
        Write-Build Yellow @"
WARNING: $ModuleName.psd1 still uses the template GUID.
Run (New-Guid).Guid in PowerShell and paste the result into the GUID field.

"@
    }

    $functions = @(
        Get-ChildItem -Path "$SrcPath/Public/*.ps1" -ErrorAction SilentlyContinue
    ).BaseName | Sort-Object

    $joined  = ($functions | ForEach-Object { "'$_'" }) -join ', '
    $newLine = "FunctionsToExport = @($joined)"
    $content = Get-Content -Path $manifestPath -Raw
    $content = [regex]::Replace($content, '(?s)FunctionsToExport\s*=\s*@\(.*?\)', $newLine)
    Set-Content -Path $manifestPath -Value $content.TrimEnd() -Encoding utf8NoBOM

    Write-Build Green "Source manifest updated: $($functions.Count) function(s) ($($functions -join ', '))."
}

# ---------------------------------------------------------------------------
task Build Clean, {
    # Auto-discover public functions — never reads or writes the source manifest
    $functions = @(Get-ChildItem "$SrcPath/Public/*.ps1" -ErrorAction SilentlyContinue).BaseName | Sort-Object

    # Concatenate Private/ then Public/ into a single .psm1 for distribution
    $sb = [System.Text.StringBuilder]::new()
    foreach ($file in Get-ChildItem "$SrcPath/Private/*.ps1" -ErrorAction SilentlyContinue) {
        $null = $sb.AppendLine((Get-Content -Path $file.FullName -Raw).TrimEnd())
        $null = $sb.AppendLine()
    }
    foreach ($file in Get-ChildItem "$SrcPath/Public/*.ps1" -ErrorAction SilentlyContinue) {
        $null = $sb.AppendLine((Get-Content -Path $file.FullName -Raw).TrimEnd())
        $null = $sb.AppendLine()
    }
    $joined = ($functions | ForEach-Object { "'$_'" }) -join ', '
    $null   = $sb.AppendLine("Export-ModuleMember -Function @($joined)")
    Set-Content -Path "$OutputPath/$ModuleName.psm1" -Value $sb.ToString() -Encoding utf8NoBOM

    # Copy manifest to build output and patch FunctionsToExport (source untouched)
    Copy-Item -Path "$SrcPath/$ModuleName.psd1" -Destination $OutputPath
    $builtManifest    = "$OutputPath/$ModuleName.psd1"
    $manifestContent  = Get-Content -Path $builtManifest -Raw
    $newExports       = "FunctionsToExport = @($joined)"
    $manifestContent  = [regex]::Replace($manifestContent, '(?s)FunctionsToExport\s*=\s*@\(.*?\)', $newExports)
    Set-Content -Path $builtManifest -Value $manifestContent.TrimEnd() -Encoding utf8NoBOM

    # Validate the built manifest before anything tries to publish it
    $validated = Test-ModuleManifest -Path $builtManifest
    Write-Build Green "Build staged at $OutputPath — $($validated.Name) v$($validated.Version), $($functions.Count) function(s)."
}

# ---------------------------------------------------------------------------
task Docs {
    assert (Test-Path "$OutputPath/$ModuleName.psd1") "Run 'Invoke-Build Build' before Docs."
    $null = New-Item $DocsPath -ItemType Directory -Force

    Import-Module -Name "$OutputPath/$ModuleName.psd1" -Force -ErrorAction Stop

    # Generate / update one markdown file per exported cmdlet
    $commands = Get-Command -Module $ModuleName
    foreach ($cmd in $commands) {
        $docFile = "$DocsPath/$($cmd.Name).md"
        if (Test-Path $docFile) {
            Update-MarkdownHelp -Path $docFile -Force | Out-Null
        } else {
            New-MarkdownHelp -Command $cmd.Name -OutputFolder $DocsPath -Force | Out-Null
        }
    }

    # Compile markdown to MAML XML so Get-Help works for the installed module
    $helpPath = "$OutputPath/en-US"
    $null = New-Item $helpPath -ItemType Directory -Force
    New-ExternalHelp -Path $DocsPath -OutputPath $helpPath -Force | Out-Null

    Remove-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue
    Write-Build Green "Docs: $($commands.Count) cmdlet(s) -> $DocsPath (markdown) + $helpPath (MAML)."
}

# ---------------------------------------------------------------------------
task Publish {
    assert $env:PSGALLERY_API_KEY 'Set PSGALLERY_API_KEY before publishing to PSGallery.'
    Publish-PSResource -Path $OutputPath -Repository PSGallery -ApiKey $env:PSGALLERY_API_KEY
    Write-Build Green 'Published to PowerShell Gallery.'
}

task PublishGitHub {
    assert $env:GITHUB_TOKEN 'Set GITHUB_TOKEN before publishing to GitHub Packages.'
    assert $env:GITHUB_OWNER 'Set GITHUB_OWNER (username or org) before publishing.'
    $uri  = "https://nuget.pkg.github.com/$env:GITHUB_OWNER/index.json"
    $cred = [pscredential]::new(
        $env:GITHUB_OWNER,
        (ConvertTo-SecureString $env:GITHUB_TOKEN -AsPlainText -Force)
    )
    Register-PSResourceRepository -Name 'GitHubPackages' -Uri $uri -Trusted -Credential $cred -ErrorAction SilentlyContinue
    Publish-PSResource -Path $OutputPath -Repository 'GitHubPackages' -ApiKey $env:GITHUB_TOKEN
    Write-Build Green 'Published to GitHub Packages.'
}

task PublishADO {
    assert $env:ADO_PAT  'Set ADO_PAT before publishing to ADO Artifacts.'
    assert $env:ADO_ORG  'Set ADO_ORG (Azure DevOps organisation) before publishing.'
    assert $env:ADO_FEED 'Set ADO_FEED (Artifacts feed name) before publishing.'
    $uri  = "https://pkgs.dev.azure.com/$env:ADO_ORG/_packaging/$env:ADO_FEED/nuget/v3/index.json"
    $cred = [pscredential]::new('PAT', (ConvertTo-SecureString $env:ADO_PAT -AsPlainText -Force))
    Register-PSResourceRepository -Name 'ADOFeed' -Uri $uri -Trusted -Credential $cred -ErrorAction SilentlyContinue
    Publish-PSResource -Path $OutputPath -Repository 'ADOFeed' -Credential $cred
    Write-Build Green 'Published to Azure DevOps Artifacts.'
}

# Default task
task . Lint, Test, Build, Docs
