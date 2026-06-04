# Win11-PrivacyHardening.ps1
# Run PowerShell as Administrator.
# Default mode reduces telemetry safely.
# Use -Aggressive to also disable DiagTrack service and telemetry-related scheduled tasks.
# Use -EnterpriseEducationOff only if you are on Windows Enterprise/Education/Server.

param(
    [switch]$Aggressive,
    [switch]$EnterpriseEducationOff
)

function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "Run this script as Administrator." -ForegroundColor Red
        exit 1
    }
}

function Set-Dword {
    param(
        [string]$Path,
        [string]$Name,
        [int]$Value
    )

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
    Write-Host "Set $Path\$Name = $Value" -ForegroundColor Green
}

Assert-Admin

Write-Host "`nWindows 11 Privacy / Telemetry Hardening" -ForegroundColor Cyan

try {
    Checkpoint-Computer -Description "Before Windows 11 Privacy Hardening" -RestorePointType "MODIFY_SETTINGS"
    Write-Host "Restore point created." -ForegroundColor Green
} catch {
    Write-Host "Could not create restore point. Continuing..." -ForegroundColor Yellow
}

# ------------------------------------------------------------
# 1. Diagnostic data level
# ------------------------------------------------------------
# 0 = Diagnostic data off, officially only Enterprise/Education/Server
# 1 = Required diagnostic data, safest minimum for Windows 11 Home/Pro
# 3 = Optional diagnostic data

$telemetryLevel = 1

if ($EnterpriseEducationOff) {
    $telemetryLevel = 0
    Write-Host "`nUsing Diagnostic Data Off mode. Only use this on Enterprise/Education/Server." -ForegroundColor Yellow
} else {
    Write-Host "`nUsing Required diagnostic data mode. Best for Windows 11 Home/Pro." -ForegroundColor Yellow
}

Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" $telemetryLevel

# Limit optional diagnostic logs and crash dump collection
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "LimitDiagnosticLogCollection" 1
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "LimitDumpCollection" 1

# Disable feedback prompts
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DoNotShowFeedbackNotifications" 1

# ------------------------------------------------------------
# 2. Tailored experiences / personalized tips
# ------------------------------------------------------------
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" 0
Set-Dword "HKCU:\Software\Policies\Microsoft\Windows\CloudContent" "DisableTailoredExperiencesWithDiagnosticData" 1
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1

# ------------------------------------------------------------
# 3. Inking and typing data collection
# ------------------------------------------------------------
Set-Dword "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitTextCollection" 1
Set-Dword "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitInkCollection" 1
Set-Dword "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore" "HarvestContacts" 0

# ------------------------------------------------------------
# 4. Activity history
# ------------------------------------------------------------
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 0
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" 0

# ------------------------------------------------------------
# 5. Online speech recognition privacy
# ------------------------------------------------------------
Set-Dword "HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" "HasAccepted" 0

# ------------------------------------------------------------
# 6. App diagnostics access
# 2 = Force deny
# ------------------------------------------------------------
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsGetDiagnosticInfo" 2

# ------------------------------------------------------------
# 7. Optional aggressive mode
# ------------------------------------------------------------
if ($Aggressive) {
    Write-Host "`nAggressive mode enabled." -ForegroundColor Yellow

    # Disable Connected User Experiences and Telemetry service
    $services = @(
        "DiagTrack"
    )

    foreach ($svc in $services) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue

        if ($service) {
            try {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc -StartupType Disabled
                Write-Host "Disabled service: $svc" -ForegroundColor Green
            } catch {
                Write-Host "Could not disable service: $svc" -ForegroundColor Red
            }
        }
    }

    # Disable common telemetry / feedback scheduled tasks
    $tasks = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        "\Microsoft\Windows\Feedback\Siuf\DmClient",
        "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
    )

    foreach ($taskPath in $tasks) {
        try {
            $taskName = Split-Path $taskPath -Leaf
            $taskFolder = (Split-Path $taskPath -Parent) + "\"

            Disable-ScheduledTask -TaskPath $taskFolder -TaskName $taskName -ErrorAction Stop | Out-Null
            Write-Host "Disabled scheduled task: $taskPath" -ForegroundColor Green
        } catch {
            Write-Host "Task not found or could not disable: $taskPath" -ForegroundColor DarkYellow
        }
    }
}

Write-Host "`nDone. Restart your PC for everything to fully apply." -ForegroundColor Cyan
Write-Host "You may see 'Some settings are managed by your organization' because these are policy-based settings." -ForegroundColor Yellow