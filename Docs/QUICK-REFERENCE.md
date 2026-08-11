# Deployment Quick Reference

## 🚀 Common Commands

### Deploy with Current User
```powershell
.\Deploy-Application.ps1 -Environment <development|staging|production>
```

### Deploy with Specific User
```powershell
.\Deploy-Application.ps1 -Environment production -Username "DOMAIN\deployuser"
```

### Deploy with Stored Credentials
```powershell
$cred = Import-Clixml -Path "C:\secure\deployuser.xml"
.\Deploy-Application.ps1 -Environment production -Credential $cred
```

### Skip Build (Deploy Existing Output)
```powershell
.\Deploy-Application.ps1 -Environment development -SkipBuild
```

### Skip Backup (Faster Deployment)
```powershell
.\Deploy-Application.ps1 -Environment development -SkipBackup
```

## 🔧 Setup Commands (Run on Target Server as Admin)

### Automated User Setup
```powershell
.\Setup-DeploymentUser.ps1 -DeploymentUser "DOMAIN\deployuser" `
							-DeploymentPath "C:\inetpub\wwwroot\BSE.Identity" `
							-BackupPath "C:\Backups\BSE.Identity" `
							-AppPoolNames @("BSE.Identity") `
							-MinimumPermissions
```

### Enable PowerShell Remoting
```powershell
Enable-PSRemoting -Force
Start-Service WinRM
Set-Service WinRM -StartupType Automatic
```

## 🔐 Credential Management

### Store Credentials (One-Time)
```powershell
$cred = Get-Credential -UserName "DOMAIN\deployuser"
$cred | Export-Clixml -Path "C:\secure\deployuser.xml"
```

### Load and Use Stored Credentials
```powershell
$cred = Import-Clixml -Path "C:\secure\deployuser.xml"
.\Deploy-Application.ps1 -Environment production -Credential $cred
```

## 🧪 Testing Commands

### Test PowerShell Remoting
```powershell
# From deployment machine
Test-WSMan -ComputerName TARGET-SERVER

# With credentials
$cred = Get-Credential
Invoke-Command -ComputerName TARGET-SERVER -Credential $cred -ScriptBlock { Get-Date }
```

### Test File Access
```powershell
Test-Path "\\TARGET-SERVER\c$\inetpub\wwwroot"
```

### Verify Deployment User Permissions
```powershell
# Run on target server
# Use the verification script from DEPLOYMENT-USER-PRIVILEGES.md
```

## 📝 Configuration File Locations

- **Main Config**: `deploy-config.json`
- **Stored Credentials**: `C:\secure\deployuser.xml` (or custom location)
- **Deployment Logs**: `deployment-log-YYYYMMDD-HHmmss.txt`
- **Backups**: As configured in `deploy-config.json` (e.g., `C:\Backups\BSE.Identity`)

## 🔄 Rollback Procedure

```powershell
# 1. Find backup folder
Get-ChildItem "C:\Backups\BSE.Identity" | Sort-Object Name -Descending | Select -First 5

# 2. Stop app pool
Stop-WebAppPool -Name "BSE.Identity"

# 3. Restore from backup
$backup = "C:\Backups\BSE.Identity\YYYYMMDD-HHMMSS"
$deploy = "C:\inetpub\wwwroot\BSE.Identity"
Remove-Item $deploy\* -Recurse -Force
Copy-Item $backup\* -Destination $deploy -Recurse

# 4. Start app pool
Start-WebAppPool -Name "BSE.Identity"
```

## ⚠️ Troubleshooting Quick Fixes

### Access Denied
```powershell
# Add to trusted hosts
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "TARGET-SERVER" -Force
```

### App Pool Won't Stop
- Increase timeout in `deploy-config.json`: `"stopTimeout": 60`
- Check for long-running requests in IIS

### Cannot Copy Files
- Verify file permissions on target
- Check network share access: `Test-Path "\\SERVER\c$\path"`
- User needs Administrator rights for `c$` shares

### WinRM Not Working
```powershell
# On target server
Enable-PSRemoting -Force
Enable-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)"
```

## 📚 Documentation

- **Full Setup Guide**: [SETUP-GUIDE.md](SETUP-GUIDE.md)
- **Usage Reference**: [README.md](README.md)
- **Permissions Guide**: [DEPLOYMENT-USER-PRIVILEGES.md](DEPLOYMENT-USER-PRIVILEGES.md)
- **Setup Script**: `Setup-DeploymentUser.ps1`
- **Deploy Script**: `Deploy-Application.ps1`

## 🎯 Deployment Checklist

Before Production Deployment:
- [ ] Test in development environment
- [ ] Verify deployment user credentials
- [ ] Review and update `deploy-config.json`
- [ ] Check target server connectivity
- [ ] Ensure backups are enabled
- [ ] Notify team of deployment window
- [ ] Review previous deployment log
- [ ] Prepare rollback plan

After Deployment:
- [ ] Verify application starts successfully
- [ ] Check deployment log for warnings
- [ ] Test critical application features
- [ ] Monitor server resources
- [ ] Document any issues or notes

## 👤 Default Paths

**Development:**
- Server: `DEV-SERVER`
- Path: `\\DEV-SERVER\c$\inetpub\wwwroot\BSE.Identity.Dev`
- App Pool: `BSE.Identity.Dev`

**Staging:**
- Server: `STAGING-SERVER`
- Path: `\\STAGING-SERVER\c$\inetpub\wwwroot\BSE.Identity.Staging`
- App Pool: `BSE.Identity.Staging`

**Production:**
- Server: `PROD-SERVER`
- Path: `\\PROD-SERVER\c$\inetpub\wwwroot\BSE.Identity`
- App Pool: `BSE.Identity`

---

**💡 Tip**: Bookmark this file or print it for quick reference during deployments!
