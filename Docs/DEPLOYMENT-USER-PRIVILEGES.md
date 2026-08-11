# Deployment User Privileges and Roles

This document describes the required privileges and roles for the deployment user account on the remote IIS server.

## Overview

The deployment user needs sufficient permissions to:
1. Manage IIS resources (app pools, websites)
2. Access and modify file system locations
3. Execute PowerShell remoting commands
4. Perform administrative tasks on the target server

## Required Windows Groups and Roles

### 1. Administrators (Recommended for Full Control)

**Group**: `BUILTIN\Administrators`

**Why**: Provides full control over IIS, file system, and PowerShell remoting.

**How to add**:
```powershell
# On the target server (as Administrator)
Add-LocalGroupMember -Group "Administrators" -Member "DOMAIN\deployuser"
```

### 2. Alternative: Minimum Permissions (More Secure)

If you don't want to grant full Administrator rights, the deployment user needs the following specific permissions:

#### a) IIS_IUSRS Group
**Group**: `IIS_IUSRS`

**Purpose**: Basic IIS access

```powershell
Add-LocalGroupMember -Group "IIS_IUSRS" -Member "DOMAIN\deployuser"
```

#### b) Remote Management Users
**Group**: `Remote Management Users`

**Purpose**: PowerShell remoting access

```powershell
Add-LocalGroupMember -Group "Remote Management Users" -Member "DOMAIN\deployuser"
```

#### c) Performance Monitor Users (Optional)
**Group**: `Performance Monitor Users`

**Purpose**: Monitor application pool status

```powershell
Add-LocalGroupMember -Group "Performance Monitor Users" -Member "DOMAIN\deployuser"
```

## IIS-Specific Permissions

### Application Pool Management

The deployment user needs permissions to manage IIS app pools.

**PowerShell cmdlets required**:
- `Stop-WebAppPool`
- `Start-WebAppPool`
- `Restart-WebAppPool`
- `Get-WebAppPoolState`

**Grant IIS Management Permissions**:
```powershell
# On the target server (as Administrator)
Import-Module WebAdministration

# Grant management permissions for specific app pool
$appPoolName = "BSE.Identity"
$deployUser = "DOMAIN\deployuser"

# Set permissions on the app pool
$appPoolPath = "IIS:\AppPools\$appPoolName"
$acl = Get-Acl $appPoolPath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
	$deployUser,
	"FullControl",
	"ContainerInherit,ObjectInherit",
	"None",
	"Allow"
)
$acl.SetAccessRule($rule)
Set-Acl $appPoolPath $acl
```

### Alternative: Use IIS Manager Permissions Feature

1. Open IIS Manager
2. Select the server node
3. Double-click "IIS Manager Permissions"
4. Click "Allow User..." 
5. Add the deployment user with "Start/Stop" privileges

## File System Permissions

### Deployment Directory

**Required Permissions**: Full Control

**Directories**:
- Deployment path (e.g., `C:\inetpub\wwwroot\BSE.Identity`)
- Backup path (e.g., `C:\Backups\BSE.Identity`)

**Grant permissions using PowerShell**:
```powershell
# On the target server (as Administrator)
$deploymentPath = "C:\inetpub\wwwroot\BSE.Identity"
$backupPath = "C:\Backups\BSE.Identity"
$deployUser = "DOMAIN\deployuser"

# Function to grant full control
function Grant-FullControl {
	param([string]$Path, [string]$User)

	# Create directory if it doesn't exist
	if (-not (Test-Path $Path)) {
		New-Item -ItemType Directory -Path $Path -Force
	}

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

	Write-Host "Granted Full Control to $User on $Path" -ForegroundColor Green
}

# Grant permissions
Grant-FullControl -Path $deploymentPath -User $deployUser
Grant-FullControl -Path $backupPath -User $deployUser
```

### Network Share Access

For UNC path access (e.g., `\\SERVER\c$\inetpub\wwwroot`):

**Requirements**:
- User must be member of Administrators (for `c$` access)
- OR create a custom share with appropriate permissions

**Create custom share (alternative to c$)**:
```powershell
# On the target server (as Administrator)
$shareName = "Deploy"
$sharePath = "C:\Deploy"
$deployUser = "DOMAIN\deployuser"

# Create directory
New-Item -ItemType Directory -Path $sharePath -Force

# Create SMB share
New-SmbShare -Name $shareName -Path $sharePath -FullAccess $deployUser

# Grant file system permissions
$acl = Get-Acl $sharePath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
	$deployUser,
	"FullControl",
	"ContainerInherit,ObjectInherit",
	"None",
	"Allow"
)
$acl.SetAccessRule($rule)
Set-Acl $sharePath $acl
```

Then update `deploy-config.json`:
```json
{
  "deploymentPath": "\\\\SERVER\\Deploy\\BSE.Identity"
}
```

## PowerShell Remoting Configuration

### Enable PowerShell Remoting on Target Server

```powershell
# On the target server (as Administrator)
Enable-PSRemoting -Force

# Configure WinRM service
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Start WinRM service
Start-Service WinRM
Set-Service WinRM -StartupType Automatic

# Configure firewall
Enable-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)"
```

### Grant PowerShell Remoting Permissions

```powershell
# On the target server (as Administrator)
$deployUser = "DOMAIN\deployuser"

# Grant access to WinRM
Set-PSSessionConfiguration -Name Microsoft.PowerShell -ShowSecurityDescriptorUI

# In the dialog that appears, add the deployment user with "Execute (Invoke)" permission
```

**Alternative command-line approach**:
```powershell
# Get current SDDL
$sddl = (Get-PSSessionConfiguration -Name Microsoft.PowerShell).SecurityDescriptorSddl

# Use PowerShell to add user (replace SID with actual user SID)
$userSid = (New-Object System.Security.Principal.NTAccount($deployUser)).Translate([System.Security.Principal.SecurityIdentifier]).Value

# This requires constructing SDDL - recommend using GUI method above instead
```

## Security Best Practices

### 1. Use a Dedicated Deployment Account

Create a service account specifically for deployments:

```powershell
# On domain controller or server
New-LocalUser -Name "deployuser" -Description "Deployment Service Account" -NoPassword
# Or for domain: New-ADUser -Name "deployuser" -Description "Deployment Service Account"
```

### 2. Password Management

**Options**:

- **Prompt for password** (default): Script prompts when `-Username` is provided
- **Use Credential Manager**: Store credentials securely
  ```powershell
  # Store credential
  $cred = Get-Credential -UserName "DOMAIN\deployuser"
  $cred | Export-Clixml -Path "C:\secure\deployuser.xml"

  # Use in script
  $cred = Import-Clixml -Path "C:\secure\deployuser.xml"
  .\Deploy-Application.ps1 -Environment production -Credential $cred
  ```

- **Use Managed Service Account** (recommended for automation):
  ```powershell
  # Create Group Managed Service Account (gMSA) on domain
  New-ADServiceAccount -Name "deploysvc" -DNSHostName "deploysvc.domain.local" -PrincipalsAllowedToRetrieveManagedPassword "DeploymentServers$"
  ```

### 3. Principle of Least Privilege

Instead of Administrator, use the minimum permissions approach:

1. **Remote Management Users** (for PowerShell remoting)
2. **IIS-specific permissions** (for app pool management)
3. **File system permissions** (only on deployment directories)
4. **Custom share** (instead of administrative share)

### 4. Audit Logging

Enable auditing for deployment activities:

```powershell
# On the target server (as Administrator)
$deploymentPath = "C:\inetpub\wwwroot\BSE.Identity"

# Enable auditing on deployment directory
$acl = Get-Acl $deploymentPath
$auditRule = New-Object System.Security.AccessControl.FileSystemAuditRule(
	"DOMAIN\deployuser",
	"Write,Delete,DeleteSubdirectoriesAndFiles",
	"ContainerInherit,ObjectInherit",
	"None",
	"Success,Failure"
)
$acl.AddAuditRule($auditRule)
Set-Acl $deploymentPath $acl

# Enable object access auditing
auditpol /set /subcategory:"File System" /success:enable /failure:enable
```

### 5. Network Segmentation

Restrict PowerShell remoting to specific source IPs:

```powershell
# On the target server (as Administrator)
$deploymentMachineIP = "192.168.1.100"

# Configure WinRM to only accept from specific IP
New-NetFirewallRule -DisplayName "WinRM Deployment Only" `
	-Direction Inbound `
	-Protocol TCP `
	-LocalPort 5985 `
	-RemoteAddress $deploymentMachineIP `
	-Action Allow
```

## Verification Script

Use this script to verify the deployment user has all required permissions:

```powershell
# Run on target server to verify deployment user permissions
param([string]$DeployUser = "DOMAIN\deployuser")

Write-Host "Verifying permissions for: $DeployUser" -ForegroundColor Cyan

# Check group memberships
Write-Host "`nChecking group memberships..." -ForegroundColor Yellow
$groups = @("Administrators", "Remote Management Users", "IIS_IUSRS")
foreach ($group in $groups) {
	try {
		$members = Get-LocalGroupMember -Group $group -ErrorAction SilentlyContinue
		if ($members.Name -contains $DeployUser) {
			Write-Host "  ✓ Member of $group" -ForegroundColor Green
		} else {
			Write-Host "  ✗ NOT member of $group" -ForegroundColor Red
		}
	}
	catch {
		Write-Host "  ? Could not check $group" -ForegroundColor Yellow
	}
}

# Check file system permissions
Write-Host "`nChecking file system permissions..." -ForegroundColor Yellow
$paths = @("C:\inetpub\wwwroot", "C:\Backups")
foreach ($path in $paths) {
	if (Test-Path $path) {
		$acl = Get-Acl $path
		$hasAccess = $acl.Access | Where-Object { 
			$_.IdentityReference -eq $DeployUser -and 
			$_.FileSystemRights -match "FullControl|Modify"
		}
		if ($hasAccess) {
			Write-Host "  ✓ Has access to $path" -ForegroundColor Green
		} else {
			Write-Host "  ✗ No access to $path" -ForegroundColor Red
		}
	} else {
		Write-Host "  ? Path does not exist: $path" -ForegroundColor Yellow
	}
}

# Check PowerShell remoting
Write-Host "`nChecking PowerShell remoting..." -ForegroundColor Yellow
$psConfig = Get-PSSessionConfiguration -Name Microsoft.PowerShell -ErrorAction SilentlyContinue
if ($psConfig) {
	Write-Host "  ✓ PowerShell remoting configured" -ForegroundColor Green
} else {
	Write-Host "  ✗ PowerShell remoting not configured" -ForegroundColor Red
}

# Check WinRM
Write-Host "`nChecking WinRM service..." -ForegroundColor Yellow
$winrm = Get-Service WinRM
if ($winrm.Status -eq "Running") {
	Write-Host "  ✓ WinRM service running" -ForegroundColor Green
} else {
	Write-Host "  ✗ WinRM service not running" -ForegroundColor Red
}

Write-Host "`nVerification complete!" -ForegroundColor Cyan
```

## Troubleshooting

### Access Denied Errors

**Issue**: "Access is denied" when trying to stop/start app pool

**Solution**: Ensure user is member of Administrators or has IIS management permissions

### WinRM Connection Failures

**Issue**: Cannot connect via PowerShell remoting

**Solutions**:
1. Enable PowerShell remoting: `Enable-PSRemoting -Force`
2. Add to trusted hosts: `Set-Item WSMan:\localhost\Client\TrustedHosts -Value "TARGET-SERVER" -Force`
3. Check firewall rules for port 5985 (HTTP) or 5986 (HTTPS)
4. Verify user is in "Remote Management Users" group

### File Copy Failures

**Issue**: Cannot copy files to UNC path

**Solutions**:
1. Verify network share permissions
2. Check NTFS permissions on target directory
3. For `c$` share, user must be Administrator
4. Consider creating custom share with specific permissions

## Summary

### Recommended Setup for Production

1. **Create dedicated deployment account**
   - Domain service account or local account
   - Strong password or use gMSA

2. **Grant minimum required permissions**
   - Add to "Remote Management Users"
   - Add to "IIS_IUSRS"
   - Grant Full Control on deployment directories only
   - Configure IIS Manager Permissions for specific app pools

3. **Security hardening**
   - Enable auditing on deployment directories
   - Restrict WinRM to specific source IPs
   - Use encrypted credentials or Windows Credential Manager
   - Regularly rotate passwords

4. **Use the deployment script with credentials**:
   ```powershell
   # Option 1: Prompt for password
   .\Deploy-Application.ps1 -Environment production -Username "DOMAIN\deployuser"

   # Option 2: Use stored credential
   $cred = Get-Credential -UserName "DOMAIN\deployuser"
   .\Deploy-Application.ps1 -Environment production -Credential $cred
   ```

This approach balances security with functionality while maintaining audit capability.
