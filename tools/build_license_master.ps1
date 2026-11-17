# ========================================================
# Smart POS Standalone License Master (Vendor Tool)
# Compiles isolated vendor executable
# ========================================================

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "Compiling Vendor License Master executable..." -ForegroundColor Cyan
& flutter build windows --target lib/license_generator_main.dart --release

if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter build failed with code $LASTEXITCODE"
    exit $LASTEXITCODE
}

$DistVendor = Join-Path $Root "dist\vendor"
if (-not (Test-Path $DistVendor)) {
    New-Item -ItemType Directory -Path $DistVendor -Force | Out-Null
}

$BuildDir = Join-Path $Root "build\windows\x64\runner\Release"
Copy-Item (Join-Path $BuildDir "desktop_starter.exe") (Join-Path $DistVendor "SmartPOS_LicenseMaster.exe") -Force
Copy-Item (Join-Path $BuildDir "*.dll") $DistVendor -Force
if (Test-Path (Join-Path $BuildDir "data")) {
    Copy-Item (Join-Path $BuildDir "data") $DistVendor -Recurse -Force
}

Write-Host "========================================================" -ForegroundColor Green
Write-Host " [SUCCESS] Vendor License Master compiled!" -ForegroundColor Green
Write-Host " Location: dist\vendor\SmartPOS_LicenseMaster.exe" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
