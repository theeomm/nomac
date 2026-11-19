<#
.SYNOPSIS
    Local Windows-to-NoMac Flutter + Shorebird Wrapper.
.DESCRIPTION
    Starts a NoMac instance, clones or updates https://github.com/theeomm/nomac on ~/drive/nomac,
    syncs the local project, runs start.sh, and displays/opens the remote macOS desktop URL.
.EXAMPLE
    .\nomac-dev.ps1 -GitName "Jane Doe" -GitEmail "jane@example.com" -Watch
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$GitName,

    [Parameter(Mandatory = $true)]
    [string]$GitEmail,

    [switch]$Watch
)

$ErrorActionPreference = "Stop"

$ProjectFolder = Split-Path -Leaf (Get-Location)
$RemoteProjectDir = "`$HOME/drive/src/$ProjectFolder"
$SetupRepo = "https://github.com"

Write-Host "==> 1. Starting or reconnecting to NoMac instance..." -ForegroundColor Cyan
nomac start

Write-Host "==> 2. Ensuring theeomm/nomac setup repo is cloned & up-to-date on ~/drive/nomac..." -ForegroundColor Cyan
$CloneOrPullCmd = "mkdir -p `"`$HOME/drive`"; if [ ! -d `"`$HOME/drive/nomac/.git`" ]; then echo 'Cloning theeomm/nomac...'; git clone '$SetupRepo' `"`$HOME/drive/nomac`"; else echo 'Pulling latest theeomm/nomac...'; git -C `"`$HOME/drive/nomac`" pull --ff-only; fi"
nomac exec --wait 120 -- bash -lc $CloneOrPullCmd

Write-Host "==> 3. Syncing local project ($ProjectFolder) to ~/drive/src/$ProjectFolder..." -ForegroundColor Cyan
nomac sync . --delete

Write-Host "==> 4. Provisioning ephemeral Flutter & Shorebird environment..." -ForegroundColor Cyan
$EnvExports = @()
if ($env:SHOREBIRD_TOKEN) { $EnvExports += "export SHOREBIRD_TOKEN='$($env:SHOREBIRD_TOKEN)';" }
if ($env:GH_TOKEN) { $EnvExports += "export GH_TOKEN='$($env:GH_TOKEN)';" }
if ($env:FIREBASE_SERVICE_ACCOUNT_BASE64) { $EnvExports += "export FIREBASE_SERVICE_ACCOUNT_BASE64='$($env:FIREBASE_SERVICE_ACCOUNT_BASE64)';" }
$EnvPrefix = ($EnvExports -join " ")

$BootstrapCmd = "$EnvPrefix source `"`$HOME/drive/nomac/start.sh`" `"$GitName`" `"$GitEmail`" `"$RemoteProjectDir`""
nomac exec --wait 900 -- zsh -lc $BootstrapCmd

Write-Host "==> 5. Desktop & Session Access:" -ForegroundColor Green
try {
    # Opens the macOS desktop in your default browser and prints any CLI output/URL
    nomac desktop
}
catch {
    Write-Warning "Could not launch desktop automatically. Check your session at: https://nomac.app"
}
Write-Host "Dashboard URL: https://nomac.app" -ForegroundColor Yellow

if ($Watch) {
    Write-Host "==> 6. Starting real-time file sync (Press Ctrl+C to stop watching)..." -ForegroundColor Cyan
    nomac sync . --watch --delete
}
else {
    Write-Host "==> Done! Run 'nomac ssh' to open a shell or 'nomac stop' to terminate the instance." -ForegroundColor Green
}
