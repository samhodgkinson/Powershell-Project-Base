Run PSScriptAnalyzer against the source:

```powershell
Invoke-Build Lint
```

Or directly:

```powershell
Invoke-ScriptAnalyzer -Path ./src -Settings ./PSScriptAnalyzerSettings.psd1 -Recurse -ReportSummary
```
