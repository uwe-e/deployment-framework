# Deployment Setup Guide

Complete step-by-step guide to set up and use the deployment automation for BSE.Identity Blazor application.

## Overview

This deployment solution provides:
- ✅ Automated build and deployment to IIS servers
- ✅ Safe app pool management (stop/start)
- ✅ Automatic backups before deployment
- ✅ Support for multiple environments
- ✅ Flexible credential management
- ✅ Comprehensive logging and error handling

## Step-by-Step Setup

### Step 1: Prepare the Target Server

**Run on the target IIS server as Administrator:**

#### Option A: Automated Setup (Recommended)

```powershell
# Navigate to deployment folder
cd C:\Path\To\BSE.Identity\deployment

# Run setup script with minimum permissions (more secure)
.\Setup-DeploymentUser.ps1 -DeploymentUser "DOMAIN\deployuser" `
							-DeploymentPath "C:\inetpub\wwwroot\BSE.Identity" `
							-BackupPath "C:\Backups\BSE.Identity" `
							-AppPoolNames @("BSE.Identity") `
							-MinimumPermissions

# OR with Administrator privileges (simpler but less secure)
.\Setup-DeploymentUser.ps1 -DeploymentUser "DOMAIN\deployuser" `
							-DeploymentPath "C:\inetpub\wwwroot\BSE.Identity" `
							-BackupPath "C:\Backups\BSE.Identity" `
							-AppPoolNames @("BSE.Identity") `
							-GrantAdministrator
```

#### Option B: Manual Setup

Follow the detailed instructions in [DEPLOYMENT-USER-PRIVILEGES.md](DEPLOYMENT-USER-PRIVILEGES.md).

Key requirements:
- PowerShell remoting enabled
- WinRM service running
- Deployment user in "Remote Management Users" group
- Full Control on deployment and backup directories
- IIS management permissions

### Step 2: Verify Target Server Setup

**Run on the target server:**

```powershell
# Test PowerShell remoting
Test-WSMan -ComputerName localhost

# Verify deployment user can manage IIS
Import-Module WebAdministration
Get-WebAppPoolState -Name "BSE.Identity"

# Check file permissions
Test-Path "C:\inetpub\wwwroot\BSE.Identity" -PathType Container
```

### Step 3: Configure Deployment Machine

**Run on the machine that will execute deployments:**

#### Enable PowerShell Remoting to Target Server

```powershell
# Test connection
Test-WSMan -ComputerName YOUR-SERVER-NAME

# If connection fails, add to trusted hosts
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "YOUR-SERVER-NAME" -Force

# Test with credentials
$cred = Get-Credential -UserName "DOMAIN\deployuser"
Invoke-Command -ComputerName YOUR-SERVER-NAME -Credential $cred -ScriptBlock { Get-Date }
```

### Step 4: Configure Deployment Settings

**Edit `deploy-config.json`:**

```json
{
  "environments": {
	"development": {
	  "projectPath": "src\\BSE.Identity.Blazor.Client\\BSE.Identity.Blazor.Client.csproj",
	  "buildConfiguration": "Debug",
	  "targetServer": "DEV-SERVER",
	  "deploymentPath": "\\\\DEV-SERVER\\c$\\inetpub\\wwwroot\\BSE.Identity.Dev",
	  "appPoolName": "BSE.Identity.Dev",
	  "websiteName": "BSE.Identity.Dev",
	  "deploymentUsername": "DOMAIN\\deployuser",
	  "backupEnabled": true,
	  "backupPath": "\\\\DEV-SERVER\\c$\\Backups\\BSE.Identity.Dev"
	},
	"production": {
	  "projectPath": "src\\BSE.Identity.Blazor.Client\\BSE.Identity.Blazor.Client.csproj",
	  "buildConfiguration": "Release",
	  "targetServer": "PROD-SERVER",
	  "deploymentPath": "\\\\PROD-SERVER\\c$\\inetpub\\wwwroot\\BSE.Identity",
	  "appPoolName": "BSE.Identity",
	  "websiteName": "BSE.Identity",
	  "deploymentUsername": "DOMAIN\\proddeploy",
	  "backupEnabled": true,
	  "backupPath": "\\\\PROD-SERVER\\c$\\Backups\\BSE.Identity"
	}
  }
}
```

**Configuration Tips:**
- Use different deployment users for different environments
- Use UNC paths for remote servers: `\\\\SERVER\\c$\\path`
- For local deployments, use local paths: `C:\\inetpub\\wwwroot\\...`
- Set `backupEnabled: false` for development if you don't need backups

### Step 5: First Deployment Test

**Run a test deployment to development:**

```powershell
# Navigate to deployment folder
cd C:\Git\ASP.Net\BSE.Identity\deployment

# Test with current user (if you have admin rights on target)
.\Deploy-Application.ps1 -Environment development

# OR with specific deployment user
.\Deploy-Application.ps1 -Environment development -Username "DOMAIN\deployuser"
```

**What happens during deployment:**
1. ✓ Loads configuration
2. ✓ Sets up credentials (prompts if needed)
3. ✓ Tests server connectivity
4. ✓ Builds the project
5. ✓ Stops the app pool
6. ✓ Creates backup (if enabled)
7. ✓ Copies files to server
8. ✓ Starts the app pool
9. ✓ Creates detailed log file

### Step 6: Review Deployment Logs

Check the log file created in the deployment folder:

```powershell
# View latest log
Get-ChildItem "deployment-log-*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content
```

## Common Deployment Scenarios

### Scenario 1: Regular Production Deployment

```powershell
# With stored credentials
$cred = Import-Clixml -Path "C:\secure\prod-deploy.xml"
.\Deploy-Application.ps1 -Environment production -Credential $cred
```

### Scenario 2: Quick Deploy Without Build

If you just built the solution in Visual Studio:

```powershell
.\Deploy-Application.ps1 -Environment development -SkipBuild
```

### Scenario 3: Deploy Without Backup

For faster deployments in development:

```powershell
.\Deploy-Application.ps1 -Environment development -SkipBackup
```

### Scenario 4: Scheduled/Automated Deployment

Create a scheduled task or use CI/CD:

```powershell
# Store credentials once (run as deployment user)
$cred = Get-Credential -UserName "DOMAIN\deployuser"
$cred | Export-Clixml -Path "C:\secure\deployuser.xml"

# Use in automated script
$cred = Import-Clixml -Path "C:\secure\deployuser.xml"
.\Deploy-Application.ps1 -Environment production -Credential $cred

# Exit code: 0 = success, 1 = failure
if ($LASTEXITCODE -eq 0) {
	Write-Host "Deployment successful"
} else {
	Write-Host "Deployment failed"
	exit 1
}
```

## Credential Management

### For Development

Use your own credentials:
```powershell
.\Deploy-Application.ps1 -Environment development
```

### For Production (Manual Deployment)

Prompt for password each time:
```powershell
.\Deploy-Application.ps1 -Environment production -Username "DOMAIN\proddeploy"
```

### For Automated Deployment

Store credentials securely (encrypted for current user):
```powershell
# One-time setup
$cred = Get-Credential -UserName "DOMAIN\proddeploy"
$cred | Export-Clixml -Path "C:\secure\proddeploy.xml"

# Each deployment
$cred = Import-Clixml -Path "C:\secure\proddeploy.xml"
.\Deploy-Application.ps1 -Environment production -Credential $cred
```

### For CI/CD Pipelines

Use service accounts or managed identities:

**Azure DevOps:**
```yaml
- task: PowerShell@2
  inputs:
	targetType: 'filePath'
	filePath: 'deployment/Deploy-Application.ps1'
	arguments: '-Environment production -Username "$(DeployUsername)"'
  env:
	DEPLOY_PASSWORD: $(DeployPassword)
```

**GitHub Actions:**
```yaml
- name: Deploy to Production
  shell: pwsh
  run: |
	$password = ConvertTo-SecureString "${{ secrets.DEPLOY_PASSWORD }}" -AsPlainText -Force
	$cred = New-Object System.Management.Automation.PSCredential("${{ secrets.DEPLOY_USERNAME }}", $password)
	.\deployment\Deploy-Application.ps1 -Environment production -Credential $cred
```

## Troubleshooting

### Issue: "Access is denied"

**Symptoms:** Cannot connect to remote server or manage IIS

**Solutions:**
1. Verify deployment user has correct permissions
2. Run verification script from DEPLOYMENT-USER-PRIVILEGES.md
3. Check user is in "Remote Management Users" group
4. Ensure PowerShell remoting is enabled: `Enable-PSRemoting -Force`

### Issue: "App pool won't stop"

**Symptoms:** Timeout waiting for app pool to stop

**Solutions:**
1. Increase timeout in deploy-config.json: `"stopTimeout": 60`
2. Check for long-running requests in IIS
3. Manually stop app pool and investigate: `Stop-WebAppPool -Name "YourAppPool"`

### Issue: "Cannot copy files"

**Symptoms:** Access denied copying to deployment path

**Solutions:**
1. Verify file system permissions on target directory
2. Check network share is accessible: `Test-Path "\\SERVER\c$\inetpub\wwwroot"`
3. For administrative shares (c$), user must be Administrator
4. Consider creating custom share with specific permissions

### Issue: "PowerShell remoting fails"

**Symptoms:** Cannot connect via Invoke-Command

**Solutions:**
1. Enable PowerShell remoting on target: `Enable-PSRemoting -Force`
2. Start WinRM service: `Start-Service WinRM`
3. Add to trusted hosts: `Set-Item WSMan:\localhost\Client\TrustedHosts -Value "TARGET" -Force`
4. Check firewall: Port 5985 (HTTP) or 5986 (HTTPS) must be open
5. Test manually: `Test-WSMan -ComputerName TARGET`

### Issue: Deployment Succeeds but Site Doesn't Work

**Symptoms:** Deployment completes but application shows errors

**Solutions:**
1. Check IIS application pool identity and permissions
2. Verify connection strings and appsettings.json
3. Check Event Viewer on target server for ASP.NET errors
4. Review deployment log for any warnings
5. Verify all dependencies were deployed (check publish output)

## Best Practices

### Security

- ✅ Use dedicated service accounts for deployment
- ✅ Grant minimum required permissions
- ✅ Enable auditing on deployment directories
- ✅ Rotate passwords regularly
- ✅ Use Windows Credential Manager or Azure Key Vault for secrets
- ✅ Never commit credentials or config files with passwords to Git

### Operations

- ✅ Always test in development first
- ✅ Review deployment logs after each deployment
- ✅ Keep backups enabled for production
- ✅ Monitor app pool startup after deployment
- ✅ Have a rollback plan (backups are stored with timestamps)
- ✅ Document deployment schedule and procedures

### Configuration

- ✅ Use separate config files for each environment
- ✅ Version control deploy-config.json (without sensitive data)
- ✅ Keep deployment paths consistent across environments
- ✅ Use meaningful app pool and website names
- ✅ Configure appropriate timeouts for your application

## Rollback Procedure

If a deployment causes issues, you can rollback using the automatic backups:

```powershell
# 1. On target server, find the backup
Get-ChildItem "C:\Backups\BSE.Identity" | Sort-Object Name -Descending

# 2. Stop the app pool
Import-Module WebAdministration
Stop-WebAppPool -Name "BSE.Identity"

# 3. Restore files
$backupPath = "C:\Backups\BSE.Identity\20250101-123000"  # Use actual backup folder
$deployPath = "C:\inetpub\wwwroot\BSE.Identity"

Remove-Item $deployPath\* -Recurse -Force
Copy-Item $backupPath\* -Destination $deployPath -Recurse -Force

# 4. Start the app pool
Start-WebAppPool -Name "BSE.Identity"
```

## Support and Documentation

- **Main README**: [README.md](README.md) - Usage and configuration
- **Privileges Guide**: [DEPLOYMENT-USER-PRIVILEGES.md](DEPLOYMENT-USER-PRIVILEGES.md) - Detailed permission requirements
- **Setup Script**: `Setup-DeploymentUser.ps1` - Automate user configuration
- **Deployment Script**: `Deploy-Application.ps1` - Main deployment automation

## Next Steps

1. ✅ Complete Step 1-4 above
2. ✅ Test deployment to development environment
3. ✅ Review logs and verify application works
4. ✅ Document any environment-specific notes
5. ✅ Set up production deployment with proper credentials
6. ✅ Train team members on deployment procedures
7. ✅ Integrate with CI/CD pipeline if needed

---

**Questions or Issues?**
- Review the troubleshooting section above
- Check DEPLOYMENT-USER-PRIVILEGES.md for permission issues
- Review deployment logs for detailed error information
- Consult project repository: https://github.com/uwe-e/BSE.Identity
