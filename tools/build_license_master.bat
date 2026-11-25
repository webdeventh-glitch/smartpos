@echo off
setlocal
echo ========================================================
echo   Smart POS Standalone License Master (Vendor Tool)
echo   Compiling isolated portable vendor executable...
echo ========================================================

cd /d "%~dp0\.."

powershell -ExecutionPolicy Bypass -File "tools\build_license_master.ps1"
if errorlevel 1 (
    echo [ERROR] Build failed!
    exit /b 1
)
