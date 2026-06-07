Run the full build pipeline (lint -> test -> build -> docs):

```powershell
Invoke-Build
```

Or run individual tasks:

```powershell
Invoke-Build Lint    # PSScriptAnalyzer only
Invoke-Build Test    # Pester tests with JaCoCo coverage
Invoke-Build Build   # Stage module to .build/
Invoke-Build Docs    # Generate markdown help via platyPS
Invoke-Build Clean   # Remove .build/
```
