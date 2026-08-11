<#
.SYNOPSIS
	Adds deployment configuration to a new project using the shared deployment framework.

.DESCRIPTION
	This script automates the setup of deployment for a new project by:
	- Creating a deployment folder
	- Copying template files from the shared framework
	- Setting up proper .gitignore

.PARAMETER ProjectPath
	Path to the project root (where deployment folder will be created)

.PARAMETER SharedScriptsPath
	Path to shared deployment scripts (auto-detected if not provided)

.EXAMPLE
	.\Add-Deployment.ps1 -ProjectPath "C:\Projects\MyNewProject"

.EXAMPLE
	.\Add-Deployment.ps1 -ProjectPath "." -SharedScriptsPath "C:\DeploymentFramework"
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)]
	[string]$ProjectPath,

	[Parameter(Mandatory=$false)]
	[string]$SharedScriptsPath
)

$ErrorActionPreference = "Stop"

# Resolve project path
$ProjectPath = Resolve-Path $ProjectPath -ErrorAction Stop

Write-Host "`n=== Add Deployment to Project ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectPath" -ForegroundColor White
Write-Host ""

# Auto-detect shared scripts path if not provided
if (-not $SharedScriptsPath) {
	$possiblePaths = @(
		# Environment variable
		$env:SHARED_DEPLOYMENT_SCRIPTS,
		# Sibling to project parent
		(Join-Path (Split-Path $ProjectPath -Parent) "DeploymentScripts"),
		# Standard location
		"C:\Git\ASP.Net\DeploymentScripts",
		# Current directory (running from shared scripts)
		(Join-Path $PSScriptRoot "..")
	)

	foreach ($path in $possiblePaths) {
		if ($path -and (Test-Path (Join-Path $path "Templates\Deploy.ps1"))) {
			$SharedScriptsPath = $path
			Write-Host "Found shared deployment scripts at: $SharedScriptsPath" -ForegroundColor Green
			break
		}
	}

	if (-not $SharedScriptsPath) {
		throw @"
Could not find shared deployment scripts.
Searched locations: $($possiblePaths -join ', ')

Please specify -SharedScriptsPath parameter or set environment variable:
`$env:SHARED_DEPLOYMENT_SCRIPTS = 'C:\Path\To\DeploymentScripts'
"@
	}
}

# Verify shared scripts exist
$templatesPath = Join-Path $SharedScriptsPath "Templates"
if (-not (Test-Path $templatesPath)) {
	throw "Templates folder not found at: $templatesPath"
}

# Create deployment folder
$deploymentPath = Join-Path $ProjectPath "deployment"
if (Test-Path $deploymentPath) {
	Write-Host "⚠ Deployment folder already exists: $deploymentPath" -ForegroundColor Yellow
	$response = Read-Host "Overwrite existing files? (y/n)"
	if ($response -ne 'y') {
		Write-Host "Cancelled by user" -ForegroundColor Yellow
		exit 0
	}
} else {
	New-Item -ItemType Directory -Path $deploymentPath -Force | Out-Null
	Write-Host "✓ Created deployment folder" -ForegroundColor Green
}

# Files to copy
$files = @(
	@{ Source = "Deploy.ps1"; Destination = "Deploy.ps1"; Description = "Deployment launcher script" },
	@{ Source = "deploy-config.template.json"; Destination = "deploy-config.json"; Description = "Configuration file" },
	@{ Source = "README-PROJECT.md"; Destination = "README.md"; Description = "Project documentation" },
	@{ Source = ".gitignore"; Destination = ".gitignore"; Description = "Git ignore file" }
)

# Copy files
Write-Host "`nCopying template files..." -ForegroundColor Cyan
foreach ($file in $files) {
	$source = Join-Path $templatesPath $file.Source
	$dest = Join-Path $deploymentPath $file.Destination

	if (Test-Path $source) {
		Copy-Item $source -Destination $dest -Force
		Write-Host "✓ $($file.Description): $($file.Destination)" -ForegroundColor Green
	} else {
		Write-Host "⚠ Template not found: $($file.Source)" -ForegroundColor Yellow
	}
}

# Try to detect project name and .csproj
Write-Host "`nDetecting project information..." -ForegroundColor Cyan

$projectName = Split-Path $ProjectPath -Leaf
Write-Host "  Project folder: $projectName"

# Find .csproj files
$csprojFiles = Get-ChildItem -Path $ProjectPath -Filter "*.csproj" -Recurse | 
			   Where-Object { $_.FullName -notlike "*\bin\*" -and $_.FullName -notlike "*\obj\*" }

if ($csprojFiles) {
	Write-Host "  Found project files:" -ForegroundColor White
	$csprojFiles | ForEach-Object {
		$relativePath = $_.FullName.Substring($ProjectPath.Length + 1)
		Write-Host "    - $relativePath" -ForegroundColor Gray
	}

	if ($csprojFiles.Count -eq 1) {
		$csprojPath = $csprojFiles[0].FullName.Substring($ProjectPath.Length + 1)
		Write-Host "`n  💡 Suggested projectPath for config: $($csprojPath -replace '\\', '\\')" -ForegroundColor Yellow
	}
}

# Summary
Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Deployment files created in: $deploymentPath" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Edit deployment\deploy-config.json:"
Write-Host "     - Update projectName and projectPath"
Write-Host "     - Configure server names and paths"
Write-Host "     - Set deployment credentials if needed"
Write-Host ""
Write-Host "  2. Prepare target server (run as Administrator on IIS server):"
Write-Host "     $SharedScriptsPath\Core\Setup-DeploymentUser.ps1 ..." -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Test deployment:"
Write-Host "     cd deployment" -ForegroundColor Gray
Write-Host "     .\Deploy.ps1 -Environment development" -ForegroundColor Gray
Write-Host ""
Write-Host "Documentation:" -ForegroundColor Cyan
Write-Host "  Setup Guide: $SharedScriptsPath\Docs\SETUP-GUIDE.md" -ForegroundColor Gray
Write-Host "  Quick Ref:   $SharedScriptsPath\Docs\QUICK-REFERENCE.md" -ForegroundColor Gray
Write-Host ""
