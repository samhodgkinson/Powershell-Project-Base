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
      Manifest       Auto-discover Public/ functions, update FunctionsToExport,
                     validate GUID is not the template placeholder
      Build          Create a monolithic .psm1 and stage to .build/MyModule/
      Docs           Generate per-cmdlet markdown via platyPS; create about_ doc
      Publish        Publish to PowerShell Gallery  (PSGALLERY_API_KEY)
      PublishGitHub  Publish to GitHub Packages     (GITHUB_TOKEN, GITHUB_OWNER)
      PublishADO     Publish to ADO Artifacts        (ADO_PAT, ADO_ORG, ADO_FEED)
#>

param(
    [string] $ModuleName    = 'MyModule',
    [string] $SrcPath       = "$PSScriptRoot/src/$ModuleName",
    [string] $BuildPath     = "$PSScriptRoot/.build",
    [string] $OutputPath    = "$PSScriptRoot/.build/$ModuleName",
    [string] $TestsPath     = "$PSScriptRoot/tests",
    [string] $DocsPath      = "$PSScriptRoot/docs",
    [string] $TemplateGuid  = '49c1b8e7-8aae-447c-a22d-b0a0a7f3d36a'
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
    $config.Run.Path          = $TestsPath
    $config.Run.Exit          = $true
    $config.Output.Verbosity  = 'Detailed'

    $config.CodeCoverage.Enabled        = $true
    $config.CodeCoverage.Path           = $SrcPath
    $config.CodeCoverage.UseBreakpoints = $false   # Profiler mode: faster on large suites
    $config.CodeCoverage.OutputFormat   = 'JaCoCo'
    $config.CodeCoverage.OutputPath     = "$BuildPath/coverage.xml"

    $config.TestResult.Enabled      = $true
    $config.TestResult.OutputFormat = 'JUnitXml'
    $config.TestResult.OutputPath   = "$BuildPath/testresults.xml"

    Invoke-Pester -Configuration $config
}

# ---------------------------------------------------------------------------
task Manifest {
    $manifestPath = "$SrcPath/$ModuleName.psd1"
    $data         = Import-PowerShellDataFile -Path $manifestPath

    # Warn if still using the template GUID so the author knows to replace it
    if ($data.GUID -eq $TemplateGuid) {
        Write-Build Yellow @"
WARNING: MyModule.psd1 still uses the template GUID.
Run the following and paste the result into the manifest:

    (New-Guid).Guid

"@
    }

    # Auto-discover exported functions from Public/
    $functions = @(
        Get-ChildItem -Path "$SrcPath/Public/*.ps1" -ErrorAction SilentlyContinue
    ).BaseName | Sort-Object

    Update-ModuleManifest -Path $manifestPath -FunctionsToExport $functions
    Write-Build Green "Manifest updated: $($functions.Count) function(s) exported ($($functions -join ', '))."
}

# ---------------------------------------------------------------------------
task Build Clean, Manifest, {
    $functions  = @(Get-ChildItem "$SrcPath/Public/*.ps1"  -ErrorAction SilentlyContinue).BaseName | Sort-Object
    $sb         = [System.Text.StringBuilder]::new()

    # Concatenate private helpers first, then public functions
    foreach ($file in Get-ChildItem "$SrcPath/Private/*.ps1" -ErrorAction SilentlyContinue) {
        $null = $sb.AppendLine((Get-Content -Path $file.FullName -Raw))
    }
    foreach ($file in Get-ChildItem "$SrcPath/Public/*.ps1" -ErrorAction SilentlyContinue) {
        $null = $sb.AppendLine((Get-Content -Path $file.FullName -Raw))
    }

    # Explicit export list in monolithic module — safer than Export-ModuleMember -Function *
    $exportList = ($functions | ForEach-Object { "'$_'" }) -join ', '
    $null = $sb.AppendLine("Export-ModuleMember -Function @($exportList)")

    Set-Content -Path "$OutputPath/$ModuleName.psm1" -Value $sb.ToString() -Encoding utf8NoBOM

    # Copy manifest and write explicit FunctionsToExport into the build copy
    Copy-Item -Path "$SrcPath/$ModuleName.psd1" -Destination $OutputPath
    Update-ModuleManifest -Path "$OutputPath/$ModuleName.psd1" -FunctionsToExport $functions

    Write-Build Green "Build staged at $OutputPath ($($functions.Count) public function(s))."
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

    Remove-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue
    Write-Build Green "Docs generated in $DocsPath ($($commands.Count) cmdlet(s))."
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
