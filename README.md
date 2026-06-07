# PowerShell Module Base

A production-ready PowerShell module template. Clone this repo and replace `src/MyModule/`
with your own code.

The template ships with:

- **PowerShell 7.2+** minimum requirement
- **PSScriptAnalyzer** — linting and style enforcement on save and in CI
- **Pester 5** — test runner with JaCoCo coverage and JUnit XML output
- **platyPS** — markdown documentation generated from comment-based help
- **Invoke-Build** — task orchestration (lint, test, build, docs, publish)
- **GitHub Actions** — CI on every PR + publish pipeline on version tag
- **Dev Container** — VS Code dev container for zero-install development

## Quick Start

### Dev Container (Recommended)

Open in VS Code and select **"Reopen in Container"**. All tools install automatically via
`postCreateCommand`.

### Local

```powershell
# Install build tools once
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module InvokeBuild, Pester, PSScriptAnalyzer, platyPS, Microsoft.PowerShell.PSResourceGet -Scope CurrentUser -Force

# Run all quality gates (lint -> test -> build -> docs)
Invoke-Build
```

## Repository Layout

```
.
├── src/MyModule/                    # Module source (replace MyModule with your name)
│   ├── MyModule.psd1                # Module manifest (version, GUID, exports)
│   ├── MyModule.psm1                # Root loader: dot-sources Public/ and Private/
│   ├── Public/                      # Exported functions — one file per cmdlet
│   │   └── Get-Example.ps1
│   └── Private/                     # Internal helpers — not exported
│       └── Invoke-ExampleHelper.ps1
├── tests/
│   ├── Unit/
│   │   ├── Public/                  # Tests mirroring Public/ (import module)
│   │   └── Private/                 # Tests for Private/ (dot-source directly)
│   └── Integration/
├── docs/                            # platyPS-generated markdown help (auto-generated)
├── .devcontainer/devcontainer.json
├── .github/workflows/
│   ├── ci.yml                       # Lint, test, security, build on every PR
│   └── publish.yml                  # Publish to registries on version tag
├── .vscode/                         # Editor settings, extensions, launch configs
├── .claude/commands/                # Claude Code helper commands
├── Build.ps1                        # Invoke-Build task file
├── PSScriptAnalyzerSettings.psd1
├── .editorconfig
└── CHANGELOG.md
```

## Common Commands

```powershell
# Run all quality gates (default task)
Invoke-Build

# Individual tasks
Invoke-Build Lint    # PSScriptAnalyzer against src/
Invoke-Build Test    # Pester 5 with JaCoCo coverage -> .build/coverage.xml
Invoke-Build Build   # Stage module to .build/MyModule/
Invoke-Build Docs    # platyPS markdown -> docs/
Invoke-Build Clean   # Remove .build/
```

## Renaming the Module

```powershell
# 1. Rename the source directory and module files
Rename-Item src/MyModule src/YourModule
Rename-Item src/YourModule/MyModule.psd1 YourModule.psd1
Rename-Item src/YourModule/MyModule.psm1 YourModule.psm1

# 2. Edit the manifest: update RootModule, GUID (New-Guid), Author, Description
# 3. Edit Build.ps1: change $ModuleName default value to 'YourModule'
# 4. Edit tests: fix the Import-Module path in BeforeAll blocks
```

## Publishing

All publish tasks require the module to be built first (`Invoke-Build Build`).
The `publish.yml` workflow triggers automatically on any `v*.*.*` tag push.

---

### PowerShell Gallery (Public)

Get your API key from [powershellgallery.com/account/apikeys](https://www.powershellgallery.com/account/apikeys).

```powershell
$env:PSGALLERY_API_KEY = 'your-api-key'
Invoke-Build Build
Invoke-Build Publish
```

Required GitHub secret: `PSGALLERY_API_KEY`

---

### GitHub Packages (Public or Private)

NuGet v3 feed — works for public and private repositories.

**Feed URL:** `https://nuget.pkg.github.com/OWNER/index.json`

```powershell
$env:GITHUB_TOKEN = 'ghp_...'
$env:GITHUB_OWNER = 'samhodgkinson'
Invoke-Build Build
Invoke-Build PublishGitHub
```

**Installing from GitHub Packages:**

```powershell
$cred = [pscredential]::new(
    'YOUR_GITHUB_USERNAME',
    (ConvertTo-SecureString 'ghp_...' -AsPlainText -Force)
)
Register-PSResourceRepository -Name 'GitHubPackages' `
    -Uri 'https://nuget.pkg.github.com/OWNER/index.json' `
    -Trusted -Credential $cred
Install-PSResource -Name MyModule -Repository GitHubPackages -Credential $cred
```

Required GitHub secret: `GITHUB_TOKEN` is automatically provided in Actions — no manual secret needed for same-owner repositories.

---

### Azure DevOps Artifacts (Private)

Create a feed in your ADO organisation first, then use the NuGet v3 endpoint.

**Organisation-scoped feed URL:**
```
https://pkgs.dev.azure.com/ORG/_packaging/FEED/nuget/v3/index.json
```

**Project-scoped feed URL:**
```
https://pkgs.dev.azure.com/ORG/PROJECT/_packaging/FEED/nuget/v3/index.json
```

```powershell
$env:ADO_PAT  = 'your-pat-token'
$env:ADO_ORG  = 'your-ado-org'
$env:ADO_FEED = 'your-feed-name'
Invoke-Build Build
Invoke-Build PublishADO
```

**Installing from ADO Artifacts:**

```powershell
$cred = [pscredential]::new(
    'PAT',
    (ConvertTo-SecureString 'your-pat-token' -AsPlainText -Force)
)
Register-PSResourceRepository -Name 'ADOFeed' `
    -Uri 'https://pkgs.dev.azure.com/ORG/_packaging/FEED/nuget/v3/index.json' `
    -Trusted -Credential $cred
Install-PSResource -Name MyModule -Repository ADOFeed -Credential $cred
```

Required GitHub secrets: `ADO_PAT`
Required GitHub variables: `ADO_ORG`, `ADO_FEED`

The `publish-ado` job in `publish.yml` is skipped when `ADO_ORG` is not set, so ADO publishing
is opt-in.

---

## Architecture Notes

- **One file per function** in `Public/` and `Private/`. The root `.psm1` dot-sources all of them.
  Keeps diffs clean and code review focused.
- **`FunctionsToExport`** in the manifest must be kept in sync with filenames in `Public/`.
- **Pester 5 `New-PesterConfiguration`** only — no legacy hashtable syntax.
  `UseBreakpoints = $false` enables the profiler-based coverage runner (much faster on large suites).
- **PSScriptAnalyzer runs all severity levels** via `PSScriptAnalyzerSettings.psd1`; CI fails on
  any finding. Security-specific rules run as a separate CI job.
- **No CodeQL for PowerShell** — GitHub CodeQL does not support PowerShell. PSScriptAnalyzer
  security rules cover SAST in CI.
- **`Publish-PSResource`** (PSResourceGet) is used for all publish targets, replacing the legacy
  `Publish-Module`. GitHub Packages and ADO Artifacts both accept NuGet v3 feeds.

## Testing Conventions

- Test files mirror source structure: `tests/Unit/Public/Get-Example.Tests.ps1`
- Import the module in `BeforeAll`; remove it in `AfterAll`
- Test private functions by dot-sourcing the file directly, not through the module
- Group assertions with `Context` blocks: "When given valid input", "When given invalid input"
- Aim for 100% branch coverage on all public functions

## When Making Changes

1. Add the function to `Public/` or `Private/`
2. Add exported function names to `FunctionsToExport` in the manifest
3. Write tests in `tests/Unit/`
4. Run `Invoke-Build Lint` — fix all PSScriptAnalyzer findings
5. Run `Invoke-Build Test` — all tests must pass
6. Run `Invoke-Build Docs` — regenerate markdown help
7. Bump `ModuleVersion` in the manifest before tagging a release
8. Update `CHANGELOG.md`
9. Tag the release: `git tag v1.0.0 && git push origin v1.0.0`
