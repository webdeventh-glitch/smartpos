# ========================================================
# Smart POS Standalone License Master (Vendor Tool)
# Compiles isolated portable vendor executable + zip
# ========================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "Compiling Vendor License Master executable..." -ForegroundColor Cyan
& flutter build windows --target lib/license_generator_main.dart --release

if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter build failed with code $LASTEXITCODE"
    exit $LASTEXITCODE
}

$DistVendor = Join-Path $Root "dist\vendor"
if (Test-Path $DistVendor) {
    Remove-Item $DistVendor -Recurse -Force
}
New-Item -ItemType Directory -Path $DistVendor -Force | Out-Null

$BuildDir = Join-Path $Root "build\windows\x64\runner\Release"
Copy-Item (Join-Path $BuildDir "desktop_starter.exe") (Join-Path $DistVendor "SmartPOS_LicenseMaster.exe") -Force
Copy-Item (Join-Path $BuildDir "*.dll") $DistVendor -Force

if (Test-Path (Join-Path $BuildDir "data")) {
    Copy-Item (Join-Path $BuildDir "data") $DistVendor -Recurse -Force
}

# Bundle VC++ runtime DLLs so portable vendor tool runs on clean Windows PCs
$VcDlls = @("msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll", "vcruntime140.dll", "vcruntime140_1.dll")
foreach ($dll in $VcDlls) {
    $sysPath = "C:\Windows\System32\$dll"
    if (Test-Path $sysPath) {
        Copy-Item $sysPath (Join-Path $DistVendor $dll) -Force
    }
}

$PortableZip = Join-Path $Root "dist\SmartPOS_LicenseMaster_Portable_v1.1.1.zip"
if (Test-Path $PortableZip) {
    Remove-Item $PortableZip -Force
}
Compress-Archive -Path "$DistVendor\*" -DestinationPath $PortableZip -CompressionLevel Optimal

Write-Host "========================================================" -ForegroundColor Green
Write-Host " [SUCCESS] Vendor License Master compiled!" -ForegroundColor Green
Write-Host " Executable: dist\vendor\SmartPOS_LicenseMaster.exe" -ForegroundColor Green
Write-Host " Portable Zip: dist\SmartPOS_LicenseMaster_Portable_v1.1.1.zip" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
