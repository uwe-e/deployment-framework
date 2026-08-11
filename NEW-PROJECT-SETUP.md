# Adding Deployment to a New Project

Quick guide for adding the shared deployment framework to a new .NET project.

## Prerequisites

- Shared deployment framework installed at `C:\Git\ASP.Net\DeploymentScripts`
- OR environment variable `SHARED_DEPLOYMENT_SCRIPTS` set
- Target IIS server prepared (see Docs\SETUP-GUIDE.md)

## Step 1: Create Deployment Folder

```powershell
cd YourProjectSolution
New-Item -ItemType Directory -Path "deployment" -Force
```

## Step 2: Copy Templates

```powershell
$templates = "C:\Git\ASP.Net\DeploymentScripts\Templates"
$project = ".\deployment"

# Copy launcher script
Copy-Item "$templates\Deploy.ps1" -Destination "$project\Deploy.ps1"

# Copy configuration template
Copy-Item "$templates\deploy-config.template.json" -Destination "$project\deploy-config.json"

# Copy README
Copy-Item "$templates\README-PROJECT.md" -Destination "$project\README.md"

# Copy .gitignore
Copy-Item "$templates\.gitignore" -Destination "$project\.gitignore"
```

## Step 3: Configure deploy-config.json

Edit `deployment\deploy-config.json`:

```json
{
  "projectName": "YourProject.Name",
  "projectDescription": "Your project description",
  "repositoryUrl": "https://github.com/yourorg/yourproject",

  "environments": {
	"development": {
	  "projectPath": "src\\YourProject\\YourProject.csproj",
	  "buildConfiguration": "Debug",
	  "targetServer": "DEV-SERVER",
	  "deploymentPath": "\\\\DEV-SERVER\\c$\\inetpub\\wwwroot\\YourProject.Dev",
	  "appPoolName": "YourProject.Dev",
	  "websiteName": "YourProject.Dev",
	  "deploymentUsername": "",
	  "backupEnabled": true,
	  "backupPath": "\\\\DEV-SERVER\\c$\\Backups\\YourProject.Dev"
	},
	"production": {
	  "projectPath": "src\\YourProject\\YourProject.csproj",
	  "buildConfiguration": "Release",
	  "targetServer": "PROD-SERVER",
	  "deploymentPath": "\\\\PROD-SERVER\\c$\\inetpub\\wwwroot\\YourProject",
	  "appPoolName": "YourProject",
	  "websiteName": "YourProject",
	  "deploymentUsername": "DOMAIN\\proddeploy",
	  "backupEnabled": true,
	  "backupPath": "\\\\PROD-SERVER\\c$\\Backups\\YourProject"
	}
  }
}
```

### Key Configuration Items

- **projectPath**: Relative path from solution root to .csproj file
- **targetServer**: Hostname or IP of target server
- **deploymentPath**: UNC path to IIS directory (use `\\\\` for JSON)
- **appPoolName**: IIS Application Pool name
- **deploymentUsername**: Optional default deployment user

## Step 4: Test Deployment

```powershell
cd deployment

# Test with current credentials
.\Deploy.ps1 -Environment development

# OR with specific user
.\Deploy.ps1 -Environment development -Username "DOMAIN\deployuser"
```

## Step 5: Commit to Git

```powershell
git add deployment/
git commit -m "Add deployment configuration"
git push
```

**Note**: The `.gitignore` prevents sensitive files (logs, credentials) from being committed.

## Automated Setup Script

For convenience, here's a script to automate steps 1-2:

```powershell
<#
.SYNOPSIS
	Adds deployment to a new project using shared framework.

.EXAMPLE
	.\Add-Deployment.ps1 -ProjectPath "C:\Projects\MyNewProject"
#>
param(
	[Parameter(Mandatory=$true)]
	[string]$ProjectPath,

	[Parameter(Mandatory=$false)]
	[string]$SharedScriptsPath = "C:\Git\ASP.Net\DeploymentScripts"
)

$ErrorActionPreference = "Stop"

Write-Host "Adding deployment to: $ProjectPath" -ForegroundColor Cyan

# Create deployment folder
$deploymentPath = Join-Path $ProjectPath "deployment"
New-Item -ItemType Directory -Path $deploymentPath -Force | Out-Null
Write-Host "✓ Created deployment folder" -ForegroundColor Green

# Copy templates
$templatesPath = Join-Path $SharedScriptsPath "Templates"

if (-not (Test-Path $templatesPath)) {
	throw "Templates not found at: $templatesPath"
}

$files = @(
	@{ Source = "Deploy.ps1"; Destination = "Deploy.ps1" },
	@{ Source = "deploy-config.template.json"; Destination = "deploy-config.json" },
	@{ Source = "README-PROJECT.md"; Destination = "README.md" },
	@{ Source = ".gitignore"; Destination = ".gitignore" }
)

foreach ($file in $files) {
	$source = Join-Path $templatesPath $file.Source
	$dest = Join-Path $deploymentPath $file.Destination

	if (Test-Path $source) {
		Copy-Item $source -Destination $dest -Force
		Write-Host "✓ Copied $($file.Destination)" -ForegroundColor Green
	} else {
		Write-Host "⚠ Template not found: $($file.Source)" -ForegroundColor Yellow
	}
}

Write-Host "`nDeployment setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Edit deployment\deploy-config.json with your project settings"
Write-Host "2. Configure target server (see DeploymentScripts\Docs\SETUP-GUIDE.md)"
Write-Host "3. Test: cd deployment; .\Deploy.ps1 -Environment development"
Write-Host ""
```

Save this as `DeploymentScripts\Templates\Add-Deployment.ps1` and use:

```powershell
C:\Git\ASP.Net\DeploymentScripts\Templates\Add-Deployment.ps1 -ProjectPath "C:\Projects\MyNewProject"
```

## Multiple Projects Example

Once shared framework is set up, adding deployment to multiple projects is fast:

```powershell
# Project 1
cd C:\Projects\Project1
.\Add-Deployment.ps1

# Project 2
cd C:\Projects\Project2
.\Add-Deployment.ps1

# Project 3
cd C:\Projects\Project3
.\Add-Deployment.ps1

# Each project now has:
# - deployment\Deploy.ps1 (launcher)
# - deployment\deploy-config.json (config)
# - deployment\README.md (docs)
```

All use the same shared deployment logic!

## Troubleshooting

### Shared Scripts Not Found

If launcher can't find shared scripts:

```powershell
# Option 1: Set environment variable
[System.Environment]::SetEnvironmentVariable(
	"SHARED_DEPLOYMENT_SCRIPTS",
	"C:\Git\ASP.Net\DeploymentScripts",
	"User"
)

# Option 2: Use explicit path
.\Deploy.ps1 -Environment dev -SharedScriptsPath "C:\Git\ASP.Net\DeploymentScripts"
```

### Build Fails

Ensure `projectPath` in config points to correct .csproj file:

```powershell
# Verify path exists (relative to solution root)
Test-Path "src\YourProject\YourProject.csproj"
```

## Template Customization

To customize templates for your organization:

1. Edit files in `DeploymentScripts\Templates\`
2. Add company-specific defaults
3. Include additional documentation
4. All new projects will use updated templates

## Support

For detailed documentation:
- **Setup Guide**: `DeploymentScripts\Docs\SETUP-GUIDE.md`
- **Quick Reference**: `DeploymentScripts\Docs\QUICK-REFERENCE.md`
- **Permissions**: `DeploymentScripts\Docs\DEPLOYMENT-USER-PRIVILEGES.md`
