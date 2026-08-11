<#
.SYNOPSIS
	Project-specific deployment launcher for BSE.Identity Blazor application.

.DESCRIPTION
	This is a thin wrapper that calls the shared deployment framework.
	Project-specific configuration is loaded from deploy-config.json in this directory.

.PARAMETER Environment
	Target environment (development, staging, production)

.PARAMETER Username
	Username for deployment (e.g., DOMAIN\username)

.PARAMETER Credential
	PSCredential object for deployment

.PARAMETER SkipBuild
	Skip the build step and deploy existing publish output

.PARAMETER SkipBackup
	Skip backup of existing deployment

.PARAMETER SharedScriptsPath
	Path to shared deployment scripts (default: auto-detect)

.EXAMPLE
	.\Deploy.ps1 -Environment development

.EXAMPLE
	.\Deploy.ps1 -Environment production -Username "DOMAIN\deployuser"
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)]
	[ValidateSet("development", "staging", "production")]
	[string]$Environment,

	[Parameter(Mandatory=$false)]
	[string]$Username,

	[Parameter(Mandatory=$false)]
	[System.Management.Automation.PSCredential]$Credential,

	[Parameter(Mandatory=$false)]
	[switch]$SkipBuild,

	[Parameter(Mandatory=$false)]
	[switch]$SkipBackup,

	[Parameter(Mandatory=$false)]
	[string]$SharedScriptsPath
)

$ErrorActionPreference = "Stop"

# Auto-detect shared scripts path if not provided
if (-not $SharedScriptsPath) {
	# Try common locations
	$possiblePaths = @(
		# Sibling to solution root
		(Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "DeploymentScripts"),
		# Relative to solution root
		(Join-Path (Split-Path $PSScriptRoot -Parent) "DeploymentScripts"),
		# Same location (for backwards compatibility)
		$PSScriptRoot,
		# Environment variable
		$env:SHARED_DEPLOYMENT_SCRIPTS
	)

	foreach ($path in $possiblePaths) {
		if ($path -and (Test-Path (Join-Path $path "Core\Deploy-Application.ps1"))) {
			$SharedScriptsPath = $path
			Write-Host "Found shared deployment scripts at: $SharedScriptsPath" -ForegroundColor Cyan
			break
		}
	}

	if (-not $SharedScriptsPath) {
		throw @"
Could not find shared deployment scripts. 
Searched locations: $($possiblePaths -join ', ')

Please either:
1. Install shared scripts to: $(Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)\DeploymentScripts
2. Set environment variable: `$env:SHARED_DEPLOYMENT_SCRIPTS = 'C:\Path\To\DeploymentScripts'
3. Specify -SharedScriptsPath parameter

See SETUP-GUIDE.md for installation instructions.
"@
	}
}

# Verify shared script exists
$mainScript = Join-Path $SharedScriptsPath "Core\Deploy-Application.ps1"
if (-not (Test-Path $mainScript)) {
	throw "Main deployment script not found at: $mainScript"
}

# Project-specific configuration
$projectConfig = Join-Path $PSScriptRoot "deploy-config.json"
if (-not (Test-Path $projectConfig)) {
	throw "Project configuration not found at: $projectConfig"
}

Write-Host "`n=== BSE.Identity Deployment ===" -ForegroundColor Cyan
Write-Host "Project: BSE.Identity Blazor Client" -ForegroundColor White
Write-Host "Environment: $Environment" -ForegroundColor White
Write-Host "Configuration: $projectConfig" -ForegroundColor Gray
Write-Host "Shared Scripts: $SharedScriptsPath" -ForegroundColor Gray
Write-Host ""

# Build parameters for shared script
$scriptParams = @{
	Environment = $Environment
	ConfigPath = $projectConfig
	SkipBuild = $SkipBuild
	SkipBackup = $SkipBackup
}

if ($Username) {
	$scriptParams.Username = $Username
}

if ($Credential) {
	$scriptParams.Credential = $Credential
}

# Call shared deployment script
try {
	& $mainScript @scriptParams
	exit $LASTEXITCODE
}
catch {
	Write-Host "Deployment failed: $_" -ForegroundColor Red
	exit 1
}
