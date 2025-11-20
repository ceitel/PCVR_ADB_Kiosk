@echo off
REM -----------------------------------------
REM Developed for the VR Lab, Department of Biomedical Sciences, Colorado State University
REM Author: Chad Eitel | License: GPL-3.0 | See README for details
REM Created: 2024-05-09 | Version: 0.9.0 | Last Updated: 2024-05-09
REM This script is licensed under the GNU General Public License v3.0 (GPL-3.0)
REM See LICENSE file in the repository or https://www.gnu.org/licenses/gpl-3.0.html

REM Description:
REM Automates launching the Pico 4E streaming client and a dedicated PCVR app using ADB.
REM It is a variant of the Oculus-based PCVR_Kiosk_Oculus.bat script and may be less tested or feature-complete.
REM Designed for institutional deployments (e.g., CSU's ceiling-mounted PCVR stations).
REM Requires SDK Platform-Tools for Windows: https://developer.android.com/tools/releases/platform-tools
REM -----------------------------------------

REM ****begin variables****

REM the path of the adb.exe from the above extracted platform-tools. Example: C:\platform-tools\adb.exe
SET "adbPath=C:\platform-tools\adb.exe"

REM the name of the dedicated PC VR app process. Example: bv.exe
SET "appExe=bv.exe"

REM the full path to exe or UWP app reference for the dedicated PC VR app to be run in Kiosk mode. Example: shell:appsfolder\Perspectus.VR.edu.release_r5ms9sfmeekqa!PerspectusViewer
SET "appPath=shell:appsfolder\Perspectus.VR.edu.release_5r2c0dmngbwzj!PerspectusViewer"

REM the android streaming service (HMD specific). Example: com.picoxr.bstreamassistant/com.picovr.stream.StreamingService:com.picoxr.bstreamassistant:picoStream
SET "streamingService=com.picoxr.bstreamassistant/com.picovr.stream.StreamingService:com.picoxr.bstreamassistant:picoStream"

REM the name of steamVR's .exe, which must be running before launching bv.exe...
SET "steamVR=vrmonitor.exe"

REM .\adb.exe shell am start -n com.picoxr.bstreamassistant/com.picovr.streamingapplication.ui.MainActivity -a android.intent.action.MAIN -c android.intent.category.LAUNCHER

REM the package name for the streaming app
SET "streamingAppPackage=com.picoxr.bstreamassistant"

REM the activity for the streaming app
SET "streamingAppActivity=com.picovr.streamingapplication.ui.MainActivity"

REM the intent action
SET "intentAction=android.intent.action.MAIN"

REM the intent category
SET "intentCategory=android.intent.category.LAUNCHER"

REM ****end of variables****

REM -----------------------------------------

echo waiting for startup to settle...
timeout /t 60

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
%adbPath% shell pidof com.picoxr.bstreamassistant >nul
IF %ERRORLEVEL% NEQ 0 (
    echo Streaming Client is not running.
	tasklist | find /I "%appExe%" >nul
	if errorlevel 1 (
		echo %appExe% is not running. Presenting business streaming UI to user...
		"%adbPath%" shell am start -n %streamingAppPackage%/%streamingAppActivity% -a %intentAction% -c %intentCategory%
		goto waitThenLoop
	) else (
		goto killApp
	)
) ELSE (
	echo Streaming Client is running.
	goto checkSteamVR
)

:checkSteamVR
tasklist | find /I "%steamVR%" >nul
if errorlevel 1 (
	echo %steamVR% is not running.
	goto killApp
) else (
	echo %steamVR% is running.
	goto startApp
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
tasklist | find /I "%appExe%" >nul
if not errorlevel 1 (
	echo %appExe% is running, closing it now...
	taskkill /F /IM "%appExe%" >nul 2>nul
) else (
	echo %appExe% is not running.
)
goto waitThenLoop

:waitThenLoop
timeout /t 10

goto start
