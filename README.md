# PCVR_ADB_Kiosk

Automates Meta Quest Link mode and launches a dedicated PCVR app using ADB and Task Scheduler. Designed for institutional deployments, it handles headset state, app focus, and edge-case recovery.

## Contents

- PCVR_Kiosk_Oculus.bat – Main automation script  
- PCVR_Kiosk_Oculus.xml – Task Scheduler import file

## Setup Instructions

1. Install ADB  
   Download and extract SDK Platform-Tools for Windows:  
   https://developer.android.com/tools/releases/platform-tools  
   Example path: C:\platform-tools

2. Edit Variables in `.bat`  
   Open `PCVR_Kiosk_Oculus.bat` and update the following:

   - adbPath: Full path to adb.exe  
     Example: C:\platform-tools\adb.exe

   - appExe: Name of the PCVR app process  
     Example: bv.exe

   - metaLinkExe: Name of the Meta Link PC app  
     Default: OculusClient.exe

   - edgeExe: Name of the default browser to close (optional)  
     Example: msedge.exe, chrome.exe, etc.

   - appPath: Full path or UWP shell reference to the PCVR app  
     Example: shell:appsfolder\YourAppFamilyName!AppViewer

3. Import Task Scheduler XML  
   - Open Task Scheduler  
   - Select “Import Task”  
   - Choose `PCVR_Kiosk_Oculus.xml`  
   - Modify:
     - **User Account**: In the “General” tab, update the “When running the task, use the following user account” field to match your Windows username. This ensures the task runs with the correct permissions.
     - **Command**: In the “Actions” tab, update the path to point to your `.bat` file.
     - **Triggers**: In the “Triggers” tab, adjust logon behavior or repetition interval if needed.


## Adaptation Notes

To use this script for other PCVR apps or environments:

- Change appExe and appPath to match your app’s executable or UWP reference.
- Update edgeExe if you want to close a different browser to clear cached credentials.
- For multi-station deployments, the same scheduled task and script can be used across all PCs, as long as each machine has the required files in the same location and uses consistent app configuration.
- Replace domain-specific usernames and paths in both `.bat` and `.xml` files.

## Debugging Tips

- Add `timeout /t 2` after key commands to observe behavior during manual runs.
- Use `echo` statements to verify device state, ADB status, and app launch conditions.
- If Link mode fails to engage, check for Meta Horizon interference or USB instability.

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0).  
You are free to use, modify, and redistribute this code, but derivative works must remain open-source under the same license. This ensures that improvements to the automation logic remain accessible to the community.
