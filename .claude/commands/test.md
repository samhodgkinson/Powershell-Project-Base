Run Pester 5 tests with code coverage:

```powershell
Invoke-Build Test
```

Or directly:

```powershell
$config = New-PesterConfiguration
$config.Run.Path                    = './tests'
$config.Run.Exit                    = $true
$config.Output.Verbosity            = 'Detailed'
$config.CodeCoverage.Enabled        = $true
$config.CodeCoverage.Path           = './src'
$config.CodeCoverage.UseBreakpoints = $false
$config.CodeCoverage.OutputFormat   = 'JaCoCo'
$config.CodeCoverage.OutputPath     = '.build/coverage.xml'
Invoke-Pester -Configuration $config
```

Coverage report is written to `.build/coverage.xml` (JaCoCo format, compatible with Codecov).
Test results are written to `.build/testresults.xml` (JUnit XML).
