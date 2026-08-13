# Minimal UTF-8 (no BOM) logging replacement for a fresh file
$logDir = "C:\Users\Public\Documents\Logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

$logFile = Join-Path $logDir "OculusUpdate.log"

# ensure UTF-8 console/output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$logDir = "C:\Users\Public\Documents\Logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir "MetaUpdate.log"
if (-not (Test-Path $logFile)) { [System.IO.File]::WriteAllText($logFile, "", [System.Text.Encoding]::UTF8) }

function Log {
    param([string]$msg, [ConsoleColor]$color = [ConsoleColor]::Gray)

    # sanitize message
    $sanitized = $msg -replace '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', ''
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "$timestamp  $sanitized" + [Environment]::NewLine

    # append to UTF-8 file (no BOM)
    try { [System.IO.File]::AppendAllText($logFile, $line, [System.Text.Encoding]::UTF8) } catch { Add-Content -Path $logFile -Value $line -Encoding UTF8 }

    # also write to console so output appears like Tee-Object did
    Write-Host $line -NoNewline -ForegroundColor $color
}

Log "=== Oculus Driver Update Started ==="

# --- Helper: find driver root (Oculus or Meta Horizon) ---
$driverRoots = @(
    "C:\Program Files\Oculus\Support\oculus-drivers",
    "C:\Program Files\Meta Horizon\Support\oculus-drivers",
    "C:\Program Files\Meta Horizon\Support\oculus-drivers"  # duplicate safe-check
)
$driverRoot = $driverRoots | Where-Object { Test-Path $_ } | Select-Object -First 1

# --- PC Link staged update handling ---
$stagingRoot = "C:\Program Files\Oculus\Staging"
if (Test-Path $stagingRoot) {
    $stagedItems = Get-ChildItem $stagingRoot -Force -Recurse -ErrorAction SilentlyContinue
    if ($stagedItems -and $stagedItems.Count -gt 0) {
        Log "PC Link staged updates detected: $($stagedItems.Count) items."

        # short countdown to allow any UI to settle
        $countdown = 8
        Log "Waiting $countdown seconds before triggering update (closing client)..."
        Start-Sleep -Seconds $countdown

        # Close client to trigger OVRLibrarian
        Log "Closing Client/OculusClient processes to trigger update..."
        Get-Process -Name Client -ErrorAction SilentlyContinue | ForEach-Object {
            try { $_ | Stop-Process -Force -ErrorAction Stop; Log "Stopped process Client (PID $($_.Id))." } catch { Log "Failed to stop Client: $_" }
        }
        Get-Process -Name OculusClient -ErrorAction SilentlyContinue | ForEach-Object {
            try { $_ | Stop-Process -Force -ErrorAction Stop; Log "Stopped process OculusClient (PID $($_.Id))." } catch { Log "Failed to stop OculusClient: $_" }
        }

		# Wait for OVRLibrarian to start
		Log "Waiting up to 120s for OVRLibrarian.exe to start..."
		$librarian = $null
		for ($i = 0; $i -lt 120; $i++) {
			$librarian = Get-Process -Name OVRLibrarian -ErrorAction SilentlyContinue
			if ($librarian) { Log "OVRLibrarian detected (PID $($librarian.Id))."; break }
			Start-Sleep -Seconds 1
		}

		if ($librarian) {
			# Wait for OVRLibrarian to exit (apply updates) but also detect UAC prompt
			Log "Monitoring OVRLibrarian for completion (timeout 10 minutes) and watching for UAC..."
			$maxWait = 600
			$uacDetected = $false

			for ($j = 0; $j -lt $maxWait; $j++) {

				# 1) Detect UAC by Consent.exe process (most reliable)
				$consent = Get-Process -Name Consent -ErrorAction SilentlyContinue
				if ($consent) {
					Log "Detected UAC (Consent.exe) (PID $($consent.Id))."
					$uacDetected = $true
					break
				}

				# 2) Extra check: detect common UAC window title text (fallback)
				$uacWindow = Get-Process | Where-Object { $_.MainWindowTitle -match "Do you want to allow this app to make changes to your device" }
				if ($uacWindow) {
					Log "Detected UAC window title (PID $($uacWindow.Id))."
					$uacDetected = $true
					break
				}

				# 3) If librarian exited normally, break
				$librarian = Get-Process -Name OVRLibrarian -ErrorAction SilentlyContinue
				if (-not $librarian) {
					Log "OVRLibrarian exited normally."
					break
				}

				Start-Sleep -Seconds 1
			}

			if ($uacDetected) {
				Log "UAC detected while OVRLibrarian was running. Proceeding to run driver installer from elevated context."
				# fall through to driver install logic (do not wait for manual consent)
			} elseif ($librarian) {
				Log "OVRLibrarian still running after timeout; proceeding to driver step anyway."
			}
		} else {
			Log "OVRLibrarian did not start; proceeding to driver step."
		}

    } else {
        Log "No PC Link staged updates found."
    }
} else {
    Log "Staging directory not present."
}

# --- Driver update logic (run elevated, combine args) ---
if (-not $driverRoot) {
    Log "No driver root found. Skipping driver update."
    Log "=== Oculus Driver Update Completed (no driver root) ==="
    exit
}

Log "Using driver root: $driverRoot"

$driverExe   = Join-Path $driverRoot "oculus-driver.exe"
$versionFile = Join-Path $driverRoot "version.txt"
if (-not (Test-Path $driverExe) -or -not (Test-Path $versionFile)) {
    Log "Driver executable or version file missing. Skipping driver update."
    Log "=== Oculus Driver Update Completed (missing files) ==="
    exit
}

$newVersion = (Get-Content $versionFile -ErrorAction SilentlyContinue).Trim()
Log "New ODI Version: $newVersion"

$regPath = "HKLM:\SOFTWARE\WOW6432Node\Oculus VR, LLC\Oculus"
$currentVersion = (Get-ItemProperty -Path $regPath -Name "DriverVersion" -ErrorAction SilentlyContinue).DriverVersion
Log "Current Installed DriverVersion: $currentVersion"

# If versions match and no staged driver present, skip
$stagedDriverFolder = Join-Path $stagingRoot "oculus-drivers"
$stagedDriverPresent = Test-Path $stagedDriverFolder
if ($currentVersion -and ($currentVersion -eq $newVersion) -and -not $stagedDriverPresent) {
    Log "Versions match and no staged driver. No driver update needed."
    Log "=== Oculus Driver Update Completed (no update) ==="
    exit
}

Log "Driver version change detected. Running driver installer..."

# Build combined arguments and run installer elevated (script already elevated via scheduled task)
$installArgs = "--mode install-and-update-shortcuts --ODIVersion $newVersion"
Log "Running driver installer: $driverExe $installArgs"

$installer = Start-Process -FilePath $driverExe -ArgumentList $installArgs -PassThru

Log "Installer PID: $($installer.Id)"

Log "Waiting for driver installer to exit or reboot modal to appear (up to ~120 seconds)..."

$modalTitle = "Restart your computer?"
$modalDetected = $false

for ($i = 1; $i -le 240; $i++) {

    $modal = Get-Process | Where-Object { $_.MainWindowTitle -eq $modalTitle }
    if ($modal) {
        Log "Detected reboot modal '$modalTitle' (PID $($modal.Id))."
		Log "=== Oculus Driver Update Completed (rebooting...) ==="
        #$modalDetected = $true
		Restart-Computer -Force
        break
    }

    if ($installer.HasExited) {
        Log "Installer exited normally. No reboot modal appeared."
		
		# Close stale UAC prompt (Consent.exe) now that installer is done
		$consent = Get-Process -Name Consent -ErrorAction SilentlyContinue
		if ($consent) {
			Log "Detected stale UAC prompt (Consent.exe PID $($consent.Id)). Closing it now..."
			try { $consent.CloseMainWindow() | Out-Null } catch {}
			Start-Sleep -Milliseconds 3000

			# If still alive, force kill
			if (Get-Process -Id $consent.Id -ErrorAction SilentlyContinue) {
				Log "Consent.exe still present; terminating forcefully..."
				Stop-Process -Id $consent.Id -Force -ErrorAction SilentlyContinue
			}
		}
        break
    }

    Start-Sleep -Milliseconds 500
}

Log "=== Oculus Driver Update Completed (rebooting...) ==="
Restart-Computer -Force

#Log "=== Oculus Driver Update Completed (no reboot) ==="
exit
