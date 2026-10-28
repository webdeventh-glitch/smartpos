<#
.SYNOPSIS
    Builds and packages Smart POS System for Windows release distribution.
.DESCRIPTION
    1. Compiles Flutter Windows Release binary if needed.
    2. Packages standalone portable zip to dist/SmartPOS_Portable_v1.0.zip
    3. Builds installer using Inno Setup (ISCC.exe) if available.
#>

param(
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path "$PSScriptRoot\.."
$ReleaseDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$DistDir = Join-Path $ProjectRoot "dist"
$IssFile = Join-Path $PSScriptRoot "smartpos_setup.iss"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       Smart POS System - Release Packaging Pipeline      " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Compile or verify Release directory
$StarterExe = Join-Path $ReleaseDir "desktop_starter.exe"
$PosExe = Join-Path $ReleaseDir "pos.exe"

if (-not $SkipBuild) {
    Write-Host "[1/3] Building fresh Flutter Windows Release binary..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
    flutter build windows --release
    Pop-Location
} else {
    Write-Host "[1/3] Skipping Flutter build (-SkipBuild specified)..." -ForegroundColor Yellow
}

if (Test-Path $StarterExe) {
    $now = Get-Date
    (Get-Item $StarterExe).LastWriteTime = $now

    Copy-Item $StarterExe $PosExe -Force
    (Get-Item $PosExe).LastWriteTime = $now

    $SmartPosExe = Join-Path $ReleaseDir "SmartPOS.exe"
    Copy-Item $StarterExe $SmartPosExe -Force
    (Get-Item $SmartPosExe).LastWriteTime = $now

    $RootSmartPos = Join-Path $ProjectRoot "SmartPOS.exe"
    Copy-Item $StarterExe $RootSmartPos -Force
    (Get-Item $RootSmartPos).LastWriteTime = $now
}

Write-Host "[1/3] Windows Release binary ready in build/windows/x64/runner/Release" -ForegroundColor Green

# 2. Prepare Dist directory
if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

# 3. Create Start_SmartPOS.bat launcher in Release directory
$LauncherPath = Join-Path $ReleaseDir "Start_SmartPOS.bat"
$LauncherContent = @"
@echo off
title Smart POS System
cd /d "%~dp0"
start "" "%~dp0pos.exe"
exit
"@
Set-Content -Path $LauncherPath -Value $LauncherContent -Encoding ASCII

# 4. Create Standalone Portable Zip
$ZipPath = Join-Path $DistDir "SmartPOS_Portable_v1.0.zip"
Write-Host "[2/3] Creating Portable Distribution Zip: $ZipPath..." -ForegroundColor Yellow
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipPath -CompressionLevel Optimal
$ZipSizeMB = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)
Write-Host "       Portable ZIP ready! ($ZipSizeMB MB)" -ForegroundColor Green

# 5. Compile Inno Setup Installer if ISCC is installed
Write-Host "[3/3] Looking for Inno Setup Compiler (ISCC.exe)..." -ForegroundColor Yellow
$IsccPaths = @(
    "ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "${env:LOCALAPPDATA}\Programs\Inno Setup 6\ISCC.exe"
)

$IsccExe = $null
foreach ($path in $IsccPaths) {
    $found = Get-Command $path -ErrorAction SilentlyContinue
    if ($found) {
        $IsccExe = $found.Source
        break
    }
    if (Test-Path $path) {
        $IsccExe = $path
        break
    }
}

if ($IsccExe) {
    Write-Host "       Found Inno Setup at: $IsccExe" -ForegroundColor Cyan
    Write-Host "       Compiling Windows Installer (SmartPOS_Setup_v1.0.exe)..." -ForegroundColor Yellow
    & $IsccExe $IssFile
    $SetupExe = Join-Path $DistDir "SmartPOS_Setup_v1.0.exe"
    if (Test-Path $SetupExe) {
        $SetupSizeMB = [math]::Round((Get-Item $SetupExe).Length / 1MB, 2)
        Write-Host "       Installer successfully generated! ($SetupSizeMB MB)" -ForegroundColor Green
    }
} else {
    Write-Host "       Inno Setup (ISCC.exe) not found on system PATH." -ForegroundColor DarkYellow
    Write-Host "       Skipping setup .exe compilation (Portable ZIP is fully functional)." -ForegroundColor Gray
    Write-Host "       To build installer, install Inno Setup 6 from https://jrsoftware.org/isdl.php and rerun." -ForegroundColor Gray
}

Write-Host "`nDistribution packages available at:" -ForegroundColor Cyan
Get-ChildItem $DistDir | Select-Object Name, @{Name="Size(MB)";Expression={[math]::Round($_.Length/1MB,2)}}, LastWriteTime | Format-Table -AutoSize
Write-Host "Packaging complete!" -ForegroundColor Green
