# Shared Deployment Framework

This directory contains **reusable deployment scripts** for deploying .NET applications to IIS servers.

## Overview

This framework provides a centralized, project-independent deployment solution that can be used across multiple projects. Each project maintains only:
- A lightweight launcher script
- Project-specific configuration

## Directory Structure

```
DeploymentScripts\
├── Core\                           # Core deployment logic
│   ├── Deploy-Application.ps1      # Main deployment engine
│   ├── Setup-DeploymentUser.ps1    # Automated user setup
│   └── DeploymentFunctions.ps1     # Shared utility functions
│
├── Docs\                           # Comprehensive documentation
│   ├── README.md                   # Main documentation
│   ├── SETUP-GUIDE.md              # Step-by-step setup guide
│   ├── DEPLOYMENT-USER-PRIVILEGES.md # Permission requirements
│   └── QUICK-REFERENCE.md          # Command cheat sheet
│
└── Templates\                      # Templates for new projects
	├── deploy-config.template.json # Configuration template
	├── Deploy.ps1                  # Launcher script template
	└── README-PROJECT.md           # Project README template
```

## Installation

### Option 1: Sibling to Solutions (Recommended)

Place the shared scripts in a common location accessible to all projects:

```
C:\Git\ASP.Net\
├── DeploymentScripts\          # ← Shared scripts here
├── BSE.Identity\               # Project 1
│   └── deployment\
│       ├── Deploy.ps1          # Launcher
│       └── deploy-config.json  # Config
├── AnotherProject\             # Project 2
│   └── deployment\
│       ├── Deploy.ps1
│       └── deploy-config.json
└── YetAnotherProject\          # Project 3
	└── deployment\
		├── Deploy.ps1
		└── deploy-config.json
```

### Option 2: Environment Variable

Set an environment variable pointing to the shared scripts:

```powershell
# User-level (current user only)
[System.Environment]::SetEnvironmentVariable(
	"SHARED_DEPLOYMENT_SCRIPTS", 
	"C:\DeploymentFramework", 
	"User"
)

# Machine-level (all users)
[System.Environment]::SetEnvironmentVariable(
	"SHARED_DEPLOYMENT_SCRIPTS", 
	"C:\DeploymentFramework", 
	"Machine"
)
```

### Option 3: Network Share (Enterprise)

For enterprise environments with multiple developers:

```powershell
# Set to network location
$env:SHARED_DEPLOYMENT_SCRIPTS = "\\FileServer\DeploymentScripts"
```

## Creating a New Project

When adding deployment to a new project:

### 1. Create Project Deployment Folder

```powershell
New-Item -ItemType Directory -Path "YourProject\deployment"
```

### 2. Copy Templates

```powershell
$templatesPath = "C:\Git\ASP.Net\DeploymentScripts\Templates"
$projectPath = "YourProject\deployment"

# Copy launcher script
Copy-Item "$templatesPath\Deploy.ps1" -Destination "$projectPath\Deploy.ps1"

# Copy config template
Copy-Item "$templatesPath\deploy-config.template.json" -Destination "$projectPath\deploy-config.json"

# Copy README
Copy-Item "$templatesPath\README-PROJECT.md" -Destination "$projectPath\README.md"

# Copy .gitignore
Copy-Item "$templatesPath\.gitignore" -Destination "$projectPath\.gitignore"
```

### 3. Configure

Edit `deploy-config.json` with your project-specific settings:
- Project path (.csproj location)
- Server names
- Deployment paths
- App pool names

### 4. Deploy

```powershell
cd YourProject\deployment
.\Deploy.ps1 -Environment development
```

## Features

### ✅ Centralized Management
- Update deployment logic once, applies to all projects
- Bug fixes benefit all projects immediately
- Consistent deployment process across organization

### ✅ Project Independence
- Each project maintains only configuration
- No duplicate code in project repositories
- Clean separation of concerns

### ✅ Flexible Credential Management
- Current user credentials
- Specific user with password prompt
- Pre-stored PSCredential objects
- Compatible with CI/CD pipelines

### ✅ Safe Deployments
- Automatic app pool stop/start
- Backup before deployment
- Comprehensive error handling
- Detailed logging

### ✅ Multi-Environment Support
- Development, Staging, Production
- Unlimited custom environments
- Environment-specific settings

## Usage Across Projects

All projects use the same command pattern:

```powershell
# Project A
cd ProjectA\deployment
.\Deploy.ps1 -Environment production -Username "DOMAIN\deploy"

# Project B
cd ProjectB\deployment
.\Deploy.ps1 -Environment production -Username "DOMAIN\deploy"

# Project C
cd ProjectC\deployment
.\Deploy.ps1 -Environment production -Username "DOMAIN\deploy"
```

The launcher automatically finds and uses the shared scripts.

## Updating the Framework

To update the shared deployment framework:

```powershell
cd C:\Git\ASP.Net\DeploymentScripts

# Pull latest changes (if version controlled)
git pull

# Or manually update Core\Deploy-Application.ps1
# All projects will use the updated version immediately
```

## Version Control

### Shared Scripts Repository (Optional)

Consider maintaining the shared scripts in their own Git repository:

```powershell
cd C:\Git\ASP.Net\DeploymentScripts
git init
git add .
git commit -m "Initial deployment framework"
git remote add origin https://your-git-server/deployment-framework.git
git push -u origin main
```

Teams can then clone/pull updates:

```powershell
git clone https://your-git-server/deployment-framework.git C:\DeploymentScripts
```

### Project Repositories

Each project's repository includes only:
- `deployment/Deploy.ps1` (launcher)
- `deployment/deploy-config.json` (configuration)
- `deployment/README.md` (project-specific docs)
- `deployment/.gitignore` (security)

The heavy-lifting scripts are external and not duplicated.

## Enterprise Setup Example

For large organizations with many projects:

```
\\FileServer\Shared\
└── DeploymentFramework\          # Shared on network
	├── Core\
	├── Docs\
	└── Templates\

# Each developer's machine
$env:SHARED_DEPLOYMENT_SCRIPTS = "\\FileServer\Shared\DeploymentFramework"

# Or map network drive
New-PSDrive -Name "Z" -PSProvider FileSystem -Root "\\FileServer\Shared"
$env:SHARED_DEPLOYMENT_SCRIPTS = "Z:\DeploymentFramework"
```

## Documentation

All documentation is in the `Docs\` folder:

- **[README.md](Docs/README.md)** - Comprehensive documentation
- **[SETUP-GUIDE.md](Docs/SETUP-GUIDE.md)** - Step-by-step setup instructions  
- **[DEPLOYMENT-USER-PRIVILEGES.md](Docs/DEPLOYMENT-USER-PRIVILEGES.md)** - Permission requirements
- **[QUICK-REFERENCE.md](Docs/QUICK-REFERENCE.md)** - Quick command reference

## Maintenance

### Adding New Features

1. Update `Core\Deploy-Application.ps1` or create new scripts in `Core\`
2. Update documentation in `Docs\`
3. Test with multiple projects
4. Document breaking changes if any

### Supporting New Project Types

Currently supports:
- ASP.NET Core / Blazor applications
- Any .NET project with `dotnet publish` support

To add support for other types:
- Update `Core\Deploy-Application.ps1` with new build logic
- Add new templates in `Templates\`
- Document in `Docs\README.md`

## Support Matrix

| Feature | Supported |
|---------|-----------|
| .NET Framework | ✅ Yes (with MSBuild) |
| .NET Core 3.1+ | ✅ Yes |
| .NET 5-9 | ✅ Yes |
| ASP.NET Core | ✅ Yes |
| Blazor Server | ✅ Yes |
| Blazor WebAssembly | ⚠️ Partial (static files only) |
| Windows IIS | ✅ Yes |
| Linux | ❌ No (IIS-specific) |
| Docker | ❌ No (different deployment model) |

## Migration from Project-Embedded Scripts

If you have existing projects with embedded deployment scripts:

```powershell
# 1. Set up shared framework
# (Install this framework as shown above)

# 2. For each project, replace with launcher
cd YourProject\deployment

# Backup existing scripts
Move-Item Deploy-Application.ps1 Deploy-Application.ps1.bak
Move-Item Setup-DeploymentUser.ps1 Setup-DeploymentUser.ps1.bak
Move-Item *.md *.md.bak

# Copy new launcher
Copy-Item C:\Git\ASP.Net\DeploymentScripts\Templates\Deploy.ps1 .
Copy-Item C:\Git\ASP.Net\DeploymentScripts\Templates\README-PROJECT.md .\README.md

# Keep your existing deploy-config.json (it's compatible)

# 3. Test
.\Deploy.ps1 -Environment development

# 4. If successful, remove backups
Remove-Item *.bak
```

## Troubleshooting

### Cannot Find Shared Scripts

**Error**: "Could not find shared deployment scripts"

**Solution**:
1. Verify installation location exists
2. Set `$env:SHARED_DEPLOYMENT_SCRIPTS`
3. Use `-SharedScriptsPath` parameter explicitly

### Permission Issues

See `Docs\DEPLOYMENT-USER-PRIVILEGES.md` for comprehensive permission setup.

### Script Not Executing

Ensure PowerShell execution policy allows scripts:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Contributing

To contribute improvements to the shared framework:

1. Test changes with multiple projects
2. Update documentation
3. Consider backward compatibility
4. Update version information
5. Communicate changes to all users

## Versioning

Framework version: **1.0.0** (2026-01-10)

### Version History

- **1.0.0** (2026-01-10)
  - Initial release
  - Support for .NET 9
  - Multi-credential support
  - Auto-discovery of shared scripts

## License

This deployment framework is provided as-is for use with your projects.

## Contact

For issues or questions:
- Check documentation in `Docs\` folder
- Review `QUICK-REFERENCE.md` for common commands
- See `SETUP-GUIDE.md` for troubleshooting
