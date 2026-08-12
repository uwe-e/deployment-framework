<#
.SYNOPSIS
	Deploys BSE.Identity Blazor application to IIS server.

.DESCRIPTION
	This script builds the project, stops the IIS app pool, deploys the application,
	and starts the app pool. All configuration is managed via deploy-config.json.

.PARAMETER Environment
	Target environment (development, staging, production)

.PARAMETER ConfigPath
	Path to the configuration JSON file (default: deploy-config.json)

.PARAMETER Username
	Username for deployment (e.g., DOMAIN\username). If not provided, uses current user credentials.

.PARAMETER Credential
	PSCredential object for deployment. If not provided and Username is specified, prompts for password.

.PARAMETER SkipBuild
	Skip the build step and deploy existing publish output

.PARAMETER SkipBackup
	Skip backup of existing deployment

.EXAMPLE
	.\Deploy-Application.ps1 -Environment development

.EXAMPLE
	.\Deploy-Application.ps1 -Environment production -Username "DOMAIN\deployuser"

.EXAMPLE
	.\Deploy-Application.ps1 -Environment production -SkipBuild -Credential $cred
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)]
	[ValidateSet("development", "staging", "production")]
	[string]$Environment,

	[Parameter(Mandatory=$false)]
	[string]$ConfigPath = ".\deploy-config.json",

	[Parameter(Mandatory=$false)]
	[string]$Username,

	[Parameter(Mandatory=$false)]
	[System.Management.Automation.PSCredential]$Credential,

	[Parameter(Mandatory=$false)]
	[switch]$SkipBuild,

	[Parameter(Mandatory=$false)]
	[switch]$SkipBackup
)

$ErrorActionPreference = "Stop"
$script:LogFile = ".\deployment-log-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$script:DeploymentCredential = $null

#region Functions

function Get-DeploymentCredential {
	Write-Log "Setting up deployment credentials..."

	if ($script:Credential) {
		Write-Log "Using provided credential object"
		$script:DeploymentCredential = $script:Credential
	}
	elseif ($script:Username) {
		Write-Log "Username provided: $script:Username"
		$script:DeploymentCredential = Get-Credential -UserName $script:Username -Message "Enter password for deployment user"
	}
	else {
		Write-Log "Using current user credentials: $env:USERDOMAIN\$env:USERNAME"
		# No credential object needed; will use current user context
	}

	return $script:DeploymentCredential
}

function Write-Log {
	param(
		[string]$Message,
		[ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
		[string]$Level = "INFO"
	)

	$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$logMessage = "[$timestamp] [$Level] $Message"

	$color = switch ($Level) {
		"INFO"    { "White" }
		"WARNING" { "Yellow" }
		"ERROR"   { "Red" }
		"SUCCESS" { "Green" }
	}

	Write-Host $logMessage -ForegroundColor $color
	Add-Content -Path $script:LogFile -Value $logMessage
}

function Load-Configuration {
	param([string]$ConfigPath)

	Write-Log "Loading configuration from: $ConfigPath"

	if (-not (Test-Path $ConfigPath)) {
		throw "Configuration file not found: $ConfigPath"
	}

	$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

	if (-not $config.environments.$Environment) {
		throw "Environment '$Environment' not found in configuration"
	}

	return $config
}

function Build-Project {
	param(
		[string]$ProjectPath,
		[string]$Configuration,
		[string]$OutputPath,
		[bool]$Clean
	)

	Write-Log "Building project: $ProjectPath"
	Write-Log "Configuration: $Configuration"
	Write-Log "Output path: $OutputPath"

	$solutionRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
	$fullProjectPath = Join-Path $solutionRoot $ProjectPath

	if (-not (Test-Path $fullProjectPath)) {
		throw "Project file not found: $fullProjectPath"
	}

	# Clean if requested
	if ($Clean) {
		Write-Log "Cleaning project..."
		& dotnet clean $fullProjectPath --configuration $Configuration
		if ($LASTEXITCODE -ne 0) {
			throw "Clean failed with exit code $LASTEXITCODE"
		}
	}

	# Build and publish
	Write-Log "Publishing project..."
	& dotnet publish $fullProjectPath --configuration $Configuration --output $OutputPath --no-self-contained

	if ($LASTEXITCODE -ne 0) {
		throw "Build failed with exit code $LASTEXITCODE"
	}

	Write-Log "Build completed successfully" -Level SUCCESS
}

function Stop-RemoteAppPool {
	param(
		[string]$ServerName,
		[string]$AppPoolName,
		[int]$TimeoutSeconds
	)

	Write-Log "Stopping app pool '$AppPoolName' on server '$ServerName'..."

	try {
		$invokeParams = @{
			ComputerName = $ServerName
			ScriptBlock = {
				param($PoolName, $Timeout)

				Import-Module WebAdministration

				$appPool = Get-Item "IIS:\AppPools\$PoolName" -ErrorAction SilentlyContinue
				if (-not $appPool) {
					return @{ Success = $false; Message = "App pool not found: $PoolName" }
				}

				if ($appPool.State -eq "Stopped") {
					return @{ Success = $true; Message = "App pool already stopped" }
				}

				Stop-WebAppPool -Name $PoolName

				# Wait for app pool to stop
				$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
				while ($stopwatch.Elapsed.TotalSeconds -lt $Timeout) {
					$appPool = Get-Item "IIS:\AppPools\$PoolName"
					if ($appPool.State -eq "Stopped") {
						return @{ Success = $true; Message = "App pool stopped successfully" }
					}
					Start-Sleep -Seconds 1
				}

				return @{ Success = $false; Message = "Timeout waiting for app pool to stop" }
			}
			ArgumentList = $AppPoolName, $TimeoutSeconds
		}

		if ($script:DeploymentCredential) {
			$invokeParams.Credential = $script:DeploymentCredential
		}

		$result = Invoke-Command @invokeParams

		if ($result.Success) {
			Write-Log $result.Message -Level SUCCESS
			return $true
		} else {
			Write-Log $result.Message -Level ERROR
			return $false
		}
	}
	catch {
		Write-Log "Error stopping app pool: $_" -Level ERROR
		throw
	}
}

function Start-RemoteAppPool {
	param(
		[string]$ServerName,
		[string]$AppPoolName,
		[int]$TimeoutSeconds
	)

	Write-Log "Starting app pool '$AppPoolName' on server '$ServerName'..."

	try {
		$invokeParams = @{
			ComputerName = $ServerName
			ScriptBlock = {
				param($PoolName, $Timeout)

				Import-Module WebAdministration

				$appPool = Get-Item "IIS:\AppPools\$PoolName" -ErrorAction SilentlyContinue
				if (-not $appPool) {
					return @{ Success = $false; Message = "App pool not found: $PoolName" }
				}

				if ($appPool.State -eq "Started") {
					return @{ Success = $true; Message = "App pool already started" }
				}

				Start-WebAppPool -Name $PoolName

				# Wait for app pool to start
				$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
				while ($stopwatch.Elapsed.TotalSeconds -lt $Timeout) {
					$appPool = Get-Item "IIS:\AppPools\$PoolName"
					if ($appPool.State -eq "Started") {
						return @{ Success = $true; Message = "App pool started successfully" }
					}
					Start-Sleep -Seconds 1
				}

				return @{ Success = $false; Message = "Timeout waiting for app pool to start" }
			}
			ArgumentList = $AppPoolName, $TimeoutSeconds
		}

		if ($script:DeploymentCredential) {
			$invokeParams.Credential = $script:DeploymentCredential
		}

		$result = Invoke-Command @invokeParams

		if ($result.Success) {
			Write-Log $result.Message -Level SUCCESS
			return $true
		} else {
			Write-Log $result.Message -Level ERROR
			return $false
		}
	}
	catch {
		Write-Log "Error starting app pool: $_" -Level ERROR
		throw
	}
}

function Backup-Deployment {
	param(
		[string]$SourcePath,
		[string]$BackupPath
	)

	Write-Log "Creating backup of existing deployment..."

	if (-not (Test-Path $SourcePath)) {
		Write-Log "Source path does not exist, skipping backup" -Level WARNING
		return
	}

	$backupFolder = Join-Path $BackupPath (Get-Date -Format "yyyyMMdd-HHmmss")

	try {
		if (-not (Test-Path $BackupPath)) {
			New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
		}

		Write-Log "Backing up to: $backupFolder"
		Copy-Item -Path $SourcePath -Destination $backupFolder -Recurse -Force

		Write-Log "Backup completed successfully" -Level SUCCESS

		# Clean old backups (keep last 5)
		$backups = Get-ChildItem -Path $BackupPath -Directory | Sort-Object Name -Descending
		if ($backups.Count -gt 5) {
			Write-Log "Removing old backups (keeping last 5)..."
			$backups | Select-Object -Skip 5 | ForEach-Object {
				Write-Log "Removing backup: $($_.Name)"
				Remove-Item -Path $_.FullName -Recurse -Force
			}
		}
	}
	catch {
		Write-Log "Backup failed: $_" -Level ERROR
		throw
	}
}

function Deploy-Files {
	param(
		[string]$SourcePath,
		[string]$DestinationPath
	)

	Write-Log "Deploying files from '$SourcePath' to '$DestinationPath'..."

	if (-not (Test-Path $SourcePath)) {
		throw "Source path not found: $SourcePath"
	}

	try {
		# Create destination if it doesn't exist
		if (-not (Test-Path $DestinationPath)) {
			Write-Log "Creating destination directory: $DestinationPath"
			New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
		}

		# Copy files
		Write-Log "Copying files..."
		$fileCount = 0
		Get-ChildItem -Path $SourcePath -Recurse -File | ForEach-Object {
			$targetPath = $_.FullName.Replace($SourcePath, $DestinationPath)
			$targetDir = Split-Path $targetPath -Parent

			if (-not (Test-Path $targetDir)) {
				New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
			}

			Copy-Item -Path $_.FullName -Destination $targetPath -Force
			$fileCount++
		}

		Write-Log "Deployed $fileCount files successfully" -Level SUCCESS
	}
	catch {
		Write-Log "Deployment failed: $_" -Level ERROR
		throw
	}
}

function Test-ServerConnection {
	param([string]$ServerName)

	Write-Log "Testing connection to server: $ServerName"

	if (Test-Connection -ComputerName $ServerName -Count 1 -Quiet) {
		Write-Log "Server is reachable" -Level SUCCESS
		return $true
	} else {
		Write-Log "Server is not reachable" -Level ERROR
		return $false
	}
}

#endregion

#region Main Script

try {
	Write-Log "=== Starting Deployment ===" -Level INFO
	Write-Log "Environment: $Environment"
	Write-Log "Skip Build: $SkipBuild"
	Write-Log "Skip Backup: $SkipBackup"

	# Setup credentials
	Get-DeploymentCredential | Out-Null

	# Load configuration
	$config = Load-Configuration -ConfigPath $ConfigPath
	$envConfig = $config.environments.$Environment
	$buildSettings = $config.buildSettings
	$iisSettings = $config.iisSettings

	# Test server connection
	if (-not (Test-ServerConnection -ServerName $envConfig.targetServer)) {
		throw "Cannot reach target server: $($envConfig.targetServer)"
	}

	# Build project
	$publishPath = Join-Path $PSScriptRoot "publish-output"

	if (-not $SkipBuild) {
		if (Test-Path $publishPath) {
			Remove-Item -Path $publishPath -Recurse -Force
		}

		Build-Project -ProjectPath $envConfig.projectPath `
					  -Configuration $envConfig.buildConfiguration `
					  -OutputPath $publishPath `
					  -Clean $buildSettings.cleanBeforeBuild
	} else {
		Write-Log "Skipping build as requested" -Level WARNING
		if (-not (Test-Path $publishPath)) {
			throw "Publish output not found at: $publishPath"
		}
	}

	# Stop app pool
	$stopped = Stop-RemoteAppPool -ServerName $envConfig.targetServer `
								   -AppPoolName $envConfig.appPoolName `
								   -TimeoutSeconds $iisSettings.stopTimeout

	if (-not $stopped) {
		throw "Failed to stop app pool"
	}

	# Backup existing deployment
	if ($envConfig.backupEnabled -and -not $SkipBackup) {
		Backup-Deployment -SourcePath $envConfig.deploymentPath `
						 -BackupPath $envConfig.backupPath
	}

	# Deploy files
	Deploy-Files -SourcePath $publishPath `
				 -DestinationPath $envConfig.deploymentPath

	# Start app pool
	$started = Start-RemoteAppPool -ServerName $envConfig.targetServer `
									-AppPoolName $envConfig.appPoolName `
									-TimeoutSeconds $iisSettings.startTimeout

	if (-not $started) {
		throw "Failed to start app pool"
	}

	# Recycle app pool if configured
	if ($iisSettings.recycleAfterDeploy) {
		Write-Log "Recycling app pool..."
		$invokeParams = @{
			ComputerName = $envConfig.targetServer
			ScriptBlock = {
				param($PoolName)
				Import-Module WebAdministration
				Restart-WebAppPool -Name $PoolName
			}
			ArgumentList = $envConfig.appPoolName
		}

		if ($script:DeploymentCredential) {
			$invokeParams.Credential = $script:DeploymentCredential
		}

		Invoke-Command @invokeParams
		Write-Log "App pool recycled" -Level SUCCESS
	}

	Write-Log "=== Deployment Completed Successfully ===" -Level SUCCESS
	Write-Log "Log file: $script:LogFile"

	exit 0
}
catch {
	Write-Log "=== Deployment Failed ===" -Level ERROR
	Write-Log "Error: $_" -Level ERROR
	Write-Log "Log file: $script:LogFile"

	# Attempt to start app pool if it was stopped
	if ($stopped -and -not $started) {
		Write-Log "Attempting to restart app pool after failure..." -Level WARNING
		try {
			Start-RemoteAppPool -ServerName $envConfig.targetServer `
							   -AppPoolName $envConfig.appPoolName `
							   -TimeoutSeconds $iisSettings.startTimeout
		}
		catch {
			Write-Log "Failed to restart app pool: $_" -Level ERROR
		}
	}

	exit 1
}

#endregion
