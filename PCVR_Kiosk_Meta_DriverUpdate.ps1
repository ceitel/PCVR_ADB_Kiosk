# PCVR_Kiosk_Meta_DriverUpdate.ps1
# Runs the Meta/Oculus driver installer in skip-if-installed mode at each logon.
# Root-aware (Meta Horizon vs Oculus). No staging dependency.

# README: 
## Create task in task scheduler to "Start a program" "At logon of any user", "Run with highest privileges" as (any) admin, "Run whether user is logged on or not"
## Program/script: powershell.exe
## Add arguments: -ExecutionPolicy Bypass -File "C:\Path\to\this\.ps1"


$LogDir  = "C:\ProgramData\PCVR_Kiosk_Meta"
$LogPath = Join-Path $LogDir "MetaDriverUpdate.log"

if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
Add-Content $LogPath "`n[$timestamp] --- Driver update check (skip-if-installed) ---"

# --- Determine root folder ---
$MetaRoot   = "C:\Program Files\Meta Horizon"
$OculusRoot = "C:\Program Files\Oculus"

if (Test-Path $MetaRoot) {
    $Root = $MetaRoot
    Add-Content $LogPath "Using Meta Horizon root: $Root"
}
else {
    $Root = $OculusRoot
    Add-Content $LogPath "Using Oculus root: $Root"
}

# --- Build Support paths ---
$SupportRoot = Join-Path $Root "Support\oculus-drivers"
$VersionFile = Join-Path $SupportRoot "version.txt"
$DriverExe   = Join-Path $SupportRoot "oculus-driver.exe"

# --- Read required version (safe read) ---
try {
    $version = (Get-Content $VersionFile -Raw).Trim()
    Add-Content $LogPath "Required driver version (from Support): '$version'"
}
catch {
    Add-Content $LogPath "ERROR reading version.txt: $($_.Exception.Message)"
    Add-Content $LogPath "--- Driver update check finished ---"
    return
}

# --- Run installer in skip-if-installed mode with timing ---
$sw = [System.Diagnostics.Stopwatch]::StartNew()

try {
    Add-Content $LogPath "Running driver installer (skip-if-installed)..."
    Start-Process $DriverExe "--skip-if-installed --ODIVersion $version" -Verb RunAs -Wait
    $sw.Stop()

    Add-Content $LogPath "Installer completed (or skipped if already installed)."
    Add-Content $LogPath "Installer runtime: $($sw.Elapsed.TotalMilliseconds) ms"
}
catch {
    $sw.Stop()
    Add-Content $LogPath "ERROR running driver installer: $($_.Exception.Message)"
    Add-Content $LogPath "Installer runtime before failure: $($sw.Elapsed.TotalMilliseconds) ms"
}

Add-Content $LogPath "--- Driver update check finished ---"