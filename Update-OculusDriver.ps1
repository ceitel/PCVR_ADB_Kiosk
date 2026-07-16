# Update-OculusDriver.ps1

<#
README — Oculus Driver Auto‑Update Script

This script checks for and installs updated Oculus/Meta Horizon PC drivers
at user logon. It is designed to run silently via Windows Task Scheduler.

FUNCTIONAL OVERVIEW
• Locates the installed Oculus/Meta Horizon driver root directory.
• Reads the new driver version from version.txt.
• Reads the currently installed driver version from the registry.
• If versions match, the script exits with no action.
• If a version change is detected, it launches oculus-driver.exe
  interactively to perform the update.
• After launching the installer, the script polls for the reboot prompt
  (“Restart your computer?”). If detected, the machine is rebooted
  automatically.
• All activity is logged to:
  C:\Users\Public\Documents\Logs\OculusDriverUpdate.log

SCHEDULED TASK DETAILS
A companion Scheduled Task (Update‑OculusDriver.xml) runs this script:
• Trigger: At logon of user CVMBSDOM\azh205 (with a 3‑minute delay)
• Principal: LocalSystem (S‑1‑5‑18), highest privileges
• Action: powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script>

INTENDED USE
Deploy this script + task to ensure Oculus/Meta Horizon drivers remain
current across managed systems without requiring manual user intervention.

This script is licensed under the GNU General Public License v3.0 (GPL-3.0)
See LICENSE file in the repository or https://www.gnu.org/licenses/gpl-3.0.html

#>


$logDir = "C:\Users\Public\Documents\Logs"
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir "OculusDriverUpdate.log"

function Log {
    param($msg)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$timestamp  $msg" | Tee-Object -FilePath $logFile -Append
}

Log "=== Oculus Driver Update Started ==="

$driverRoots = @(
    "C:\Program Files\Oculus\Support\oculus-drivers",
    "C:\Program Files\Meta Horizon\Support\oculus-drivers"
)
$driverRoot = $driverRoots | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $driverRoot) { Log "No driver root found."; exit }

Log "Using driver root: $driverRoot"

$driverExe   = Join-Path $driverRoot "oculus-driver.exe"
$versionFile = Join-Path $driverRoot "version.txt"
if (-not (Test-Path $driverExe) -or -not (Test-Path $versionFile)) {
    Log "Driver executable or version file missing."; exit
}

$newVersion = Get-Content $versionFile
Log "New ODI Version: $newVersion"

$regPath = "HKLM:\SOFTWARE\WOW6432Node\Oculus VR, LLC\Oculus"
$currentVersion = (Get-ItemProperty -Path $regPath -Name "DriverVersion" -ErrorAction SilentlyContinue).DriverVersion
Log "Current Installed DriverVersion: $currentVersion"

if ($currentVersion -and ($currentVersion -eq $newVersion)) {
    Log "Versions match. No update needed."
    Log "=== Oculus Driver Update Completed (no update) ==="
    exit
}

Log "Version change detected. Running installer (interactive)..."

$installer = Start-Process -FilePath $driverExe `
    -ArgumentList "--ODIVersion $newVersion" `
    -PassThru

Log "Installer PID: $($installer.Id)"

$modalTitle = "Restart your computer?"
$modalDetected = $false

# Poll for the reboot modal
for ($i = 1; $i -le 240; $i++) {  # ~120 seconds
    $modal = Get-Process | Where-Object { $_.MainWindowTitle -eq $modalTitle }

    if ($modal) {
        Log "Detected reboot modal '$modalTitle' (PID $($modal.Id))."
		Log "=== Oculus Driver Update Completed (rebooting...) ==="
        Restart-Computer -Force
        exit
    }

    if ($installer.HasExited) {
        Log "Installer exited normally. No reboot modal appeared."
        Log "=== Oculus Driver Update Completed (no reboot) ==="
        exit
    }

    Start-Sleep -Milliseconds 500
}

Log "Installer did not exit and no modal appeared. Doing nothing."
Log "=== Oculus Driver Update Completed (no reboot) ==="
