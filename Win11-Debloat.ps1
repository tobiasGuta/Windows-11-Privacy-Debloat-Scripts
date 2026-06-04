# Win11-Debloat-Updated.ps1
# Run PowerShell as Administrator.
# Default mode is dry-run. Use -Apply to actually remove apps.

param(
    [switch]$Apply
)

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Run this script as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "`nWindows 11 Debloat Script" -ForegroundColor Cyan

if (-not $Apply) {
    Write-Host "DRY RUN MODE: Nothing will be removed." -ForegroundColor Yellow
    Write-Host "To actually remove apps, run: .\Win11-Debloat.ps1 -Apply`n"
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
                Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -AllUsers -ErrorAction Stop
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
Write-Host "`nDone." -ForegroundColor Cyan