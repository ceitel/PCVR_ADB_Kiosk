@echo off
REM -----------------------------------------
REM Developed for the VR Lab, Department of Biomedical Sciences, Colorado State University
REM Author: Chad Eitel | License: GPL-3.0 | See README for details
REM Created: 2024-05-09 | Version: 1.3.2 | Last Updated: 2025-11-20
REM This script is licensed under the GNU General Public License v3.0 (GPL-3.0)
REM See LICENSE file in the repository or https://www.gnu.org/licenses/gpl-3.0.html

REM Change Log:
REM - 2025-11-20 CE: Fixed issue where Meta Horizon would launch after Link mode and steal focus from Meta OS,
REM                  preventing headset from entering Link mode normally and requiring manual USB replug.
REM                  Also added device sleep to start of script for easier debugging.
REM - 2025-09-11: Increased startup settle time from 10s to 60s.
REM - 2024-10-24 CE: Fixed edge case where a PC reboot while the HMD was awake but idle would cause PVR to launch in 2D mode.
REM                  Added check to ensure OculusClient.exe is running before launching PVR.
REM - 2024-10-02 CE: Updated appPath/hash for PVR 1.8.377 (hash: 5r2c0dmngbwzj)

REM Description:
REM Automates launching Meta Quest Link mode and a dedicated PCVR app using ADB and Task Scheduler.
REM Designed for unattended VR deployments in institutional environments.
REM Requires SDK Platform-Tools for Windows: https://developer.android.com/tools/releases/platform-tools
REM -----------------------------------------

REM ****begin variables****

REM the path of the adb.exe from the above extracted platform-tools. Example: C:\platform-tools\adb.exe
SET "adbPath=C:\platform-tools\adb.exe"

REM the name of the dedicated PC VR app process. Example: bv.exe
SET "appExe=bv.exe"

REM the name of the Meta Link PC App:
set "metaLinkExe=OculusClient.exe"

REM the default web browser that we will close to clear cached credentials when device goes to sleep
set "edgeExe=msedge.exe"

REM the full path to exe or UWP app reference for the dedicated PC VR app to be run in Kiosk mode. Example:	shell:appsfolder\Perspectus.VR.edu.release_r5ms9sfmeekqa!PerspectusViewer

SET "appPath=shell:appsfolder\Perspectus.VR.edu.release_5r2c0dmngbwzj!PerspectusViewer"

REM ****end of variables****

REM -----------------------------------------

echo waiting for startup to settle...
timeout /t 60

REM if PVR isn't running we'll put the HMD to sleep now...
tasklist | find /I "%appExe%" >nul
if errorlevel 1 (
	echo %appExe% is not running, putting device to sleep...
	%adbPath% shell input keyevent KEYCODE_SLEEP
) else (
	echo %appExe% is running, skipping sleep command
)

timeout /t 2
goto start


:start
"%adbPath%" get-state 1>nul 2>&1
if errorlevel 1 (
    echo ADB daemon is not running.
	goto waitThenLoop
) else (
    echo ADB daemon is running.
	goto checkAwake
)

:checkAwake
for /f "tokens=2 delims==" %%a in ('%adbPath% shell dumpsys power ^| findstr "mWakefulness="') do (
    if "%%a" == "Awake" (
        echo HMD is awake.
	goto checkLink
    ) else (
        echo HMD is asleep.
		goto killApp
    )
)

:checkLink
%adbPath% shell pidof com.oculus.xrstreamingclient >nul
IF %ERRORLEVEL% NEQ 0 (
	echo Streaming Client is not running.
	tasklist | find /I "%appExe%" >nul
	if errorlevel 1 (
		echo %appExe% is not running. 
		echo Starting com.oculus.xrstreamingclient after delay...
		timeout /t 5
		%adbPath% shell am start -S com.oculus.xrstreamingclient/.MainActivity
		goto waitThenLoop
	) else (
		goto killApp
	)
) ELSE (
	echo Streaming Client is running.
	tasklist | find /I "%metaLinkExe%" >nul
	if errorlevel 1 (
		echo %metaLinkExe% is not running. Waiting for Meta Link PC app.
		goto killApp
	) else (
		echo %metaLinkExe% is running.
		goto startApp
	)
)

:startApp
tasklist | find /I "%appExe%" >nul
if errorlevel 1 (
	echo %appExe% is not running, starting it now...
	start %appPath%
) else (
	echo %appExe% is already running.
)
goto waitThenLoop

:killApp
%adbPath% shell pidof com.oculus.xrstreamingclient >nul
IF %ERRORLEVEL% NEQ 0 (
    echo com.oculus.xrstreamingclient is not running.
) ELSE (
	echo com.oculus.xrstreamingclient is running. Killing it now...
	%adbPath% shell am force-stop com.oculus.xrstreamingclient
)
tasklist | find /I "%appExe%" >nul
if not errorlevel 1 (
	echo %appExe% is running, closing it now...
	taskkill /F /IM "%appExe%" >nul 2>nul
) else (
	echo %appExe% is not running.
)
tasklist | find /I "%edgeExe%" >nul
if not errorlevel 1 (
	echo %edgeExe% is running, closing it now...
	taskkill /F /IM "%edgeExe%" >nul 2>nul
) else (
	echo %edgeExe% is not running.
)
goto waitThenLoop

:waitThenLoop
timeout /t 5

goto start
