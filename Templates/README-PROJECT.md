# BSE.Identity Deployment

This directory contains **project-specific** deployment configuration for the BSE.Identity Blazor application.

## Project Architecture

This project uses a **shared deployment framework** to avoid code duplication:

- **Shared Scripts**: Common deployment logic used across multiple projects
- **This Directory**: Only project-specific configuration and launcher

### Files in This Directory

- **Deploy.ps1** - Lightweight launcher script (calls shared framework)
- **deploy-config.json** - Project-specific configuration
- **.gitignore** - Prevents sensitive files from being committed

## Shared Deployment Framework

The main deployment logic is located in a shared location, typically:
- `C:\Git\ASP.Net\DeploymentScripts\` (sibling to solution)
- Or set via environment variable: `$env:SHARED_DEPLOYMENT_SCRIPTS`

### Shared Framework Structure

```
DeploymentScripts\
├── Core\
│   ├── Deploy-Application.ps1        # Main deployment engine
│   ├── Setup-DeploymentUser.ps1      # User setup automation
│   └── DeploymentFunctions.ps1       # Shared utilities
├── Docs\
│   ├── README.md                     # Comprehensive documentation
│   ├── SETUP-GUIDE.md                # Step-by-step setup
│   ├── DEPLOYMENT-USER-PRIVILEGES.md # Permission requirements
│   └── QUICK-REFERENCE.md            # Command cheat sheet
└── Templates\
	└── deploy-config.template.json   # Config template for new projects
```

## Installation

### First-Time Setup

If this is your first time deploying, you need the shared deployment framework:

```powershell
# Clone or copy shared deployment scripts to a common location
# Recommended: C:\Git\ASP.Net\DeploymentScripts

# OR set environment variable
$env:SHARED_DEPLOYMENT_SCRIPTS = "C:\Path\To\DeploymentScripts"
[System.Environment]::SetEnvironmentVariable("SHARED_DEPLOYMENT_SCRIPTS", "C:\Path\To\DeploymentScripts", "User")
```

### Configure Target Server

Run the setup script **on the target server** (as Administrator):

```powershell
# Use shared setup script
C:\Git\ASP.Net\DeploymentScripts\Core\Setup-DeploymentUser.ps1 `
	-DeploymentUser "DOMAIN\deployuser" `
	-DeploymentPath "C:\inetpub\wwwroot\BSE.Identity" `
	-BackupPath "C:\Backups\BSE.Identity" `
	-AppPoolNames @("BSE.Identity") `
	-MinimumPermissions
```

### Configure This Project

Edit `deploy-config.json` with your server details and paths.

## Usage

All deployments use the lightweight launcher script:

### Basic Deployment

```powershell
# Deploy to development
.\Deploy.ps1 -Environment development

# Deploy to production with specific user
.\Deploy.ps1 -Environment production -Username "DOMAIN\deployuser"
```

### Advanced Options

```powershell
# Skip build (deploy existing output)
.\Deploy.ps1 -Environment development -SkipBuild

# Skip backup
.\Deploy.ps1 -Environment development -SkipBackup

# Use stored credentials
$cred = Import-Clixml -Path "C:\secure\deployuser.xml"
.\Deploy.ps1 -Environment production -Credential $cred

# Specify shared scripts location
.\Deploy.ps1 -Environment production -SharedScriptsPath "C:\DeploymentFramework"
```

## Documentation

For comprehensive documentation, see the shared framework docs:

- **Quick Reference**: `DeploymentScripts\Docs\QUICK-REFERENCE.md`
- **Setup Guide**: `DeploymentScripts\Docs\SETUP-GUIDE.md`
- **Permissions Guide**: `DeploymentScripts\Docs\DEPLOYMENT-USER-PRIVILEGES.md`
- **Full Documentation**: `DeploymentScripts\Docs\README.md`

## Configuration

This project's configuration is in `deploy-config.json`:

```json
{
  "projectName": "BSE.Identity.Blazor.Client",
  "projectDescription": "BSE.Identity Blazor Server Application",
  "environments": {
	"development": {
	  "projectPath": "src\\BSE.Identity.Blazor.Client\\BSE.Identity.Blazor.Client.csproj",
	  "buildConfiguration": "Debug",
	  "targetServer": "DEV-SERVER",
	  "deploymentPath": "\\\\DEV-SERVER\\c$\\inetpub\\wwwroot\\BSE.Identity.Dev",
	  "appPoolName": "BSE.Identity.Dev",
	  "websiteName": "BSE.Identity.Dev",
	  "deploymentUsername": "",
	  "backupEnabled": true,
	  "backupPath": "\\\\DEV-SERVER\\c$\\Backups\\BSE.Identity.Dev"
	}
  }
}
```

## Advantages of This Architecture

✅ **Single Source of Truth**: Update deployment logic once, applies to all projects
✅ **Cleaner Project Repos**: Only config and launcher in version control
✅ **Easier Maintenance**: Fix bugs or add features in one place
✅ **Consistency**: All projects use the same deployment process
✅ **Scalability**: Easy to add new projects without duplicating code

## Troubleshooting

### Cannot Find Shared Scripts

If you see "Could not find shared deployment scripts":

1. **Check installation location**:
   ```powershell
   Test-Path "C:\Git\ASP.Net\DeploymentScripts\Core\Deploy-Application.ps1"
   ```

2. **Set environment variable**:
   ```powershell
   $env:SHARED_DEPLOYMENT_SCRIPTS = "C:\Your\Path\DeploymentScripts"
   ```

3. **Specify explicitly**:
   ```powershell
   .\Deploy.ps1 -Environment dev -SharedScriptsPath "C:\Path\To\DeploymentScripts"
   ```

### Other Issues

For all other troubleshooting, see the shared framework documentation:
- `DeploymentScripts\Docs\SETUP-GUIDE.md` - Troubleshooting section
- `DeploymentScripts\Docs\DEPLOYMENT-USER-PRIVILEGES.md` - Permission issues

## Support

- **Project Repository**: https://github.com/uwe-e/BSE.Identity
- **Shared Framework Docs**: See `DeploymentScripts\Docs\` directory
