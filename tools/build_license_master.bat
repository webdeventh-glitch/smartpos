@echo off
setlocal
echo ========================================================
echo   Smart POS Standalone License Master (Vendor Tool)
echo   Compiling isolated vendor executable...
echo ========================================================

cd /d "%~dp0\.."

flutter build windows --target lib/license_generator_main.dart --release
if errorlevel 1 (
    echo [ERROR] Build failed!
    exit /b 1
)

if not exist "dist\vendor" mkdir "dist\vendor"
copy /y "build\windows\x64\runner\Release\desktop_starter.exe" "dist\vendor\SmartPOS_LicenseMaster.exe"
copy /y "build\windows\x64\runner\Release\*.dll" "dist\vendor\"
if exist "build\windows\x64\runner\Release\data" xcopy /e /i /y "build\windows\x64\runner\Release\data" "dist\vendor\data"

echo.
echo ========================================================
echo   [SUCCESS] Vendor License Master compiled!
echo   Location: dist\vendor\SmartPOS_LicenseMaster.exe
echo ========================================================
