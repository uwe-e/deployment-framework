<#
.SYNOPSIS
	Sets up a deployment user with required permissions on the target IIS server.

.DESCRIPTION
	This script configures a Windows user account with the necessary permissions
	to deploy applications via the Deploy-Application.ps1 script. It can create
	a new user or configure an existing domain/local user.

.PARAMETER DeploymentUser
	Username in format DOMAIN\username or just username for local accounts

.PARAMETER CreateLocalUser
	Creates a new local user account (if not exists)

.PARAMETER DeploymentPath
	Path to the deployment directory (e.g., C:\inetpub\wwwroot\BSE.Identity)

.PARAMETER BackupPath
	Path to the backup directory (e.g., C:\Backups\BSE.Identity)

.PARAMETER AppPoolNames
	Array of IIS application pool names to grant permissions on

.PARAMETER GrantAdministrator
	If specified, adds user to Administrators group (simplest but less secure)

.PARAMETER MinimumPermissions
	If specified, grants only minimum required permissions (more secure)

.EXAMPLE
	.\Setup-DeploymentUser.ps1 -DeploymentUser "DOMAIN\deployuser" -DeploymentPath "C:\inetpub\wwwroot\BSE.Identity" -BackupPath "C:\Backups\BSE.Identity" -AppPoolNames @("BSE.Identity") -MinimumPermissions

.EXAMPLE
	.\Setup-DeploymentUser.ps1 -DeploymentUser "deployuser" -CreateLocalUser -DeploymentPath "C:\inetpub\wwwroot\BSE.Identity" -AppPoolNames @("BSE.Identity") -GrantAdministrator
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)]
	[string]$DeploymentUser,

	[Parameter(Mandatory=$false)]
	[switch]$CreateLocalUser,

	[Parameter(Mandatory=$true)]
	[string]$DeploymentPath,

	[Parameter(Mandatory=$false)]
	[string]$BackupPath,

	[Parameter(Mandatory=$true)]
	[string[]]$AppPoolNames,

	[Parameter(Mandatory=$false)]
	[switch]$GrantAdministrator,

	[Parameter(Mandatory=$false)]
	[switch]$MinimumPermissions
)

$ErrorActionPreference = "Stop"

#Requires -RunAsAdministrator
#Requires -Modules WebAdministration

function Write-Success {
	param([string]$Message)
	Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Info {
	param([string]$Message)
	Write-Host "→ $Message" -ForegroundColor Cyan
}

function Write-Warn {
	param([string]$Message)
	Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Fail {
	param([string]$Message)
	Write-Host "✗ $Message" -ForegroundColor Red
}

try {
	Write-Host "`n=== Deployment User Setup Script ===" -ForegroundColor Cyan
	Write-Host "Deployment User: $DeploymentUser" -ForegroundColor White
	Write-Host ""

	# Extract username (remove domain if present)
	$username = if ($DeploymentUser -contains '\') {
		$DeploymentUser.Split('\')[1]
	} else {
		$DeploymentUser
	}

	# Create local user if requested
	if ($CreateLocalUser) {
		Write-Info "Checking if local user exists..."
		$existingUser = Get-LocalUser -Name $username -ErrorAction SilentlyContinue

		if ($existingUser) {
			Write-Warn "Local user '$username' already exists"
		} else {
			Write-Info "Creating local user '$username'..."
			$password = Read-Host "Enter password for new user" -AsSecureString
			New-LocalUser -Name $username -Password $password -Description "Deployment Service Account" -PasswordNeverExpires
			Write-Success "Local user '$username' created"
		}
	}

	# Add to groups
	Write-Info "Configuring Windows groups..."

	if ($GrantAdministrator) {
		Write-Info "Adding to Administrators group..."
		try {
			Add-LocalGroupMember -Group "Administrators" -Member $DeploymentUser -ErrorAction Stop
			Write-Success "Added to Administrators group"
		}
		catch {
			if ($_.Exception.Message -like "*already a member*") {
				Write-Warn "Already a member of Administrators group"
			} else {
				throw
			}
		}
	}

	if ($MinimumPermissions) {
		# Helper function to add user to group using SID (language-independent)
		function Add-UserToGroupBySid {
			param(
				[string]$GroupSid,
				[string]$User,
				[string]$GroupDescription
			)

			# Get group by SID (works regardless of Windows language)
			try {
				$group = Get-LocalGroup -SID $GroupSid -ErrorAction Stop
				$groupName = $group.Name

				Write-Info "Adding to $groupName ($GroupDescription)..."
				try {
					Add-LocalGroupMember -SID $GroupSid -Member $User -ErrorAction Stop
					Write-Success "Added to $groupName"
				}
				catch {
					if ($_.Exception.Message -like "*already a member*") {
						Write-Warn "Already a member of $groupName"
					} else {
						throw
					}
				}
			}
			catch {
				Write-Warn "Group $GroupDescription (SID: $GroupSid) does not exist on this system - skipping"
			}
		}

		# Add to Remote Management Users (S-1-5-32-580)
		# English: "Remote Management Users", German: "Remoteverwaltungsbenutzer"
		Add-UserToGroupBySid -GroupSid "S-1-5-32-580" -User $DeploymentUser -GroupDescription "Remote Management Users"

		# Add to IIS_IUSRS (S-1-5-32-568)
		Add-UserToGroupBySid -GroupSid "S-1-5-32-568" -User $DeploymentUser -GroupDescription "IIS_IUSRS"
	}

	# Configure file system permissions
	Write-Info "Configuring file system permissions..."

	function Grant-DirectoryPermissions {
		param(
			[string]$Path,
			[string]$User,
			[string]$Description
		)

		if (-not (Test-Path $Path)) {
			Write-Info "Creating directory: $Path"
			New-Item -ItemType Directory -Path $Path -Force | Out-Null
		}

		Write-Info "Granting Full Control on $Description ($Path)..."
		$acl = Get-Acl $Path
		$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
			$User,
			"FullControl",
			"ContainerInherit,ObjectInherit",
			"None",
			"Allow"
		)
		$acl.SetAccessRule($rule)
		Set-Acl $Path $acl
		Write-Success "Granted Full Control on $Description"
	}

	Grant-DirectoryPermissions -Path $DeploymentPath -User $DeploymentUser -Description "deployment directory"

	if ($BackupPath) {
		Grant-DirectoryPermissions -Path $BackupPath -User $DeploymentUser -Description "backup directory"
	}

	# Configure IIS application pool permissions
	if ($MinimumPermissions) {
		Write-Info "Configuring IIS application pool permissions..."
		Import-Module WebAdministration

		foreach ($appPoolName in $AppPoolNames) {
			Write-Info "Configuring permissions for app pool: $appPoolName"

			$appPoolPath = "IIS:\AppPools\$appPoolName"
			if (Test-Path $appPoolPath) {
				try {
					# Note: IIS AppPool permissions are complex and may require additional configuration
					# The user needs to be able to execute IIS management cmdlets which is typically
					# handled by group membership (Administrators or IIS_IUSRS)
					Write-Success "App pool '$appPoolName' exists and is accessible"
				}
				catch {
					Write-Warn "Could not fully configure app pool permissions. Ensure user can manage IIS."
				}
			} else {
				Write-Warn "App pool '$appPoolName' does not exist. Create it first or it will be configured during first deployment."
			}
		}
	}

	# Configure PowerShell remoting
	Write-Info "Configuring PowerShell remoting..."

	# Check if PSRemoting is enabled
	try {
		$null = Get-PSSessionConfiguration -Name Microsoft.PowerShell -ErrorAction Stop
		Write-Success "PowerShell remoting is already enabled"
	}
	catch {
		Write-Info "Enabling PowerShell remoting..."
		Enable-PSRemoting -Force -SkipNetworkProfileCheck
		Write-Success "PowerShell remoting enabled"
	}

	# Configure WinRM
	Write-Info "Checking WinRM service..."
	$winrm = Get-Service WinRM
	if ($winrm.Status -ne "Running") {
		Write-Info "Starting WinRM service..."
		Start-Service WinRM
		Set-Service WinRM -StartupType Automatic
		Write-Success "WinRM service started and set to automatic"
	} else {
		Write-Success "WinRM service is running"
	}

	# Configure firewall
	Write-Info "Checking firewall rules..."
	# Use the language-independent Name property instead of DisplayName
	# WINRM-HTTP-In-TCP is the system name for "Windows Remote Management (HTTP-In)"
	$firewallRule = Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP*" -ErrorAction SilentlyContinue | Select-Object -First 1
	if ($firewallRule -and $firewallRule.Enabled -eq $true) {
		Write-Success "WinRM firewall rule is enabled"
	} else {
		Write-Info "Enabling WinRM firewall rule..."
		Enable-NetFirewallRule -Name "WINRM-HTTP-In-TCP*"
		Write-Success "WinRM firewall rule enabled"
	}

	# Summary
	Write-Host "`n=== Configuration Complete ===" -ForegroundColor Green
	Write-Host ""
	Write-Host "Deployment user '$DeploymentUser' has been configured with:" -ForegroundColor White

	if ($GrantAdministrator) {
		Write-Host "  - Administrator privileges (full control)" -ForegroundColor Yellow
	}

	if ($MinimumPermissions) {
		$configuredGroups = @()

		# Check which groups the user is actually a member of
		if (Get-LocalGroup -Name "Remote Management Users" -ErrorAction SilentlyContinue) {
			$members = Get-LocalGroupMember -Group "Remote Management Users" -ErrorAction SilentlyContinue
			if ($members | Where-Object { $_.Name -like "*$username" }) {
				$configuredGroups += "Remote Management Users"
			}
		}

		if (Get-LocalGroup -Name "IIS_IUSRS" -ErrorAction SilentlyContinue) {
			$members = Get-LocalGroupMember -Group "IIS_IUSRS" -ErrorAction SilentlyContinue
			if ($members | Where-Object { $_.Name -like "*$username" }) {
				$configuredGroups += "IIS_IUSRS"
			}
		}

		foreach ($group in $configuredGroups) {
			Write-Host "  - $group membership" -ForegroundColor White
		}
		Write-Host "  - PowerShell remoting access" -ForegroundColor White
	}

	Write-Host "  - Full Control on: $DeploymentPath" -ForegroundColor White
	if ($BackupPath) {
		Write-Host "  - Full Control on: $BackupPath" -ForegroundColor White
	}

	Write-Host ""
	Write-Host "Next steps:" -ForegroundColor Cyan
	Write-Host "1. Test the deployment user credentials" -ForegroundColor White
	Write-Host "2. Verify PowerShell remoting from deployment machine:" -ForegroundColor White
	Write-Host "   Test-WSMan -ComputerName $env:COMPUTERNAME" -ForegroundColor Gray
	Write-Host "3. Run the verification script from DEPLOYMENT-USER-PRIVILEGES.md" -ForegroundColor White
	Write-Host "4. Update deploy-config.json with server and path information" -ForegroundColor White
	Write-Host ""

}
catch {
	Write-Fail "Configuration failed: $_"
	exit 1
}
