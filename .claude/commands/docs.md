Generate markdown documentation from comment-based help:

```powershell
# Build the module first, then generate docs
Invoke-Build Build, Docs
```

Or after an initial build, regenerate docs only:

```powershell
Invoke-Build Docs
```

Docs are written to `docs/` as platyPS-formatted markdown.

When adding a new public function:
1. Add the function to `src/MyModule/Public/`
2. Add its name to `FunctionsToExport` in `src/MyModule/MyModule.psd1`
3. Run `Invoke-Build Docs` to generate its help page
