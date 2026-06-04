# Windows 11 Privacy & Debloat Scripts

A small PowerShell toolkit for reducing Windows 11 bloat and improving privacy without switching to Linux or breaking core Windows security features.

This repository contains two scripts:

```text
Win11-Debloat.ps1
Win11-PrivacyHardening.ps1
```

The goal is to make Windows 11 less noisy, less bloated, and more privacy-respecting while keeping important features like Windows Defender, Windows Update, Microsoft Store dependencies, and normal app compatibility intact.

## Scripts

### Win11-Debloat.ps1

Removes selected built-in Windows apps that are commonly considered unnecessary for many users.

Examples of apps targeted:

```text
Microsoft Bing News
Microsoft Bing Weather
Microsoft Get Help
Microsoft Office Hub
Microsoft Solitaire Collection
Microsoft People
Microsoft To Do
Windows Feedback Hub
Xbox-related apps
Groove Music / Zune Music
Movies & TV / Zune Video
Your Phone / Phone Link
Power Automate Desktop
```

The script uses a safe dry-run mode by default.

```powershell
.\Win11-Debloat.ps1
```

To actually remove apps:

```powershell
.\Win11-Debloat.ps1 -Apply
```

The script attempts to remove both installed AppX packages and provisioned AppX packages where possible.

Some Windows packages may remain because they are system-tied or protected by Windows. For example:

```text
Microsoft.XboxGameCallableUI
```

This package is often tied into Windows gaming/system components and should usually be left alone.

### Win11-PrivacyHardening.ps1

Applies Windows 11 privacy and telemetry hardening settings through registry policy keys.

Default mode reduces telemetry and disables several optional data collection features while keeping Windows stable.

The default mode:

```text
Sets diagnostic data to Required
Limits optional diagnostic log collection
Limits dump collection
Disables feedback prompts
Disables tailored experiences
Restricts typing and inking collection
Disables activity history upload
Disables online speech recognition acceptance
Force-denies app diagnostic information access
Disables Windows consumer feature suggestions
```

Run the safe default mode:

```powershell
.\Win11-PrivacyHardening.ps1
```

Optional aggressive mode:

```powershell
.\Win11-PrivacyHardening.ps1 -Aggressive
```

Aggressive mode additionally attempts to disable:

```text
Connected User Experiences and Telemetry service
Common telemetry-related scheduled tasks
Feedback-related scheduled tasks
Customer Experience Improvement Program tasks
Application Experience telemetry tasks
```

Aggressive mode is optional. Test the normal mode first before using it.

Enterprise/Education/Server-only mode:

```powershell
.\Win11-PrivacyHardening.ps1 -EnterpriseEducationOff
```

Only use this on Windows Enterprise, Education, or Server editions. Standard Windows 11 Home/Pro should use the default Required diagnostic data level.

## Requirements

Use Windows PowerShell as Administrator.

Recommended:

```text
Windows PowerShell 5.1
Run as Administrator
Windows 11 Home, Pro, Education, Enterprise, or Server
```

PowerShell 7 can work for some commands, but Windows PowerShell 5.1 is recommended for AppX and Windows system cmdlets.

Check your PowerShell version:

```powershell
$PSVersionTable.PSVersion
```

## Running Scripts

Open Windows PowerShell as Administrator:

```text
Start Menu → Windows PowerShell → Run as administrator
```

Go to the folder where the scripts are located:

```powershell
cd "$env:USERPROFILE\Downloads"
```

Temporarily allow scripts for the current PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Unblock the scripts if Windows marks them as downloaded files:

```powershell
Unblock-File .\Win11-Debloat.ps1
Unblock-File .\Win11-PrivacyHardening.ps1
```

Run the debloat script in dry-run mode first:

```powershell
.\Win11-Debloat.ps1
```

Apply debloat changes:

```powershell
.\Win11-Debloat.ps1 -Apply
```

Run privacy hardening:

```powershell
.\Win11-PrivacyHardening.ps1
```

Restart after running:

```powershell
Restart-Computer
```

## Recommended Order

Run the scripts in this order:

```text
1. Win11-Debloat.ps1
2. Restart
3. Win11-PrivacyHardening.ps1
4. Restart
5. Test Windows Update, Defender, Edge, Store, and normal apps
```

Do not run aggressive privacy hardening immediately. Use the computer normally for a day first.

## Verification

### Check removed apps for the current user

```powershell
Get-AppxPackage |
  Where-Object {
    $_.Name -like "*BingNews*" -or
    $_.Name -like "*BingWeather*" -or
    $_.Name -like "*Solitaire*" -or
    $_.Name -like "*PowerAutomate*" -or
    $_.Name -like "*Xbox*" -or
    $_.Name -like "*Zune*" -or
    $_.Name -like "*YourPhone*" -or
    $_.Name -like "*FeedbackHub*"
  } |
  Select-Object Name, PackageFullName
```

If nothing appears, those apps are removed for your current account.

`Get-AppxPackage -AllUsers` may still show staged or system-tied packages. That does not always mean the apps are installed for your active user.

### Check provisioned apps

```powershell
Get-AppxProvisionedPackage -Online |
  Where-Object {
    $_.DisplayName -like "*BingNews*" -or
    $_.DisplayName -like "*BingWeather*" -or
    $_.DisplayName -like "*Solitaire*" -or
    $_.DisplayName -like "*PowerAutomate*" -or
    $_.DisplayName -like "*Xbox*" -or
    $_.DisplayName -like "*Zune*" -or
    $_.DisplayName -like "*YourPhone*" -or
    $_.DisplayName -like "*FeedbackHub*"
  } |
  Select-Object DisplayName, PackageName
```

Provisioned packages affect new Windows user accounts. They may not affect your current account.

### Check privacy hardening registry keys

```powershell
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"

Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"

Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"

Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
```

Expected important values:

```text
AllowTelemetry = 1
LimitDiagnosticLogCollection = 1
LimitDumpCollection = 1
DoNotShowFeedbackNotifications = 1
TailoredExperiencesWithDiagnosticDataEnabled = 0
EnableActivityFeed = 0
PublishUserActivities = 0
UploadUserActivities = 0
LetAppsGetDiagnosticInfo = 2
```

## Restore Points

The scripts attempt to create a restore point before making changes.

Windows may show this warning:

```text
A new system restore point cannot be created because one has already been created within the past 1440 minutes.
```

This is normal. Windows limits restore point creation frequency by default.

## What This Does Not Do

These scripts do not make Windows anonymous.

They do not protect against:

```text
Browser fingerprinting
Website tracking
Google/social media tracking
ISP-level visibility
Telemetry from third-party apps
Tracking from accounts you log into
```

For stronger privacy, combine these scripts with:

```text
Strict tracking prevention in Microsoft Edge
A reputable content blocker
Encrypted DNS
Separate browser profiles
Virtual machines for risky testing
Good account separation
```

## What Not To Remove

Do not randomly remove core Windows components.

Avoid removing:

```text
Microsoft Store
App Installer
Windows Security
Microsoft Defender
Windows Update
Edge WebView2
.NET runtime packages
Visual C++ runtime packages
Microsoft.UI.Xaml
Microsoft.VCLibs
DesktopAppInstaller
```

Removing those can break updates, app installs, security features, or normal Windows functionality.

## Recommended Setup

Balanced privacy setup:

```text
Windows 11 debloated conservatively
Telemetry reduced to Required
Edge Tracking Prevention set to Strict
Defender enabled
Windows Update enabled
Microsoft Store dependencies preserved
Separate browser profiles for personal, school, and security research
VMs for pentesting/reverse engineering labs
```

## Disclaimer

Use these scripts at your own risk.

They are intended for personal Windows 11 systems you own and administer. Review the scripts before running them. Some changes may cause Windows settings to show:

```text
Some settings are managed by your organization
```

That is expected because the scripts use local policy registry keys.

These scripts are designed to be conservative, but every Windows installation is different. Create backups and test carefully.
