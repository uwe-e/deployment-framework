# Deployment Scripts

This directory contains deployment automation scripts for the BSE.Identity Blazor application.

## 📚 Documentation

- **[QUICK-REFERENCE.md](QUICK-REFERENCE.md)** - Quick command reference and cheat sheet
- **[SETUP-GUIDE.md](SETUP-GUIDE.md)** - Complete step-by-step setup instructions
- **[DEPLOYMENT-USER-PRIVILEGES.md](DEPLOYMENT-USER-PRIVILEGES.md)** - Detailed permission requirements
- **[README.md](README.md)** - This file (comprehensive documentation)

## 🚀 Quick Start

1. **On the target server** (as Administrator):
   ```powershell
   # Automated setup (recommended)
   .\Setup-DeploymentUser.ps1 -DeploymentUser "DOMAIN\deployuser" `
                               -DeploymentPath "C:\inetpub\wwwroot\BSE.Identity" `
                               -BackupPath "C:\Backups\BSE.Identity" `
                               -AppPoolNames @("BSE.Identity") `
                               -MinimumPermissions
   ```

2. **On the deployment machine**:
   - Edit `deploy-config.json` with your server details
   - Run deployment:
     ```powershell
     .\Deploy-Application.ps1 -Environment production -Username "DOMAIN\deployuser"
     ```

## Files in This Directory

- **Deploy-Application.ps1**: Main deployment script
- **deploy-config.json**: Configuration file for all environments
- **Setup-DeploymentUser.ps1**: Helper script to configure deployment user on target server
- **DEPLOYMENT-USER-PRIVILEGES.md**: Detailed documentation on required permissions
- **README.md**: This file

## Prerequisites

1. **PowerShell Remoting**: Must be enabled on target servers
   ```powershell
   # Run on target server as Administrator
   Enable-PSRemoting -Force
   ```

2. **IIS Management Module**: Must be installed on target servers
   ```powershell
   # Run on target server as Administrator
   Install-WindowsFeature -Name Web-Server -IncludeManagementTools
   ```

3. **Deployment User Setup**: Configure a user with proper permissions
   - **Automated**: Use `Setup-DeploymentUser.ps1` (recommended)
   - **Manual**: Follow [DEPLOYMENT-USER-PRIVILEGES.md](DEPLOYMENT-USER-PRIVILEGES.md)

4. **Network Permissions**: 
   - Ensure the deployment machine can access the target server via network shares
   - Firewall rules must allow WinRM (port 5985 for HTTP, 5986 for HTTPS)

5. **.NET SDK**: Must be installed on the build machine
   ```powershell
   # Verify .NET SDK installation
   dotnet --version
   ```

## Configuration

Edit `deploy-config.json` to configure your deployment environments:

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
	  "backupEnabled": true,
	  "backupPath": "\\\\DEV-SERVER\\c$\\Backups\\BSE.Identity.Dev"
	}
  }
}
```

### Configuration Options

- **projectPath**: Path to the .csproj file (relative to solution root)
- **buildConfiguration**: Build configuration (Debug/Release)
- **targetServer**: Target server hostname or IP
- **deploymentPath**: UNC path to deployment location
- **appPoolName**: Name of the IIS Application Pool
- **websiteName**: Name of the IIS Website
- **deploymentUsername**: (Optional) Default username for deployment. Can be overridden via script parameter.
- **backupEnabled**: Whether to backup before deployment
- **backupPath**: Path for backup storage

**Note**: The `deploymentUsername` in config is optional. If specified, it will be used as default when script parameter is not provided.

## Usage

### Basic Deployment

Deploy to development environment (uses current user credentials):
```powershell
cd deployment
.\Deploy-Application.ps1 -Environment development
```

Deploy to production (uses current user credentials):
```powershell
.\Deploy-Application.ps1 -Environment production
```

### Deployment with Specific User Credentials

Deploy using a specific domain user (will prompt for password):
```powershell
.\Deploy-Application.ps1 -Environment production -Username "DOMAIN\deployuser"
```

Deploy using stored credentials:
```powershell
$cred = Get-Credential -UserName "DOMAIN\deployuser"
.\Deploy-Application.ps1 -Environment production -Credential $cred
```

Store and reuse credentials:
```powershell
# Store credentials securely (one-time)
$cred = Get-Credential -UserName "DOMAIN\deployuser"
$cred | Export-Clixml -Path "C:\secure\deployuser.xml"

# Use stored credentials
$cred = Import-Clixml -Path "C:\secure\deployuser.xml"
.\Deploy-Application.ps1 -Environment production -Credential $cred
```

### Advanced Options

Skip the build step (use existing publish output):
```powershell
.\Deploy-Application.ps1 -Environment production -SkipBuild
```

Skip backup:
```powershell
.\Deploy-Application.ps1 -Environment production -SkipBackup
```

Use custom configuration file:
```powershell
.\Deploy-Application.ps1 -Environment production -ConfigPath "C:\custom-config.json"
```

Combine multiple options:
```powershell
.\Deploy-Application.ps1 -Environment production -Username "DOMAIN\deployuser" -SkipBackup
```

## Deployment Process

The script performs the following steps:

1. **Load Configuration**: Reads settings from JSON config file
2. **Server Connection Test**: Verifies target server is reachable
3. **Build Project**: Compiles and publishes the application (unless skipped)
4. **Stop App Pool**: Gracefully stops the IIS Application Pool
5. **Backup**: Creates timestamped backup of existing deployment
6. **Deploy Files**: Copies new files to deployment location
7. **Start App Pool**: Starts the IIS Application Pool
8. **Recycle**: Optionally recycles the app pool

## Logging

Each deployment creates a log file in the deployment directory:
- Format: `deployment-log-yyyyMMdd-HHmmss.txt`
- Contains timestamped entries for all operations
- Includes success, warning, and error messages

## Backup Management

- Backups are stored with timestamp: `yyyyMMdd-HHmmss`
- Automatically keeps the last 5 backups
- Can be disabled per environment or via `-SkipBackup` parameter

## Troubleshooting

### Cannot connect to remote server
```powershell
# Test WinRM connection
Test-WSMan -ComputerName YOUR-SERVER

# Configure TrustedHosts if needed (on deployment machine)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "YOUR-SERVER" -Force
```

### Authentication errors with specific user
```powershell
# Test credentials
$cred = Get-Credential -UserName "DOMAIN\deployuser"
Invoke-Command -ComputerName YOUR-SERVER -Credential $cred -ScriptBlock { Get-Date }

# If this fails, check user permissions on target server
# See DEPLOYMENT-USER-PRIVILEGES.md for detailed setup
```

### Permission denied errors
- Ensure the deployment user has the required privileges on the target server
- **See [DEPLOYMENT-USER-PRIVILEGES.md](DEPLOYMENT-USER-PRIVILEGES.md) for detailed permission requirements**
- Verify network share permissions: `\\SERVER\c$\` requires admin access
- Check that User Account Control (UAC) is configured properly
- Use the verification script in DEPLOYMENT-USER-PRIVILEGES.md to check all permissions

### App pool won't stop
- Increase timeout in `deploy-config.json` → `iisSettings.stopTimeout`
- Check if application has long-running requests
- Manually check app pool state on server

### Deployment fails but app pool is stopped
The script attempts to restart the app pool automatically on failure.
Manual restart:
```powershell
# On target server
Import-Module WebAdministration
Start-WebAppPool -Name "YOUR-APP-POOL-NAME"
```

## Security Considerations

**For comprehensive security setup, see [DEPLOYMENT-USER-PRIVILEGES.md](DEPLOYMENT-USER-PRIVILEGES.md)**

1. **Credentials**: The script supports multiple authentication methods:
   - Current user credentials (default)
   - Specific user via `-Username` parameter (prompts for password)
   - Pre-stored credentials via `-Credential` parameter
   - Managed Service Accounts (recommended for automated deployments)
   - Group Managed Service Accounts (gMSA) for domain environments

2. **Credential Storage**: 
   ```powershell
   # Securely store credentials (encrypted for current user)
   $cred = Get-Credential -UserName "DOMAIN\deployuser"
   $cred | Export-Clixml -Path "C:\secure\deployuser.xml"

   # Load and use
   $cred = Import-Clixml -Path "C:\secure\deployuser.xml"
   .\Deploy-Application.ps1 -Environment production -Credential $cred
   ```

3. **Network Shares**: UNC paths require proper permissions:
   - Use PowerShell remoting with explicit credentials
   - Configure secure file shares with specific ACLs
   - Consider custom shares instead of administrative shares (`c$`)

4. **Principle of Least Privilege**:
   - Don't use domain admin accounts for deployment
   - Create dedicated deployment service accounts
   - Grant only necessary permissions (see DEPLOYMENT-USER-PRIVILEGES.md)
   - Enable auditing on deployment directories

5. **Configuration File**: Contains server names and paths. Consider:
   - Storing in secure location
   - Using different config files for each user/environment
   - Adding to .gitignore if it contains sensitive data
   - **Never store passwords in the config file**

## Deployment User Setup

**IMPORTANT**: Before deploying, ensure the deployment user has proper permissions on the target server.

See **[DEPLOYMENT-USER-PRIVILEGES.md](DEPLOYMENT-USER-PRIVILEGES.md)** for:
- Required Windows groups and roles
- IIS-specific permissions
- File system permissions
- PowerShell remoting configuration
- Security best practices
- Verification scripts
- Troubleshooting guide

### Quick Permission Checklist

The deployment user needs:
- ✅ Member of "Remote Management Users" (for PowerShell remoting)
- ✅ Member of "Administrators" OR specific IIS/file system permissions
- ✅ Full Control on deployment directory
- ✅ Full Control on backup directory
- ✅ PowerShell remoting enabled on target server
- ✅ WinRM service running on target server

## Continuous Integration

This script can be integrated with CI/CD pipelines:

### Azure DevOps
```yaml
- task: PowerShell@2
  inputs:
	filePath: 'deployment/Deploy-Application.ps1'
	arguments: '-Environment production'
```

### GitHub Actions
```yaml
- name: Deploy Application
  shell: pwsh
  run: |
	cd deployment
	.\Deploy-Application.ps1 -Environment production
```

## Support

For issues or questions, please refer to:
- Project repository: https://github.com/uwe-e/BSE.Identity
- Project documentation
