# PCVR_ADB_Kiosk

Automates Meta Quest Link mode and launches a dedicated PCVR app using ADB and Task Scheduler. Designed for institutional deployments, it handles headset state, app focus, and edge-case recovery.

## Contents

- PCVR_Kiosk_Oculus.bat – Main automation script  
- PCVR_Kiosk_Oculus.xml – Task Scheduler import file

## Setup Instructions

### 1. Install ADB  
Download and extract SDK Platform-Tools for Windows:  
https://developer.android.com/tools/releases/platform-tools  
Example path: `C:\platform-tools`

### 2. Copy Files  
- Copy `.\platform-tools` to `[PathA]` (e.g., `C:\platform-tools`)  
- Copy `PCVR_Kiosk_*.bat` to `[PathB]` (e.g., `C:\Users\Public\Documents\Perspectus\`)  
- Make any adjustments to variables in the `.bat` file:
  - `adbPath`: Full path to `adb.exe`
  - `appExe`: Name of the PCVR app process
  - `metaLinkExe`: Meta Link PC app name
  - `edgeExe`: Browser to close (optional)
  - `appPath`: Full path or UWP shell reference to the PCVR app

### 3. Import Task Scheduler XML  
- Open Task Scheduler  
- Select “Import Task”  
- Choose `PCVR_Kiosk_Oculus.xml`  
- Modify:
  - **User Account**: In the “General” tab, update “When running the task, use the following user account” to match your Windows username  
  - **Triggers**: Confirm or adjust the user account and repetition interval  
  - **Actions**: Update the program path to match `[PathB]` where the `.bat` file resides

## Oculus Authorization Notes

**IMPORTANT:** Each HMD must be authorized with its dedicated PC.

1. Ensure the HMD is in **developer/debugging mode**  
   (currently only set via the Meta phone app)

2. Reboot the HMD

3. From command prompt:
```
C:\platform-tools\adb devices
```
If you see:
```
xxxxxxxxx  unauthorized
```
Do the following **while the Task Scheduler task is NOT running**:
```
C:\platform-tools\adb kill-server
C:\platform-tools\adb start-server
```

4. On the HMD, choose:  
**“Always allow from this computer”**

5. Reboot the HMD again

For large-scale deployments, it’s ideal to have:
- One person remoting into PCs to restart the ADB server
- Another person physically authorizing each PC on the HMD

## Adaptation Notes

To use this script for other PCVR apps or environments:

- Change `appExe` and `appPath` to match your app’s executable or UWP reference  
- Update `edgeExe` if you want to close a different browser to clear cached credentials  
- The same scheduled task and script can be used across all PCs, as long as each machine has the required files in the same location and uses consistent app configuration  
- Replace domain-specific usernames and paths in both `.bat` and `.xml` files

## Debugging Tips

- Add `timeout /t 2` after key commands to observe behavior during manual runs  
- Use `echo` statements to verify device state, ADB status, and app launch conditions  
- If Link mode fails to engage, check for Meta Horizon interference or USB instability

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0)  
You are free to use, modify, and redistribute this code, but derivative works must remain open-source under the same license. See the LICENSE file or visit:  
https://www.gnu.org/licenses/gpl-3.0.html
