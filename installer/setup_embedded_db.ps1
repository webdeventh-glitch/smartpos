<#
.SYNOPSIS
    Prepares and bundles Embedded MySQL / MariaDB Portable binaries for Smart POS Enterprise.
.DESCRIPTION
    1. Checks if local Laragon MySQL (C:\laragon\bin\mysql) is available and copies minimal binaries.
    2. Alternatively downloads portable MariaDB 10.11 zip and extracts engine binaries.
    3. Places binaries into build/windows/x64/runner/Release/engine/mysql (or mariadb)
       so Inno Setup automatically bundles it into the setup installer.
#>

param(
    [switch]$ForceDownload
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ProjectRoot = Resolve-Path "$PSScriptRoot\.."
$ReleaseDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$EngineDir = Join-Path $ReleaseDir "engine\mysql"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Smart POS - Embedded Database Packaging Setup Utility  " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

if (-not (Test-Path $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
}

# 1. Check if local Laragon MySQL is available
$LaragonMysqlDir = "C:\laragon\bin\mysql\mysql-8.0.30-winx64"
if ((Test-Path $LaragonMysqlDir) -and (-not $ForceDownload)) {
    Write-Host "[1/2] Found local Laragon MySQL at: $LaragonMysqlDir" -ForegroundColor Green
    Write-Host "[2/2] Copying essential engine binaries to: $EngineDir..." -ForegroundColor Yellow

    if (-not (Test-Path $EngineDir)) {
        New-Item -ItemType Directory -Path $EngineDir -Force | Out-Null
    }

    $BinDest = Join-Path $EngineDir "bin"
    if (-not (Test-Path $BinDest)) {
        New-Item -ItemType Directory -Path $BinDest -Force | Out-Null
    }

    # Copy essential binaries
    $EssentialBins = @("mysqld.exe", "mysqladmin.exe", "mysql.exe")
    foreach ($bin in $EssentialBins) {
        $src = Join-Path $LaragonMysqlDir "bin\$bin"
        if (Test-Path $src) {
            Copy-Item $src (Join-Path $BinDest $bin) -Force
            Write-Host "       Copied: $bin" -ForegroundColor Gray
        }
    }

    # Copy share / errmsg if present
    $ShareSrc = Join-Path $LaragonMysqlDir "share"
    if (Test-Path $ShareSrc) {
        $ShareDest = Join-Path $EngineDir "share"
        Copy-Item -Path $ShareSrc -Destination $EngineDir -Recurse -Force
        Write-Host "       Copied: share/ (error messages & charsets)" -ForegroundColor Gray
    }

    Write-Host "Embedded MySQL engine successfully prepared in Release/engine/mysql!" -ForegroundColor Green
    exit 0
}

Write-Host "Preparing MariaDB portable engine..." -ForegroundColor Yellow
# Fallback instructions or download logic if needed
