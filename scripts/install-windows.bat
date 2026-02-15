@echo off
REM Sidecar Windows Installer Batch Wrapper
REM This script launches the PowerShell installer

echo Sidecar Windows Installer
echo.

REM Check if PowerShell is available
where powershell >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Error: PowerShell not found. Please install PowerShell.
    exit /b 1
)

REM Launch PowerShell installer with execution policy bypass
powershell -ExecutionPolicy Bypass -File "%~dp0install-windows.ps1" %*
