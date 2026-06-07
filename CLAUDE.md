# CLAUDE.md — AI Context for PowerShell-Project-Base

This file gives Claude Code (and other AI tools) the context needed to work
effectively in this repository.

## Project Overview

A base template for PowerShell modules. Clone this repo and replace `src/MyModule/`
with your own module code.

The template ships with:

- **PowerShell 7.2+** minimum requirement; dev container uses PowerShell 7.4
- **PSScriptAnalyzer** — linting and style enforcement (replaces ad-hoc review); runs on save
- **Pester 5** — test runner with JaCoCo coverage and JUnit XML output
- **platyPS** — markdown documentation from comment-based help
- **Invoke-Build** — task orchestration (lint, test, build, docs, publish)
- **GitHub Actions** — CI (lint, test, security, build) + publish pipeline on version tag
- **Dev Container** — VS Code dev container for zero-install development

## Repository Layout

```
.
├── src/MyModule/
│   ├── MyModule.psd1                # Module manifest (version, GUID, exports)
│   ├── MyModule.psm1                # Root loader: dot-sources Public/ and Private/
│   ├── Public/                      # Exported functions — one file per cmdlet
│   └── Private/                     # Internal helpers — not exported
├── tests/
│   ├── Unit/Public/                 # Public function tests (imports full module)
│   ├── Unit/Private/                # Private function tests (dot-source directly)
│   └── Integration/
├── docs/                            # platyPS markdown (auto-generated — do not hand-edit)
├── .devcontainer/devcontainer.json
├── .github/workflows/
│   ├── ci.yml                       # Lint, test, security, build on every PR
│   └── publish.yml                  # Publish to registries on v*.*.* tag
├── .vscode/                         # Editor settings, extensions, launch configs
├── .claude/commands/                # Claude Code helper commands
├── Build.ps1                        # Invoke-Build task file
└── PSScriptAnalyzerSettings.psd1
```

## Common Commands

All commands run inside the dev container terminal or locally with tools installed.

```powershell
# Install all tools (once per environment)
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module InvokeBuild, Pester, PSScriptAnalyzer, platyPS, Microsoft.PowerShell.PSResourceGet -Scope CurrentUser -Force

# Run all quality gates (default task: Lint -> Test -> Build -> Docs)
Invoke-Build

# Individual tasks
Invoke-Build Lint    # PSScriptAnalyzer against src/
Invoke-Build Test    # Pester 5 + JaCoCo coverage -> .build/coverage.xml
Invoke-Build Build   # Stage module files to .build/MyModule/
Invoke-Build Docs    # platyPS markdown -> docs/
Invoke-Build Clean   # Remove .build/

# Publish (require env vars — see README.md)
Invoke-Build Publish        # -> PowerShell Gallery (PSGALLERY_API_KEY)
Invoke-Build PublishGitHub  # -> GitHub Packages   (GITHUB_TOKEN, GITHUB_OWNER)
Invoke-Build PublishADO     # -> ADO Artifacts      (ADO_PAT, ADO_ORG, ADO_FEED)
```

## Architecture Notes

- **One file per function** in `Public/` and `Private/`. Root `.psm1` dot-sources all of them.
- **`FunctionsToExport`** in `MyModule.psd1` must match the names of files in `Public/`.
- **Pester 5 `New-PesterConfiguration` style only** — no legacy hashtable syntax.
  `UseBreakpoints = $false` enables profiler-based coverage (significantly faster on large suites).
- **PSScriptAnalyzer runs all severity levels** configured in `PSScriptAnalyzerSettings.psd1`.
  CI lint job fails on any finding.
- **No CodeQL** — GitHub CodeQL does not support PowerShell. PSScriptAnalyzer security rules
  cover SAST in the `security` CI job.
- **`Publish-PSResource`** (Microsoft.PowerShell.PSResourceGet) is used for all publish targets.
  This is the modern replacement for `Publish-Module` (PowerShellGet v2).
  GitHub Packages and ADO Artifacts both use NuGet v3 feeds.
- **`docs/` is auto-generated** by platyPS — do not hand-edit the markdown there.
  Edit comment-based help in the `.ps1` source files and re-run `Invoke-Build Docs`.

## Testing Conventions

- Test files mirror `src/` structure: `tests/Unit/Public/Get-Example.Tests.ps1`
- Import the module in `BeforeAll`; remove it in `AfterAll`
- Test private functions by dot-sourcing the `.ps1` file directly
- Group with `Context` blocks: "When given valid input", "When given invalid input"
- Aim for 100% branch coverage on all new public functions

## When Making Changes

1. Add the function to `Public/` (exported) or `Private/` (internal)
2. Update `FunctionsToExport` in `MyModule.psd1` for public functions
3. Write tests in `tests/Unit/`
4. Run `Invoke-Build Lint` — fix all PSScriptAnalyzer findings
5. Run `Invoke-Build Test` — all tests must pass
6. Run `Invoke-Build Docs` — regenerate markdown help
7. Bump `ModuleVersion` in `MyModule.psd1` before tagging a release
8. Update `CHANGELOG.md`
9. Tag and push: `git tag v1.0.0 && git push origin v1.0.0`
