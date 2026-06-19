# Win11-Debloat-Updated.ps1
# Run PowerShell as Administrator.
# Default mode is dry-run. Use -Apply to actually remove apps and apply tweaks.

param(
    [switch]$Apply
)

# --- HELPER FUNCTIONS ---
function Set-RegistryKey {
    param($Path, $Name, $Value, $PropertyType = "DWord")
    if ($Apply) {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force -ErrorAction SilentlyContinue | Out-Null
        }
        try {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $PropertyType -Force -ErrorAction Stop
            Write-Host "Applied Registry Tweak: $Name" -ForegroundColor Green
        } catch {
            Write-Host "Failed Registry Tweak: $Name" -ForegroundColor Red
        }
    } else {
        Write-Host "Found Tweak (Dry-Run): Will set $Name to $Value" -ForegroundColor DarkGray
    }
}

function Disable-WinService {
    param($Name, $DisplayName)
    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($service) {
        if ($Apply) {
            try {
                Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
                Set-Service -Name $Name -StartupType Disabled -ErrorAction Stop
                Write-Host "Disabled Service: $DisplayName" -ForegroundColor Green
            } catch {
                Write-Host "Failed to disable Service: $DisplayName" -ForegroundColor Red
            }
        } else {
            Write-Host "Found Service (Dry-Run): Will disable $DisplayName" -ForegroundColor DarkGray
        }
    }
}

# --- INITIALIZATION ---
# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Run this script as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Windows 11 Full Debloat Script ===" -ForegroundColor Cyan

if (-not $Apply) {
    Write-Host "DRY RUN MODE: Nothing will be removed or changed." -ForegroundColor Yellow
    Write-Host "To actually apply changes, run: .\Win11-Debloat-Updated.ps1 -Apply`n"
} else {
    Write-Host "APPLY MODE: Changes will be made to your system.`n" -ForegroundColor Red
}

# Optional restore point
if ($Apply) {
    try {
        Write-Host "Creating restore point... (This might take a moment)" -ForegroundColor Cyan
        Checkpoint-Computer -Description "Before Win11 Debloat" -RestorePointType "MODIFY_SETTINGS"
        Write-Host "Restore point created.`n" -ForegroundColor Green
    } catch {
        Write-Host "Could not create restore point. Continuing...`n" -ForegroundColor Yellow
    }
}

# --- PART 1: SYSTEM TWEAKS & PRIVACY ---
Write-Host "--- Processing System & Privacy Tweaks ---" -ForegroundColor Cyan

# 1. Stop "Sponsored" Apps from Reinstalling (Windows Consumer Experience)
Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1

# 2. Disable Bing Web Search in the Start Menu
Set-RegistryKey -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1

# 3. Disable Telemetry and Data Collection
Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
Disable-WinService -Name "DiagTrack" -DisplayName "Connected User Experiences and Telemetry"

# 4. Disable Widgets (News and Interests)
Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0

Write-Host "" # Spacer

# --- PART 2: APPX APP REMOVAL ---
Write-Host "--- Processing App Removal ---" -ForegroundColor Cyan

# Edit this list. Remove anything you want to keep.
$AppxPatterns = @(
    "Microsoft.BingNews",
    "Microsoft.BingWeather",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.People",
    "Microsoft.Todos",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.Xbox*",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "Microsoft.YourPhone",
    "Microsoft.MixedReality.Portal",
    "Microsoft.PowerAutomateDesktop"
)

$totalApps = $AppxPatterns.Count
$currentApp = 0

foreach ($pattern in $AppxPatterns) {
    $currentApp++
    $percent = [math]::Round(($currentApp / $totalApps) * 100)

    # Update the visual progress bar at the top of the console
    Write-Progress -Activity "Debloating Windows" -Status "Processing: $pattern ($currentApp of $totalApps)" -PercentComplete $percent

    # Remove for existing users
    $packages = Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue

    foreach ($pkg in $packages) {
        if ($Apply) {
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                Write-Host "Removed Installed: $($pkg.Name)" -ForegroundColor Green
            } catch {
                Write-Host "Failed to remove Installed: $($pkg.Name)" -ForegroundColor Red
            }
        } else {
            Write-Host "Found Installed (Dry-Run): $($pkg.Name)" -ForegroundColor DarkGray
        }
    }

    # Remove provisioned package so it does not return for new users
    # We use SilentlyContinue here to bypass the "Class not registered" COM error
    $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like $pattern }

    foreach ($prov in $provisioned) {
        if ($Apply) {
            try {
                # BUG FIXED HERE: Removed the invalid -AllUsers parameter
                Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop
                Write-Host "Removed Provisioned: $($prov.DisplayName)" -ForegroundColor Green
            } catch {
                Write-Host "Failed to remove Provisioned: $($prov.DisplayName)" -ForegroundColor Red
            }
        } else {
            Write-Host "Found Provisioned (Dry-Run): $($prov.DisplayName)" -ForegroundColor DarkGray
        }
    }
}

# Close the progress bar
Write-Progress -Activity "Debloating Windows" -Completed
Write-Host "`nDone. A system restart is recommended to apply registry changes." -ForegroundColor Cyan
