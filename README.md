PCVR_ADB_Kiosk

This package contains automation and diagnostic tools developed for institutional PCVR deployments using Meta Quest and Pico headsets. Scripts were created and field-tested in the VR lab of the Department of Biomedical Sciences at Colorado State University, supporting large-scale, ceiling-mounted PCVR stations.

The tools streamline headset state management, app launching, and remote diagnostics using ADB and Task Scheduler. They are shared openly to support similar deployments at other institutions.

Author: Chad Eitel  
Institution: Colorado State University – Department of Biomedical Sciences, VR Lab  
License: GNU General Public License v3.0 (GPL-3.0)

Contents:
- PCVR_Kiosk_Oculus.bat – Main automation script for Meta Quest
- PCVR_Kiosk_Oculus.xml – Task Scheduler import file
- PCVR_Kiosk_Pico.bat – Variant script for Pico 4E HMDs
- QuestRemoteScan.ps1 – Remote diagnostics and inventory tool for Meta Quest 3

Setup Instructions:

1. Install ADB
   - Download and extract SDK Platform-Tools for Windows:
     https://developer.android.com/tools/releases/platform-tools
   - Example path: C:\platform-tools

2. Copy Files
   - Copy .\platform-tools to [PathA] (e.g., C:\platform-tools)
   - Copy PCVR_Kiosk_*.bat to [PathB] (e.g., C:\Users\Public\Documents\Perspectus\)
   - Adjust variables in the .bat file:
     - adbPath: Full path to adb.exe
     - appExe: Name of the PCVR app process
     - metaLinkExe: Meta Link PC app name (Oculus only)
     - edgeExe: Browser to close (optional)
     - appPath: Full path or UWP shell reference to the PCVR app

3. Import Task Scheduler XML
   - Open Task Scheduler
   - Select “Import Task”
   - Choose PCVR_Kiosk_Oculus.xml
   - Modify:
     - User Account: Update “When running the task, use the following user account” to match your Windows username
     - Triggers: Confirm or adjust the user account and repetition interval
     - Actions: Update the program path to match [PathB] where the .bat file resides

Oculus Authorization Notes:

IMPORTANT: Each HMD must be authorized with its dedicated PC.

1. Ensure the HMD is in developer/debugging mode (set via the Meta phone app)
2. Reboot the HMD
3. From command prompt:
   C:\platform-tools\adb devices
   If you see:
   xxxxxxxxx  unauthorized
   Do the following while the Task Scheduler task is NOT running:
   C:\platform-tools\adb kill-server
   C:\platform-tools\adb start-server
4. On the HMD, choose: “Always allow from this computer”
5. Reboot the HMD again

For large-scale deployments:
- One person should remote into PCs to restart the ADB server
- Another person should physically authorize each PC on the HMD

Pico Variant Notes:

PCVR_Kiosk_Pico.bat is a variant of the Oculus script adapted for Pico 4E headsets.  
It uses Pico-specific streaming services and checks for SteamVR before launching the PCVR app.

- Still under refinement and may lack some edge-case handling present in the Oculus script
- Licensed under GPL-3.0 and intended for institutional kiosk deployments

QuestRemoteScan.ps1 – Remote Diagnostics Tool:

Collects Meta Quest 3 serial numbers and telemetry from multiple PCs using PowerShell remoting and ADB.  
Outputs include UUID, Meta OS version, MAC address, randomized MAC status, SSID, Wi-Fi state, and firewall rule status.

- Requires admin privileges and PowerShell remoting enabled
- Reads computer list from AZH205Computers.txt
- Saves results to timestamped CSV in C:\AZH205Logs
- Compares latest two scans and logs differences to diff.log

License:

This project is licensed under the GNU General Public License v3.0 (GPL-3.0)  
You are free to use, modify, and redistribute this code, but derivative works must remain open-source under the same license.  
See LICENSE.txt included in this package or visit: https://www.gnu.org/licenses/gpl-3.0.html
