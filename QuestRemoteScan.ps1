<#
.SYNOPSIS
Collects Android‑based XR headset serial numbers and telemetry from multiple PCs using ADB and PowerShell remoting.

.DESCRIPTION
This script supports Meta Quest, Pico, Galaxy XR, Vive XR Elite, Lenovo VRX, and any Android‑based XR headset.
It performs remote diagnostics across a list of computers, extracting headset and system metadata.

.LICENSE
Licensed under the GNU General Public License v3.0 (GPL-3.0)

.AUTHOR
Chad Eitel
#>

param(
    [switch]$NoExit = $false
)

################# BEGIN CONFIG #################
$outputDir       = "C:\AZH205Logs"
$pcListFile      = "AZH205AdbComputers.txt"
$adbPath         = "C:\Users\Public\Documents\Perspectus\platform-tools\adb.exe"

$computerListPath = Join-Path $PSScriptRoot $pcListFile
$verboseLogFilePath = Join-Path $outputDir "verbose.log"
$diffLogFilePath    = Join-Path $outputDir "diff.log"
################# END CONFIG ###################

# Ensure output/log directory exists
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Unified verbose logger
function Log {
    param(
        [string]$Message,
        [ValidateSet("Info","Warn","Error")]
        [string]$Level = "Info"
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "Info"  { Write-Host    $line }
        "Warn"  { Write-Warning $line }
        "Error" { Write-Error   $line }
    }

    $line | Out-File -FilePath $verboseLogFilePath -Append -Encoding UTF8
}

# Diff-only logger
function Write-Diff {
    param([string]$Message)
    $Message | Out-File -FilePath $diffLogFilePath -Append -Encoding UTF8
}

Log "==============================================="
Log "XR Headset Diagnostics and Telemetry Collector"
Log "==============================================="
Log "Running with Administrator privileges..."
Log "Using ADB path: $adbPath"

# Validate computer list
if (-not (Test-Path $computerListPath)) {
    Log "Computer list NOT found at: $computerListPath" -Level Error
    if ($NoExit) { Read-Host "Press Enter to exit..." }
    exit 1
}

Log "Computer list file FOUND at: $computerListPath"

# Read list
$computers = Get-Content $computerListPath | Where-Object { $_.Trim() -ne "" }
Log "Found $($computers.Count) computers in list."

# Test remoting
Log "Testing PowerShell remoting..."
try {
    Test-WSMan -ErrorAction Stop | Out-Null
    Log "PowerShell remoting is enabled."
} catch {
    Log "Attempting to enable PowerShell remoting..." -Level Warn
    try {
        Enable-PSRemoting -Force -ErrorAction Stop
        Log "Successfully enabled PowerShell remoting."
    } catch {
        Log "Failed to enable PowerShell remoting: $($_.Exception.Message)" -Level Error
        if ($NoExit) { Read-Host "Press Enter to exit..." }
        exit 1
    }
}

# Global results list
$global:pcList = @()
Log "Initialized empty device list."

# Helper for unreachable PCs
function Add-PCNotFound {
    param([string]$ComputerName)
    $global:pcList += [PSCustomObject]@{
        ComputerName    = $ComputerName
        UUID            = "PC not found."
        RuntimeVersion  = ""
        DeviceModel     = ""
        DeviceSerial    = ""
        DeviceOSVersion = ""
        WiFiMAC         = ""
        RandomizedMAC   = ""
        WiFiState       = ""
        SSID            = ""
        CaptivePortal   = ""
    }
}

# Remote ADB + telemetry collector
function Get-RemoteDeviceInfo {
    param ([string]$ComputerName)

    Log "Connecting to $ComputerName..."

    try {
        # Ping test
        if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
            Log "$ComputerName is not responding to ping." -Level Warn
            Add-PCNotFound $ComputerName
            return
        }

        # WMI test
        try {
            Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName -ErrorAction Stop | Out-Null
        } catch {
            Log "$ComputerName - WMI access failed: $($_.Exception.Message)" -Level Warn
            Add-PCNotFound $ComputerName
            return
        }

        # Remote scriptblock
        $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            param($adbPath)

            $deviceInfo = @()

            # PC UUID
            $computerUUID = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID

            # XR runtime detection
            $runtimeCandidates = @(
                "C:\Program Files\Oculus\Support\oculus-runtime\OVRServer_x64.exe",
                "C:\Program Files\Pico Streaming Assistant\StreamingAssistant.exe",
                "C:\Program Files\SamsungXR\Runtime\SamsungXRRuntime.exe"
            )

            $RuntimeVersion = "Not Found"
            foreach ($path in $runtimeCandidates) {
                try {
                    $file = Get-WmiObject CIM_DataFile -Filter "Name='$($path.Replace('\','\\'))'"
                    if ($file) {
                        $RuntimeVersion = $file.Version
                        break
                    }
                } catch {}
            }

            # ADB check
            if (-not (Test-Path $adbPath)) {
                $deviceInfo += @{
                    ComputerName    = $env:COMPUTERNAME
                    UUID            = $computerUUID
                    RuntimeVersion  = $RuntimeVersion
                    DeviceModel     = "ADB not found."
                    DeviceSerial    = ""
                    DeviceOSVersion = ""
                    WiFiMAC         = ""
                    RandomizedMAC   = ""
                    WiFiState       = ""
                    SSID            = ""
                    CaptivePortal   = ""
                }
                return $deviceInfo
            }

            # Device list
            $devices = & $adbPath devices 2>&1
            $deviceFound = $false

            foreach ($line in $devices) {
                if ($line -match '^(\S+)\s+device') {
                    $deviceFound = $true
                    $serial = $matches[1]

                    function ADBShell { param($S,$Cmd) & $adbPath -s $S shell $Cmd 2>&1 }

                    # Model
                    $model = (ADBShell $serial "getprop ro.product.model").Trim()

                    # OS version (fallback across vendors)
                    $osProps = @(
                        "ro.vros.build.version",        # Meta
                        "ro.build.version.release",     # Pico / Android
                        "ro.system.build.version"       # fallback
                    )

                    $DeviceOSVersion = "Unknown"
                    foreach ($prop in $osProps) {
                        $val = ADBShell $serial "getprop $prop"
                        if ($val -and $val.Trim() -ne "") {
                            $DeviceOSVersion = $val.Trim()
                            break
                        }
                    }

                    # MAC
                    $macOutput = ADBShell $serial "ip addr show wlan0"
                    $macMatch  = $macOutput | Select-String -Pattern "link/ether ([0-9a-f:]{17})"
                    $WiFiMAC   = if ($macMatch) { $macMatch.Matches[0].Groups[1].Value } else { "Unknown" }

                    # Randomized MAC
                    #$wifiMetrics = ADBShell $serial "dumpsys wifi" | findstr /C:"useRandomizedMac"
                    #$RandomizedMAC = $null
                    #foreach ($wm in ($wifiMetrics -split "`n")) {
                    #    if ($wm -match "useRandomizedMac") {
                    #        $RandomizedMAC = ($wm -match "useRandomizedMac=true")
                    #    }
                    #}
					
					# Factory MAC (burned-in hardware MAC)
					$factoryMac = (ADBShell $serial "getprop ro.boot.wifimacaddr").Trim()

					# Determine if randomized MAC is active
					if ($factoryMac -and $WiFiMAC -and ($factoryMac -ne $WiFiMAC)) {
						$RandomizedMAC = $true
					} else {
						$RandomizedMAC = $false
					}

                    # SSID + state
                    $wifiInfo = ADBShell $serial "dumpsys wifi"
                    $ssidMatch = $wifiInfo | Select-String -Pattern 'mWifiInfo SSID: "([^"]+)"'
                    $SSID = if ($ssidMatch) { $ssidMatch.Matches[0].Groups[1].Value } else { "Unknown" }

                    $stateMatch = $wifiInfo | Select-String -Pattern 'Supplicant state: (\w+)'
                    $WiFiState = if ($stateMatch) { $stateMatch.Matches[0].Groups[1].Value } else { "Unknown" }

                    # Captive portal
                    #$netInfo = ADBShell $serial "dumpsys connectivity"
                    #$CaptivePortal = ($netInfo -match "CAPTIVE_PORTAL")
					# Captive portal detection
					$netInfo = ADBShell $serial "dumpsys connectivity" | Out-String
					$CaptivePortal = ($netInfo -match "CAPTIVE_PORTAL")

                    # Add record
                    $deviceInfo += @{
                        ComputerName    = $env:COMPUTERNAME
                        UUID            = $computerUUID
                        RuntimeVersion  = $RuntimeVersion
                        DeviceModel     = $model
                        DeviceSerial    = $serial
                        DeviceOSVersion = $DeviceOSVersion
                        WiFiMAC         = $WiFiMAC
                        RandomizedMAC   = $RandomizedMAC
                        WiFiState       = $WiFiState
                        SSID            = $SSID
                        CaptivePortal   = $CaptivePortal
                    }
                }
            }

            if (-not $deviceFound) {
                $deviceInfo += @{
                    ComputerName    = $env:COMPUTERNAME
                    UUID            = $computerUUID
                    RuntimeVersion  = $RuntimeVersion
                    DeviceModel     = "Device not found."
                    DeviceSerial    = ""
                    DeviceOSVersion = ""
                    WiFiMAC         = ""
                    RandomizedMAC   = ""
                    WiFiState       = ""
                    SSID            = ""
                    CaptivePortal   = ""
                }
            }

            return $deviceInfo
        } -ArgumentList $adbPath -ErrorAction Stop

        if ($result) {
            foreach ($d in $result) {
                # Enforce strict column order
                $global:pcList += [PSCustomObject]@{
                    ComputerName    = $d.ComputerName
                    UUID            = $d.UUID
                    RuntimeVersion  = $d.RuntimeVersion
                    DeviceModel     = $d.DeviceModel
                    DeviceSerial    = $d.DeviceSerial
                    DeviceOSVersion = $d.DeviceOSVersion
                    WiFiMAC         = $d.WiFiMAC
                    RandomizedMAC   = $d.RandomizedMAC
                    WiFiState       = $d.WiFiState
                    SSID            = $d.SSID
                    CaptivePortal   = $d.CaptivePortal
                }
            }
            Log "Processed $ComputerName. Total records: $($global:pcList.Count)"
        } else {
            Log "No results returned from $ComputerName" -Level Warn
            Add-PCNotFound $ComputerName
        }
    }
    catch {
        Log "Failed to connect to $ComputerName - $($_.Exception.Message)" -Level Warn
        Add-PCNotFound $ComputerName
    }
}

# Begin scan
Log "Starting device scan across all computers..."
foreach ($c in $computers) {
    Get-RemoteDeviceInfo -ComputerName $c.Trim()
}

# Prepare CSV output
$outputPath = Join-Path $outputDir "results_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
Log "CSV will be saved to: $outputPath"

# Test write access
try {
    $testFile = Join-Path $outputDir "write_test.tmp"
    "test" | Out-File -FilePath $testFile -ErrorAction Stop
    Remove-Item $testFile -Force
    Log "Output directory is writable."
} catch {
    Log "Output directory not writable. Falling back to script directory." -Level Warn
    $outputPath = Join-Path $PSScriptRoot "results_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
}

# Export CSV
if ($pcList.Count -gt 0) {
    try {
        $pcList | Export-Csv -Path $outputPath -NoTypeInformation -ErrorAction Stop
        Log "Successfully exported $($pcList.Count) records to: $outputPath"
    } catch {
        Log "Failed to export CSV: $($_.Exception.Message)" -Level Error
    }
} else {
    Log "No devices found on any computers. No CSV created." -Level Warn
}

# Diff last two results
Log "Running diff on last two results files..."

$csvFiles = Get-ChildItem -Path $outputDir -Filter "results*.csv" |
            Sort-Object LastWriteTime -Descending | Select-Object -First 2

if ($csvFiles.Count -lt 2) {
    Write-Diff "No previous results available for comparison."
    Log "Less than two results files found. Skipping diff."
} else {
    $file1 = Import-Csv $csvFiles[0].FullName
    $file2 = Import-Csv $csvFiles[1].FullName

    $comparison =
        foreach ($row1 in $file1) {
            $row2 = $file2 | Where-Object ComputerName -eq $row1.ComputerName
            if ($row2) {
                foreach ($prop in $row1.PSObject.Properties.Name) {
                    if ($prop -ne "ComputerName" -and
                        $row1.$prop -ne $row2.$prop -and
                        $row1.$prop -ne '' -and
                        $row2.$prop -ne '') {

                        [PSCustomObject]@{
                            ComputerName = $row1.ComputerName
                            Property     = $prop
                            'Prev Value' = $row2.$prop
                            'Curr Value' = $row1.$prop
                        }
                    }
                }
            }
        }

	# Append a separator for readability
	Write-Diff ""
	Write-Diff "------------------------------------------------------------"
	Write-Diff ""

	$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

	if ($comparison) {
		Write-Diff "[$timestamp] Changes detected between the last two scans:"
		Write-Diff ""

		foreach ($change in $comparison) {
			$line = "$($change.ComputerName): $($change.Property) changed from '$($change.'Prev Value')' to '$($change.'Curr Value')'"
			Write-Diff $line
		}

		Log "Diff written to diff.log"
	} else {
		Write-Diff "[$timestamp] No changes detected between the last two scans."
		Log "No changes detected"
	}
}

Log "Script completed! Results saved to: $outputPath"

# Close all remoting sessions
Get-PSSession | Remove-PSSession -ErrorAction SilentlyContinue

# Kill any leftover adb processes
Get-Process adb -ErrorAction SilentlyContinue | Stop-Process -Force

# If running under Task Scheduler (non-interactive), exit immediately
try {
    if (-not $Host.UI.RawUI.KeyAvailable) {
        exit 0
    }
} catch {
    # RawUI may not exist in non-interactive hosts → also exit
    exit 0
}

# Interactive pause
if ($NoExit) {
    Read-Host "Press Enter to exit..."
}
