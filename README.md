# PCVR_ADB_Kiosk
Automation & Diagnostics Toolkit for Institutional PCVR Deployments

This package contains a suite of automation and diagnostic tools developed for large-scale PCVR deployments using Meta Quest headsets, with partial compatibility for other Android-based XR devices. These tools were created and field-tested in the VR lab of the Department of Biomedical Sciences at Colorado State University, supporting ceiling-mounted PCVR stations and multi-headset XR teaching environments.

The toolkit streamlines:
- Headset state management
- PCVR app launching
- Remote diagnostics
- Telemetry collection
- Network and OS drift detection
- Automated monitoring via Task Scheduler

All tools are shared openly to support similar deployments at other institutions.

Author: Chad Eitel  
Institution: Colorado State University – Department of Biomedical Sciences, VR Lab  
License: GNU General Public License v3.0 (GPL-3.0)

---

# Contents

## PCVR Automation Scripts
- PCVR_Kiosk_Oculus.bat  
  Main automation script for Meta Quest headsets. Handles app launching, Meta Link state management, and kiosk-style behavior.

- PCVR_Kiosk_Oculus.xml  
  Task Scheduler import file for automated kiosk operation.

- PCVR_Kiosk_Pico.bat  
  Variant script for Pico 4E headsets. Integrates Pico Streaming Assistant and SteamVR checks.  
  (Note: Pico support is functional but not as fully validated as Quest.)

## XR Telemetry & Diagnostics
- QuestRemoteScan.ps1  
  Remote telemetry collector using PowerShell Remoting + ADB.  
  **Fully supports Meta Quest devices** (Quest 3, Quest Pro, Quest 2).  
  Some collected fields may also work on other Android XR devices such as Pico, Samsung XR, Vive XR Elite, and Lenovo VRX, but only Quest devices are officially supported.

  Outputs:
  - Timestamped CSV with strict schema
  - verbose.log (engineering diagnostics)
  - diff.log (historical drift tracking)

---

# Setup Instructions

## 1. Install ADB
Download and extract Android SDK Platform-Tools:  
https://developer.android.com/tools/releases/platform-tools

Example path:  
C:\platform-tools

## 2. Copy Files
- Copy platform-tools to your preferred location  
- Copy PCVR_Kiosk_*.bat and QuestRemoteScan.ps1 to a shared tools directory  
  (e.g., C:\Users\Public\Documents\Perspectus\)

Update variables inside the .bat files:
- adbPath – full path to adb.exe  
- appExe – PCVR app process name  
- metaLinkExe – Meta Link PC app name (Oculus only)  
- edgeExe – optional browser to close  
- appPath – full path or UWP shell reference to the PCVR app  

## 3. Import Task Scheduler XML
1. Open Task Scheduler  
2. Select “Import Task”  
3. Choose PCVR_Kiosk_Oculus.xml  
4. Update:
   - User Account  
   - Triggers (interval, user)  
   - Actions (path to .bat file)

---

# Oculus / Meta Authorization Notes

Each Meta headset must be authorized with its dedicated PC.

1. Enable Developer Mode in the Meta mobile app  
2. Reboot the headset  
3. On the PC:  
   adb devices  
4. If you see “unauthorized”:  
   adb kill-server  
   adb start-server  
5. Put on the headset → choose “Always allow from this computer”  
6. Reboot the headset again  

For large deployments:
- One person restarts ADB servers remotely  
- Another person authorizes each headset physically  

---

# Pico Variant Notes

PCVR_Kiosk_Pico.bat is adapted for Pico 4E headsets.

- Uses Pico Streaming Assistant  
- Checks SteamVR state before launching apps  
- Behavior is similar to the Oculus script but with Pico-specific logic  
- Still evolving and may lack some edge-case handling  

---

# QuestRemoteScan.ps1 – XR Telemetry & Diagnostics

This script performs remote XR telemetry collection using PowerShell Remoting and ADB.

## Officially Supported Devices
- Meta Quest 3  
- Meta Quest Pro  
- Meta Quest 2  

## Partial Compatibility
Some fields may also populate correctly on:
- Pico 4 / Neo series  
- Samsung Galaxy XR  
- Vive XR Elite  
- Lenovo VRX  
- Other Android XR devices with ADB enabled  

(Only Quest devices are fully validated.)

## Collected Fields (CSV Schema)
1. ComputerName  
2. UUID  
3. RuntimeVersion  
4. DeviceModel  
5. DeviceSerial  
6. DeviceOSVersion  
7. WiFiMAC  
8. RandomizedMAC (true/false)  
9. WiFiState  
10. SSID  
11. CaptivePortal  

## Outputs
- results_YYYYMMDD_HHMMSS.csv  
  Timestamped telemetry snapshot

- verbose.log  
  Full diagnostic output (engineering use)

- diff.log  
  Historical record of differences between scans  
  Each entry is timestamped and separated for readability

## Requirements
- Admin privileges  
- PowerShell Remoting enabled  
- ADB installed  
- Computer list in AZH205AdbComputers.txt  
- Output directory: C:\AZH205Logs  

---

# License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0).  
You are free to use, modify, and redistribute this code, but derivative works must remain open-source under the same license.

See LICENSE.txt or:  
https://www.gnu.org/licenses/gpl-3.0.html
