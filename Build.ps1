<#
.SYNOPSIS
    Invoke-Build task script for MyModule.
.DESCRIPTION
    Run tasks with: Invoke-Build <TaskName>
    Default task runs: Lint -> Test -> Build -> Docs

    Tasks:
      Clean          Remove .build/ output directory
      Lint           Run PSScriptAnalyzer against src/
      Test           Run Pester 5 tests with JaCoCo coverage output
      Build          Stage module files to .build/MyModule/
      Docs           Generate markdown help from comment-based help via platyPS
      Publish        Publish to PowerShell Gallery  (requires PSGALLERY_API_KEY)
      PublishGitHub  Publish to GitHub Packages     (requires GITHUB_TOKEN, GITHUB_OWNER)
      PublishADO     Publish to ADO Artifacts        (requires ADO_PAT, ADO_ORG, ADO_FEED)
#>

param(
    [string] $ModuleName = 'MyModule',
    [string] $SrcPath    = "$PSScriptRoot/src/$ModuleName",
    [string] $BuildPath  = "$PSScriptRoot/.build",
    [string] $OutputPath = "$PSScriptRoot/.build/$ModuleName",
    [string] $TestsPath  = "$PSScriptRoot/tests",
    [string] $DocsPath   = "$PSScriptRoot/docs"
)

task Clean {
    if (Test-Path $BuildPath) {
        Remove-Item $BuildPath -Recurse -Force
    }
    $null = New-Item $OutputPath -ItemType Directory -Force
    Write-Build Green 'Clean complete.'
}

task Lint {
    $settings = "$PSScriptRoot/PSScriptAnalyzerSettings.psd1"
    $results  = Invoke-ScriptAnalyzer -Path $SrcPath -Settings $settings -Recurse -ReportSummary
    if ($results) {
        $results | Format-Table RuleName, Severity, ScriptName, Line, Message -AutoSize
        throw "PSScriptAnalyzer found $($results.Count) issue(s). Fix them before proceeding."
    }
    Write-Build Green 'Lint passed.'
}

task Test {
    $null = New-Item $BuildPath -ItemType Directory -Force
    $config = New-PesterConfiguration
    $config.Run.Path         = $TestsPath
    $config.Run.Exit         = $true
    $config.Output.Verbosity = 'Detailed'

    $config.CodeCoverage.Enabled        = $true
    $config.CodeCoverage.Path           = $SrcPath
    $config.CodeCoverage.UseBreakpoints = $false
    $config.CodeCoverage.OutputFormat   = 'JaCoCo'
    $config.CodeCoverage.OutputPath     = "$BuildPath/coverage.xml"

    $config.TestResult.Enabled      = $true
    $config.TestResult.OutputFormat = 'JUnitXml'
    $config.TestResult.OutputPath   = "$BuildPath/testresults.xml"

    Invoke-Pester -Configuration $config
}

task Build Clean, {
    Copy-Item -Path $SrcPath -Destination $OutputPath -Recurse -Force
    Write-Build Green "Build output staged at $OutputPath"
}

task Docs {
    assert (Test-Path "$OutputPath/$ModuleName.psd1") "Run 'Invoke-Build Build' before generating docs."
    $null = New-Item $DocsPath -ItemType Directory -Force
    Import-Module -Name "$OutputPath/$ModuleName.psd1" -Force -ErrorAction Stop
    $commands = Get-Command -Module $ModuleName
    foreach ($cmd in $commands) {
        New-MarkdownHelp -Command $cmd.Name -OutputFolder $DocsPath -Force | Out-Null
    }
    Remove-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue
    Write-Build Green "Docs generated in $DocsPath"
}

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
    assert $env:ADO_PAT  'Set ADO_PAT (Personal Access Token) before publishing to ADO.'
    assert $env:ADO_ORG  'Set ADO_ORG (Azure DevOps organisation) before publishing.'
    assert $env:ADO_FEED 'Set ADO_FEED (Artifacts feed name) before publishing.'
    $uri  = "https://pkgs.dev.azure.com/$env:ADO_ORG/_packaging/$env:ADO_FEED/nuget/v3/index.json"
    $cred = [pscredential]::new('PAT', (ConvertTo-SecureString $env:ADO_PAT -AsPlainText -Force))
    Register-PSResourceRepository -Name 'ADOFeed' -Uri $uri -Trusted -Credential $cred -ErrorAction SilentlyContinue
    Publish-PSResource -Path $OutputPath -Repository 'ADOFeed' -Credential $cred
    Write-Build Green 'Published to Azure DevOps Artifacts.'
}

task . Lint, Test, Build, Docs
