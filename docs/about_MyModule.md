---
Module Name: MyModule
Module Guid: 49c1b8e7-8aae-447c-a22d-b0a0a7f3d36a
Help Version: 0.1.0
Locale: en-US
---

# about_MyModule

## SHORT DESCRIPTION

A PowerShell module template — replace this description with your own.

## LONG DESCRIPTION

This module is scaffolded from **PowerShell-Project-Base**, a production-ready
module template. Replace the content under `src/MyModule/` with your own
cmdlets.

The template enforces a consistent layout:

- **Public/** — one `.ps1` file per exported cmdlet. The build auto-discovers
  these and writes an explicit `FunctionsToExport` list into the distributed
  manifest.
- **Private/** — internal helpers that are not exported. Test them by
  dot-sourcing the file directly.
- **Monolithic build** — `Invoke-Build Build` concatenates all source files
  into a single `.psm1` in `.build/MyModule/` for distribution.

## GETTING STARTED

Install the module from the source:

```powershell
Import-Module ./src/MyModule/MyModule.psd1 -Force
Get-Example -Name 'World'
```

Or install from the PowerShell Gallery once published:

```powershell
Install-PSResource -Name MyModule
```

## CMDLETS

| Cmdlet | Synopsis |
|--------|----------|
| [Get-Example](Get-Example.md) | Returns a greeting message for the specified name. |

## KEYWORDS

- Template
- Module
- Scaffold
