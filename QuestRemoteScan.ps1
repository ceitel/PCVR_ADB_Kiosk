<#
.SYNOPSIS
Collects Meta Quest 3 serial numbers and telemetry from multiple PCs using ADB and PowerShell remoting.

.DESCRIPTION
This script is a companion to PCVR_Kiosk_Oculus.bat and PCVR_Kiosk_Pico.bat.
It performs remote diagnostics across a list of computers, extracting headset and system metadata including UUID, Meta OS version, MAC address, randomized MAC status, SSID, Wi-Fi state, and firewall rule status.

.DEVELOPMENT
Developed for the VR Lab, Department of Biomedical Sciences, Colorado State University

.AUTHOR
Chad Eitel

.VERSION
Created: 2024-05-09
Version: 1.0.0
Last Updated: 2025-11-20

.LICENSE
Licensed under the GNU General Public License v3.0 (GPL-3.0)
See LICENSE file or https://www.gnu.org/licenses/gpl-3.0.html

.CHANGELOG
2025-11-20: Added diff logging between scans and improved fallback logic for unreachable PCs
2024-10-12: Added randomized MAC detection and SSID parsing
2024-09-30: Initial version with remote ADB scan and CSV export
#>

# Define variables...
# Configuration
$outputDir = "C:\AZH205Logs"
$computerListPath = "C:\AZH205Logs\AZH205AdbComputers.txt"
$diffLogFilePath = "C:\AZH205Logs\diff.log"



# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
	Write-Host "Script requires admin privileges. Attempting to elevate..."
	$CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $Args
	Start-Process -FilePath PowerShell.exe -Verb RunAs -ArgumentList $CommandLine
	Exit
}

# Script to collect Meta Quest 3 serial numbers using ADB from multiple computers
param(
	[switch]$NoExit = $false
)

# If script is double-clicked (no parameters passed), set NoExit to true
if ($MyInvocation.Line -eq "") {
	$NoExit = $true
}


if (-not (Test-Path $outputDir)) {
	New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}
$outputPath = Join-Path $outputDir "results_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

Write-Host "CSV will be saved to: $outputPath"

# Correct ADB path for your environment
$adbPath = "C:\Users\Public\Documents\Perspectus\platform-tools\adb.exe"

# Clear the screen for better readability
Clear-Host

Write-Host "==============================================="
Write-Host "Meta Quest 3 Serial Number Collection Script"
Write-Host "===============================================`n"

Write-Host "Running with Administrator privileges...`n"
Write-Host "Using ADB path: $adbPath`n"

# Check if computer list exists
if (-not (Test-Path $computerListPath)) {
	Write-Error "Computer list not found at: $computerListPath"
	Write-Host "`nPress Enter to exit..."
	Read-Host
	exit 1
}

# Read computer list
$computers = Get-Content $computerListPath | Where-Object { $_.Trim() -ne "" }
Write-Host "Found $($computers.Count) computers in list.`n"

# Test PowerShell remoting
Write-Host "Testing PowerShell remoting..."
try {
	$testResult = Test-WSMan -ErrorAction Stop
	Write-Host "PowerShell remoting is enabled.`n"
} catch {
	Write-Host "Attempting to enable PowerShell remoting..."
	try {
		Enable-PSRemoting -Force -ErrorAction Stop
		Write-Host "Successfully enabled PowerShell remoting.`n"
	} catch {
		Write-Error "Failed to enable PowerShell remoting. Error: $($_.Exception.Message)"
		Write-Host "`nPress Enter to exit..."
		Read-Host
		exit 1
	}
}

$global:pcList = @()
Write-Host "Initialized empty device list"

# Function to run ADB command remotely and get device info
function Get-RemoteDeviceInfo {
	param (
		[string]$ComputerName
	)

	Write-Host "Connecting to $ComputerName..."
	
	try {
		# Test if computer is online
		if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
			Write-Warning "$ComputerName is not responding to ping"
			
			$global:pcList += [PSCustomObject]@{
				ComputerName = $ComputerName
				UUID = "PC not found."
			}
			return
		}

		# Test WMI connection
		try {
			$null = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName -ErrorAction Stop
		} catch {
			Write-Warning "$ComputerName - WMI access failed: $($_.Exception.Message)"
			$global:pcList += [PSCustomObject]@{
				ComputerName = $ComputerName
				UUID = "WMI access failed."
			}
			return
		}

		$result = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
			param($adbPath)
			
			# Get Computer UUID first, regardless of device presence
			Write-Host "Getting Computer UUID..."
			$computerUUID = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
			Write-Host "Computer UUID: $computerUUID"
			
			# Get Meta Quest Link Version using WMI
			Write-Host "Getting Meta Quest Link Version..."
			$filePath = "C:\Program Files\Oculus\Support\oculus-runtime\OVRServer_x64.exe"
			try {
				$file = Get-WmiObject CIM_DataFile -Filter "Name='$($filePath.Replace('\','\\'))'"
				if ($file) {
					$questLinkVersion = $file.Version
					Write-Host "Found Oculus version: $questLinkVersion"
				} else {
					$questLinkVersion = "Not Found"
					Write-Host "OVRServer_x64.exe not found"
				}
			} catch {
				$questLinkVersion = "Error Reading Version"
				Write-Host "Error getting version info: $($_.Exception.Message)"
			}
			
			Write-Host "Checking ADB on $env:COMPUTERNAME..."
			
			# Verify ADB exists
			if (-not (Test-Path $adbPath)) {
				Write-Warning "ADB not found at specified path: $adbPath"
				Write-Host "Directory contents:"
				Get-ChildItem (Split-Path $adbPath) -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "- $_" }
				# Create base device info with just computer name and UUID
				$deviceInfo = @()
				$deviceInfo += @{
					ComputerName = $env:COMPUTERNAME
					UUID = $computerUUID
					ModelNumber = "ADB not found."
				}
					return $deviceInfo
			}
			
			Write-Host "ADB found. Testing connection..."
			
			try {
				# Test ADB
				$adbTest = & $adbPath version 2>&1
				Write-Host "ADB version output: $adbTest"
				
				# Get list of devices
				Write-Host "Getting device list..."
				$devices = & $adbPath devices 2>&1
				Write-Host "ADB devices output: $devices"
				
				$deviceInfo = @()
				$deviceFound = $false
				
				foreach ($line in $devices) {
					if ($line -match '^(\S+)\s+device') {
						$deviceFound = $true
						$serialNumber = $matches[1]
						Write-Host "Found device: $serialNumber"
						
						# Get device status
						$status = & $adbPath -s $serialNumber get-state 2>&1
						Write-Host "Device status: $status"
						
						# Get product name
						$productName = & $adbPath -s $serialNumber shell getprop ro.product.name 2>&1
						Write-Host "Product name: $productName"
						
						# Get model number
						$modelNumber = & $adbPath -s $serialNumber shell getprop ro.product.model 2>&1
						Write-Host "Model number: $modelNumber"
						
						# Get Meta OS Version
						Write-Host "Getting Meta OS Version..."
						$metaOS = & $adbPath -s $serialNumber shell "getprop ro.vros.build.version" 2>&1
						$metaOS = if ($metaOS -is [string]) { $metaOS.Trim() } else { "Unknown" }
						Write-Host "Meta OS Version: $metaOS"
						
						# Get MAC address from wlan0 interface
						Write-Host "Getting MAC address..."
						$macAddress = & $adbPath -s $serialNumber shell "ip addr show wlan0" 2>&1
						$macMatch = $macAddress | Select-String -Pattern "link/ether ([0-9a-f:]{17})" -AllMatches
						$macAddress = if ($macMatch.Matches.Count -gt 0) { $macMatch.Matches[0].Groups[1].Value } else { "Unknown" }
						Write-Host "MAC Address: $macAddress"
						
						# Get the Wifi metrics information
						$wifiMetrics = & $adbPath -s $serialNumber shell "dumpsys wifi" | findstr /C:"useRandomizedMac"

						# Initialize the variable to hold the last useRandomizedMac status
						$lastUseRandomizedMac = $null

						# Split the wifiMetrics output into lines and get the last useRandomizedMac value
						$wifiMetricsLines = $wifiMetrics -split "`n"
						foreach ($line in $wifiMetricsLines) {
							if ($line -match "useRandomizedMac") {
								$lastUseRandomizedMac = if ($line -match "useRandomizedMac=true") { $true } else { $false }
							}
						}

						# Output the result
						if ($lastUseRandomizedMac -ne $null) {
							Write-Host "The last connection event used randomized MAC: $lastUseRandomizedMac"
						} else {
							Write-Host "No connection events found or unable to determine MAC usage."
						}


						# Get the Wi-Fi information
						$wifiInfo = & $adbPath -s $serialNumber shell "dumpsys wifi"

						# Extract the SSID
						$ssidMatch = $wifiInfo | Select-String -Pattern 'mWifiInfo SSID: "([^"]+)"'
						Write-Host "SSIDMatch: $ssidMatch"
						
						$ssid = if ($ssidMatch -and $ssidMatch.Matches.Count -gt 0) { $ssidMatch.Matches[0].Groups[1].Value } else { "Unknown" }

						# Extract the Supplicant state
						$supplicantStateMatch = $wifiInfo | Select-String -Pattern 'Supplicant state: (\w+)'
						$supplicantState = if ($supplicantStateMatch -and $supplicantStateMatch.Matches.Count -gt 0) { $supplicantStateMatch.Matches[0].Groups[1].Value } else { "Unknown" }

						# Output the SSID and Supplicant state
						Write-Host "SSID: $ssid"
						Write-Host "Supplicant State: $supplicantState"
						
						$networkInfo = & $adbPath shell "dumpsys connectivity"
						$captivePortalExists = if ($networkInfo -match "CAPTIVE_PORTAL") { $true } else { $false }
						Write-Host "CAPTIVE_PORTAL exists: $captivePortalExists"
						
						$deviceInfo += @{
							ComputerName = $env:COMPUTERNAME
							UUID = $computerUUID
							QuestLinkVersion = $questLinkVersion
							ModelNumber = if ($modelNumber) { $modelNumber.Trim() } else { "Unknown" }
							SerialNumber = $serialNumber
							MetaOS = $metaOS
							MACAddress = $macAddress
							randomized = $lastUseRandomizedMac
							SSID = $ssid
							WiFiState = $supplicantState
							captivePortal = $captivePortalExists
						}
					}
				}
				
				# Only add computer with empty device info if no devices were found
				if (-not $deviceFound) {
					Write-Host "No devices found, adding computer info only"
					$deviceInfo += @{
						ComputerName = $env:COMPUTERNAME
						UUID = $computerUUID
						QuestLinkVersion = $questLinkVersion
						ModelNumber = "Device not found."
					}
				}
				
				return $deviceInfo
			}
			catch {
				Write-Warning "Error running ADB commands: $($_.Exception.Message)"
				return $null
			}
		} -ArgumentList $adbPath -ErrorAction Stop

		if ($result) {
			if ($result.Count -gt 0) {
				Write-Host "Processing $($result.Count) records from $ComputerName"
				foreach ($device in $result) {
					Write-Host "Adding record for $($device.ComputerName) to list"
					$global:pcList += [PSCustomObject]@{
						ComputerName = $device.ComputerName
						UUID = $device.UUID
						QuestLinkVersion = $device.QuestLinkVersion
						Model = $device.ModelNumber
						Serial = $device.SerialNumber
						MetaOS = $device.MetaOS
						MACAddress = $device.MACAddress
						randomized = $device.randomized
						SSID = $device.SSID
						WiFiState = $device.WiFiState
						captivePortal = $device.captivePortal
					}
				}
				Write-Host "Successfully processed $ComputerName"
				Write-Host "Total records in list: $($global:pcList.Count)"
			} else {
				Write-Host "No records found on $ComputerName"
				$global:pcList += [PSCustomObject]@{
					ComputerName = $ComputerName
					UUID = "PC not found."
				}
			}
		} else {
			Write-Host "No results returned from $ComputerName"
			$global:pcList += [PSCustomObject]@{
				ComputerName = $ComputerName
				UUID = "PC not found."
			}
		}
	}
	catch {
		Write-Warning "Failed to connect to $ComputerName - $($_.Exception.Message)"
		Write-Host "Detailed error: $($_.Exception.Message)" -ForegroundColor Red
		$global:pcList += [PSCustomObject]@{
			ComputerName = $ComputerName
			UUID = "PC not found."
		}
	}
}

# Process each computer
Write-Host "`nStarting device scan across all computers...`n"
foreach ($computer in $computers) {
	Get-RemoteDeviceInfo -ComputerName $computer.Trim()
	Write-Host "" # Add a blank line between computers
}

# Export to CSV
Write-Host "`nAttempting to export data..."
Write-Host "Output directory: $outputDir"
Write-Host "Full output path: $outputPath"

# Verify output directory exists and is writable
try {
	if (-not (Test-Path $outputDir)) {
		Write-Host "Creating output directory..."
		New-Item -ItemType Directory -Path $outputDir -Force -ErrorAction Stop | Out-Null
		Write-Host "Directory created successfully"
	}
	
	# Test write access
	Write-Host "Testing write access to directory..."
	$testFile = Join-Path $outputDir "test.txt"
	"test" | Out-File -FilePath $testFile -ErrorAction Stop
	Remove-Item $testFile -ErrorAction SilentlyContinue
	Write-Host "Directory is writable"
} catch {
	Write-Warning "Failed to access or write to output directory: $($_.Exception.Message)"
	Write-Host "Attempting to use script directory instead..."
	$outputPath = Join-Path $PSScriptRoot "quest_serials_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
	Write-Host "New output path: $outputPath"
}

if ($pcList.Count -gt 0) {
	try {
		Write-Host "`nWriting data to CSV..."
		$pcList | Export-Csv -Path $outputPath -NoTypeInformation -ErrorAction Stop
		Write-Host "Successfully exported $($pcList.Count) devices to: $outputPath"
		
		# Verify file was created
		if (Test-Path $outputPath) {
			Write-Host "Verified: CSV file exists at specified location"
			Write-Host "File size: $((Get-Item $outputPath).Length) bytes"
		} else {
			Write-Warning "Warning: CSV file was not found after export"
		}
	} catch {
		Write-Warning "Failed to export CSV: $($_.Exception.Message)"
		
		# Try alternative location
		try {
			$altPath = Join-Path $env:USERPROFILE "Desktop\quest_serials_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
			Write-Host "Attempting to save to desktop instead: $altPath"
			$pcList | Export-Csv -Path $altPath -NoTypeInformation -ErrorAction Stop
			Write-Host "Successfully saved to desktop: $altPath"
			$outputPath = $altPath
		} catch {
			Write-Error "Failed to save to alternative location: $($_.Exception.Message)"
		}
	}
} else {
	Write-Warning "No devices found on any computers. No CSV will be created."
}

# Display the contents that would be in the CSV
Write-Host "`nData that should be in the CSV:"
$pcList | Format-Table -AutoSize

# Display results in console
Write-Host "`nDevice Summary:"
$pcList | Format-Table -AutoSize

Write-Host "`nScript completed! Results have been saved to: $outputPath"



Write-Output "First task completed."
 

 Write-Output "Second task running..." 
 

# Get the two most recent CSV files starting with 'ping_results'
$csvFiles = Get-ChildItem -Path $outputDir -Filter "results*.csv" | Sort-Object LastWriteTime -Descending | Select-Object -First 2

# Ensure there are at least two CSV files
if ($csvFiles.Count -lt 2) {
	Write-Output "Less than two 'ping_results' CSV files found in the directory."
	return
}

# Import the content of the two most recent CSV files
$file1 = Import-Csv $csvFiles[0].FullName
$file2 = Import-Csv $csvFiles[1].FullName

# Get the current date and time
$currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Compare rows where ComputerName matches and ignore the ScanTime column
$comparison = foreach ($row1 in $file1) {
    $row2 = $file2 | Where-Object { $_.ComputerName -eq $row1.ComputerName }
    if ($row2) {
        $changesFound = $false
        $changes = foreach ($property in $row1.PSObject.Properties.Name) {
            if ($property -ne 'ComputerName' -and $row1.$property -ne $row2.$property -and $row1.$property -ne '' -and $row2.$property -ne '') {
                $changesFound = $true
                [PSCustomObject]@{
                    'ComputerName' = $row1.ComputerName
                    'Property' = $property
                    'prev Value' = $row2.$property
                    'curr Value' = $row1.$property
                }
            }
        }
        if ($changesFound) {
            $changes
        }
    }
}

$currentDateTime = Get-Date

# Prepare the log entries
if ($comparison) {
    $logEntries = $comparison | Format-Table -AutoSize | Out-String

    # Append the log entries to the log file
	Add-Content -Path $diffLogFilePath -Value "Changes found $($currentDateTime):"
    Add-Content -Path $diffLogFilePath -Value $logEntries
} else {
    Add-Content -Path $diffLogFilePath -Value "No changes found $($currentDateTime).`r`n"
}

# Output the differences
if ($comparison) {
	Write-Output "Changes found $($currentDateTime):"
    $comparison | Format-Table -AutoSize
} else {
    Write-Output "No changes found $($currentDateTime)"
}

#Write-Host -NoNewLine 'Press any key to continue...';
#$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
