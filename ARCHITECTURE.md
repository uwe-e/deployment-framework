# Project-Independent Deployment Architecture

## Overview

This document describes the architecture for a **shared, reusable deployment framework** that eliminates code duplication across multiple projects.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Shared Deployment Framework                   │
│              C:\Git\ASP.Net\DeploymentScripts\                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Core/                                                          │
│  ├── Deploy-Application.ps1      ◄── Main deployment engine     │
│  ├── Setup-DeploymentUser.ps1    ◄── Server setup automation    │
│  └── DeploymentFunctions.ps1     ◄── Shared utilities           │
│                                                                  │
│  Docs/                                                          │
│  ├── README.md                    ◄── Full documentation         │
│  ├── SETUP-GUIDE.md               ◄── Step-by-step guide         │
│  ├── DEPLOYMENT-USER-PRIVILEGES.md ◄── Permissions guide         │
│  └── QUICK-REFERENCE.md           ◄── Command cheat sheet        │
│                                                                  │
│  Templates/                                                      │
│  ├── Deploy.ps1                   ◄── Launcher template          │
│  ├── deploy-config.template.json  ◄── Config template           │
│  ├── README-PROJECT.md            ◄── Project README             │
│  ├── .gitignore                   ◄── Security template          │
│  └── Add-Deployment.ps1           ◄── Setup automation           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
							   ▲
							   │ calls
			  ┌────────────────┼────────────────┐
			  │                │                │
	┌─────────▼──────┐  ┌──────▼──────┐  ┌─────▼──────┐
	│  Project A     │  │  Project B  │  │  Project C │
	│  BSE.Identity  │  │  SomeApp    │  │  AnotherApp│
	├────────────────┤  ├─────────────┤  ├────────────┤
	│ deployment/    │  │ deployment/ │  │ deployment/│
	│ ├ Deploy.ps1   │  │ ├ Deploy.ps1│  │ ├ Deploy.ps1
	│ └ config.json  │  │ └ config.json  │ └ config.json
	└────────────────┘  └─────────────┘  └────────────┘
		 8 KB files          8 KB files       8 KB files

	vs. 100+ KB with embedded scripts (saves ~90KB per project)
```

## Benefits

### 1. **Single Source of Truth**
- Update deployment logic once, applies to all projects
- Bug fixes benefit all projects immediately  
- Consistent deployment process across organization

### 2. **Reduced Duplication**
- Each project: ~8 KB (launcher + config)
- Without sharing: ~100+ KB (full scripts + docs)
- **Savings**: ~90 KB per project × N projects

### 3. **Cleaner Repositories**
- Project repos contain only configuration
- No duplicate documentation
- Easier code reviews (config-only changes)

### 4. **Better Maintenance**
- Update once, not N times
- Easier to add features
- Centralized testing and validation

### 5. **Enterprise Ready**
- Network share deployment possible
- Version control for deployment framework separate from projects
- Easy to enforce standards

## File Size Comparison

### Traditional Approach (Embedded Scripts)
```
ProjectA/
└── deployment/            ~110 KB
	├── Deploy-Application.ps1       (13 KB)
	├── Setup-DeploymentUser.ps1     (9 KB)
	├── README.md                     (11 KB)
	├── SETUP-GUIDE.md                (12 KB)
	├── DEPLOYMENT-USER-PRIVILEGES.md (13 KB)
	├── QUICK-REFERENCE.md            (5 KB)
	├── deploy-config.json            (2 KB)
	└── .gitignore                    (< 1 KB)

ProjectB/
└── deployment/            ~110 KB (duplicate!)
	└── [same files...]

ProjectC/
└── deployment/            ~110 KB (duplicate!)
	└── [same files...]

Total: 330 KB for 3 projects
```

### Shared Framework Approach
```
DeploymentScripts/         ~65 KB (shared once)
├── Core/                   22 KB
├── Docs/                   41 KB
└── Templates/              2 KB

ProjectA/
└── deployment/            ~8 KB
	├── Deploy.ps1          (6 KB - thin wrapper)
	├── deploy-config.json  (2 KB)
	└── .gitignore          (< 1 KB)

ProjectB/
└── deployment/            ~8 KB
	└── [same structure...]

ProjectC/
└── deployment/            ~8 KB
	└── [same structure...]

Total: ~90 KB for 3 projects (65 + 8 + 8 + 8)
Savings: 240 KB (73% reduction)
```

With 10 projects: **1,100 KB → 145 KB (87% reduction)**

## Discovery Mechanism

The launcher script automatically finds shared scripts using this priority:

1. **Explicit parameter**: `-SharedScriptsPath`
2. **Environment variable**: `$env:SHARED_DEPLOYMENT_SCRIPTS`
3. **Sibling to solution**: `../DeploymentScripts`
4. **Standard location**: `C:\Git\ASP.Net\DeploymentScripts`

### Code Example

```powershell
# Auto-discovery logic in Deploy.ps1
$possiblePaths = @(
	# 1. Environment variable (highest priority)
	$env:SHARED_DEPLOYMENT_SCRIPTS,

	# 2. Sibling to solution root
	(Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "DeploymentScripts"),

	# 3. Standard location
	"C:\Git\ASP.Net\DeploymentScripts"
)

foreach ($path in $possiblePaths) {
	if ($path -and (Test-Path (Join-Path $path "Core\Deploy-Application.ps1"))) {
		$SharedScriptsPath = $path
		break
	}
}
```

## Configuration Flow

```
┌──────────────────┐
│  Deploy.ps1      │  1. User runs launcher
│  (Project)       │     .\Deploy.ps1 -Environment production
└────────┬─────────┘
		 │
		 │ 2. Auto-discovers shared scripts
		 │    → Environment variable
		 │    → Sibling directory
		 │    → Standard location
		 │
		 ▼
┌──────────────────────────┐
│  Deploy-Application.ps1  │  3. Loads project config
│  (Shared)                │     deployment\deploy-config.json
└────────┬─────────────────┘
		 │
		 │ 4. Executes deployment
		 │    • Build project
		 │    • Stop app pool
		 │    • Backup
		 │    • Deploy files
		 │    • Start app pool
		 │
		 ▼
┌──────────────────┐
│  Target Server   │  5. Application deployed
│  (IIS)           │
└──────────────────┘
```

## Setup Process

### One-Time Framework Setup

```powershell
# 1. Install shared scripts (one time)
cd C:\Git\ASP.Net
git clone https://your-org/deployment-framework.git DeploymentScripts

# 2. Optional: Set environment variable
[System.Environment]::SetEnvironmentVariable(
	"SHARED_DEPLOYMENT_SCRIPTS",
	"C:\Git\ASP.Net\DeploymentScripts",
	"User"
)
```

### Per-Project Setup

```powershell
# For each new project (< 1 minute)
cd ProjectName
C:\Git\ASP.Net\DeploymentScripts\Templates\Add-Deployment.ps1 -ProjectPath .

# Edit config
notepad deployment\deploy-config.json

# Test
cd deployment
.\Deploy.ps1 -Environment development
```

## Multi-Project Workflow

### Scenario: Update Deployment Logic

**Traditional Approach** (pain point):
```powershell
# Update ProjectA
cd ProjectA\deployment
# Edit Deploy-Application.ps1
# Test

# Update ProjectB (copy-paste changes)
cd ..\ProjectB\deployment  
# Copy changes from ProjectA
# Test

# Update ProjectC (copy-paste again)
cd ..\ProjectC\deployment
# Copy changes from ProjectA
# Test

# Total: 3× work, 3× testing, 3× risk of mistakes
```

**Shared Framework Approach** (efficient):
```powershell
# Update shared framework once
cd DeploymentScripts\Core
# Edit Deploy-Application.ps1
# Test with one project
git commit -m "Fix: Handle long app pool stop times"

# All projects automatically use updated logic!
# ProjectA, ProjectB, ProjectC all get the fix
# Total: 1× work, minimal testing, consistent
```

### Scenario: Adding New Feature

**Example**: Add pre-deployment health check

**Shared Framework**:
1. Add feature to `Core\Deploy-Application.ps1`
2. Test with one project
3. All projects can opt-in via config flag
4. Update documentation once

**Traditional**:
1. Add feature to Project A
2. Copy-paste to Project B (might forget some parts)
3. Copy-paste to Project C (might have conflicts)
4. Update docs 3 times
5. Different implementations across projects

## Version Control Strategy

### Option 1: Separate Repository (Recommended)

```
Repository: deployment-framework.git
├── Core/
├── Docs/
└── Templates/

Repository: bse-identity.git
└── deployment/
	├── Deploy.ps1           (tracks framework version)
	└── deploy-config.json

Repository: another-project.git
└── deployment/
	├── Deploy.ps1
	└── deploy-config.json
```

**Advantages**:
- Independent versioning
- Projects reference framework version
- Easy to update framework without projects
- Central issue tracking for deployment issues

### Option 2: Monorepo

```
Repository: company-projects.git
├── DeploymentScripts/    (shared)
├── BSE.Identity/
│   └── deployment/       (config only)
├── AnotherProject/
│   └── deployment/       (config only)
└── YetAnother/
	└── deployment/       (config only)
```

**Advantages**:
- Everything in one place
- Atomic commits across framework + configs
- Simpler initial setup

## Enterprise Deployment

### Network Share Setup

For large organizations:

```powershell
# 1. IT deploys framework to network share
\\FileServer\Shared\DeploymentFramework\
├── Core/
├── Docs/
└── Templates/

# 2. All developers' machines configured
$env:SHARED_DEPLOYMENT_SCRIPTS = "\\FileServer\Shared\DeploymentFramework"

# 3. Projects reference network location
# 4. IT updates framework, all developers get updates
```

### Benefits:
- ✅ Central management
- ✅ Instant updates for all users
- ✅ No local installation required
- ✅ Version tracking via file share versioning

## Migration Path

### Step 1: Install Shared Framework

```powershell
cd C:\Git\ASP.Net
# Copy or clone shared scripts
git clone https://your-repo/deployment-framework.git DeploymentScripts
```

### Step 2: Migrate Existing Project

```powershell
cd BSE.Identity\deployment

# Backup existing scripts
New-Item -ItemType Directory -Path "backup" -Force
Move-Item *.ps1, *.md -Destination backup\

# Install new launcher
Copy-Item C:\Git\ASP.Net\DeploymentScripts\Templates\Deploy.ps1 .
Copy-Item C:\Git\ASP.Net\DeploymentScripts\Templates\README-PROJECT.md .\README.md

# Keep existing deploy-config.json (it's compatible)

# Test
.\Deploy.ps1 -Environment development

# If successful, commit
git add .
git commit -m "Migrate to shared deployment framework"
```

### Step 3: Repeat for Other Projects

```powershell
# Each project takes ~2 minutes to migrate
# Scripts/docs automatically removed, replaced with launchers
```

## Maintenance

### Framework Updates

```powershell
# Update shared framework
cd C:\Git\ASP.Net\DeploymentScripts
git pull

# All projects immediately use new version
# No per-project updates needed
```

### Adding New Project

```powershell
# < 1 minute setup
cd NewProject
..\DeploymentScripts\Templates\Add-Deployment.ps1 -ProjectPath .

# Edit config
notepad deployment\deploy-config.json

# Done!
```

## Conclusion

This architecture provides:
- **73-87% size reduction** across multiple projects
- **Single source of truth** for deployment logic
- **Consistent processes** across organization
- **Faster updates** (1× vs N×)
- **Easier maintenance** and testing
- **Better documentation** (one place to update)
- **Enterprise ready** (network share deployment)

Perfect for organizations with multiple .NET projects requiring IIS deployment.
