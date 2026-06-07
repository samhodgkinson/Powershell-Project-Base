# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-06-07

### Added
- Initial module scaffold with `Get-Example` public function
- Pester 5 unit tests with JaCoCo coverage output
- PSScriptAnalyzer configuration with formatting and security rules
- Invoke-Build task script (Lint, Test, Build, Docs, Publish, PublishGitHub, PublishADO)
- platyPS documentation generation
- GitHub Actions CI pipeline (lint, test, security, build) across Ubuntu / Windows / macOS
- GitHub Actions publish pipeline (PSGallery, GitHub Packages, ADO Artifacts) on version tag
- Dev container configuration (PowerShell 7.4)
- VS Code settings, extensions, and launch configurations
