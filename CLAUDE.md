# CLAUDE.md — AI Context for PowerShell-Project-Base

This file gives Claude Code the context needed to work effectively in this repository.

## Project Overview

A production-ready base template for PowerShell modules. Clone and replace
`src/MyModule/` with your own code. The dev container provides a fully
working environment with no local PowerShell setup required.

Toolchain:

| Concern | Tool |
|---------|------|
| Lint & style | PSScriptAnalyzer (all severities) |
| Tests | Pester 5 |
| Coverage | JaCoCo XML (Pester built-in) |
| Security SAST | PSScriptAnalyzer security rules |
| Build / publish | Invoke-Build |
| Docs | platyPS (from comment-based help) |
| Container | mcr.microsoft.com/devcontainers/powershell:7.4 |

## Repository Layout

```
.
├── src/MyModule/
│   ├── MyModule.psd1         manifest (GUID, version, FunctionsToExport='*' in src)
│   ├── MyModule.psm1         dev loader: dot-sources Public/ + Private/
│   ├── Public/               exported cmdlets, one file per function
│   └── Private/              internal helpers, not exported
├── tests/
│   ├── Unit/Public/          tests that import the full module
│   ├── Unit/Private/         tests that dot-source the helper directly
│   └── Integration/
├── docs/
│   ├── about_MyModule.md     hand-maintained module overview
│   └── *.md                  auto-generated per-cmdlet pages (platyPS)
├── .build/                   git-ignored build output
├── .devcontainer/devcontainer.json
├── .github/workflows/
│   ├── ci.yml                lint + test (3 OS) + security + build
│   └── publish.yml           triggered by v*.*.* tag
├── Build.ps1               Invoke-Build task file
└── PSScriptAnalyzerSettings.psd1
```

## Common Commands

```powershell
# Install tools (once per environment)
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module InvokeBuild, Pester, PSScriptAnalyzer, platyPS, Microsoft.PowerShell.PSResourceGet -Scope CurrentUser -Force

# Default task: Lint -> Test -> Build -> Docs
Invoke-Build

# Individual tasks
Invoke-Build Lint       # PSScriptAnalyzer against src/
Invoke-Build Test       # Pester 5 -> .build/coverage.xml + testresults.xml
Invoke-Build Manifest   # auto-update FunctionsToExport in src manifest
Invoke-Build Build      # monolithic .psm1 -> .build/MyModule/
Invoke-Build Docs       # platyPS markdown -> docs/
Invoke-Build Clean      # remove .build/

# Publish (set env vars first — see README.md)
Invoke-Build Publish        # -> PowerShell Gallery
Invoke-Build PublishGitHub  # -> GitHub Packages (NuGet v3)
Invoke-Build PublishADO     # -> ADO Artifacts    (NuGet v3)
```

## How the Build Works

- **Source (`src/`)**: `MyModule.psm1` is a dev loader that dot-sources all
  `.ps1` files at runtime. `FunctionsToExport = '*'` in the manifest exports
  everything — fine for dev/test.
- **Build output (`.build/MyModule/`)**: a monolithic `.psm1` produced by
  concatenating Private/ then Public/ files, with an explicit
  `Export-ModuleMember` call. The manifest gets an exact `FunctionsToExport`
  list auto-discovered from `Public/`. This is what gets published.
- **`Manifest` task** validates the GUID is not the template placeholder and
  updates `FunctionsToExport` in the source manifest.

## Architecture Notes

- **One file per function**. Do not group multiple functions in one file.
- **`FunctionsToExport` is auto-managed**. Never edit it by hand.
- **Pester 5 `New-PesterConfiguration`** only. `UseBreakpoints = $false` for
  faster profiler-based coverage.
- **PSScriptAnalyzer all rules**. `PSScriptAnalyzerSettings.psd1` configures
  formatting rules. CI fails on any finding.
- **No CodeQL** — not supported for PowerShell. PSScriptAnalyzer security
  rules run in the dedicated `security` CI job.
- **`docs/`**: `about_MyModule.md` is hand-maintained. Per-cmdlet `.md` files
  are platyPS-generated — do not edit them directly.

## Testing Conventions

- `tests/Unit/Public/` — import the full module; test exported behaviour only
- `tests/Unit/Private/` — dot-source the `.ps1` file; test internal logic
- `BeforeAll` / `AfterAll` for module lifecycle (not per-test)
- `Context` blocks: "When given valid input", "When given invalid input"
- 100% branch coverage on all new public functions

## When Making Changes

1. Add function to `Public/` or `Private/`
2. Write tests in `tests/Unit/`
3. `Invoke-Build Lint` — fix all PSScriptAnalyzer findings
4. `Invoke-Build Test` — all tests must pass
5. `Invoke-Build Build, Docs` — verify build; regenerate docs
6. Bump `ModuleVersion` in `MyModule.psd1`
7. Update `CHANGELOG.md`
8. Tag the release: `git tag v1.x.x && git push origin v1.x.x`
