@echo off
:: Network Drive Removal Tool - Universal Launcher
:: Handles network location issues and dependency checking

setlocal EnableDelayedExpansion

echo ================================================================
echo   NETWORK DRIVE REMOVAL TOOL - UNIVERSAL LAUNCHER
echo ================================================================
echo.

:: Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [WARNING] Not running as Administrator
    echo           Some features may not work correctly
    echo           For best results: Right-click this file -^> "Run as administrator"
    echo.
)

:: Get current directory
set "SCRIPT_DIR=%~dp0"
echo Script Location: %SCRIPT_DIR%
echo.

:: Check if running from network location
echo %SCRIPT_DIR% | findstr /R "^\\\\.*" >nul
if %errorLevel% equ 0 (
    echo [INFO] Running from network location (UNC path)
    goto :network_location
)

echo %SCRIPT_DIR% | findstr /R "^[A-Z]:.*" >nul
if %errorLevel% equ 0 (
    net use | findstr /C:"%SCRIPT_DIR:~0,2%" | findstr /C:"\\\\" >nul
    if !errorLevel! equ 0 (
        echo [INFO] Running from mapped network drive
        goto :network_location
    )
)

echo [INFO] Running from local location
goto :check_dependencies

:network_location
echo.
echo [WARNING] Network location detected!
echo           This may cause security restrictions and execution issues.
echo.
echo Options:
echo [1] Continue from network location (may have issues)
echo [2] Copy to local machine (recommended)
echo [3] Exit
echo.
set /p "choice=Enter your choice (1, 2, or 3): "

if "%choice%"=="1" goto :check_dependencies
if "%choice%"=="2" goto :copy_local
if "%choice%"=="3" goto :exit

echo Invalid choice. Continuing with network location...
goto :check_dependencies

:copy_local
set "LOCAL_DIR=C:\Tools\NetworkDriveRemover"
echo.
echo Copying files to: %LOCAL_DIR%
echo.

:: Create local directory
if not exist "%LOCAL_DIR%" (
    mkdir "%LOCAL_DIR%" 2>nul
    if !errorLevel! neq 0 (
        echo [ERROR] Failed to create directory. Try running as Administrator.
        pause
        goto :exit
    )
    echo [OK] Created local directory
)

:: Copy files
echo Copying PowerShell scripts...
copy "%SCRIPT_DIR%*.ps1" "%LOCAL_DIR%\" >nul 2>&1
if %errorLevel% equ 0 echo [OK] Copied PowerShell scripts

echo Copying documentation...
copy "%SCRIPT_DIR%*.md" "%LOCAL_DIR%\" >nul 2>&1
copy "%SCRIPT_DIR%*.txt" "%LOCAL_DIR%\" >nul 2>&1

:: Unblock files (PowerShell command)
echo Unblocking files...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem '%LOCAL_DIR%\*.ps1' | Unblock-File" 2>nul

echo.
echo [SUCCESS] Files copied to local directory!
echo.
echo To run the application:
echo 1. Open PowerShell as Administrator
echo 2. cd "%LOCAL_DIR%"
echo 3. .\NetworkDriveRemover-Launcher.ps1
echo.

:: Ask if user wants to run now
set /p "run_now=Run the application now? (Y/N): "
if /i "%run_now%"=="Y" (
    cd /d "%LOCAL_DIR%"
    goto :run_powershell
)
goto :exit

:check_dependencies
echo Checking dependencies...
echo.

:: Check PowerShell version
for /f "tokens=*" %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$PSVersionTable.PSVersion.Major"') do set "PS_VERSION=%%i"
if "%PS_VERSION%" geq "5" (
    echo [OK] PowerShell version: %PS_VERSION%.x
) else (
    echo [ERROR] PowerShell 5.0+ required. Current: %PS_VERSION%.x
    echo         Please upgrade PowerShell via Windows Management Framework
    echo.
    pause
    goto :exit
)

:: Check required files
echo Checking required files...
if exist "%SCRIPT_DIR%NetworkDriveRemover-Launcher.ps1" (
    echo [OK] Main launcher found
) else (
    echo [ERROR] NetworkDriveRemover-Launcher.ps1 not found
)

if exist "%SCRIPT_DIR%Remove-NetworkDrives.ps1" (
    echo [OK] CLI script found
) else (
    echo [ERROR] Remove-NetworkDrives.ps1 not found
)

if exist "%SCRIPT_DIR%Remove-NetworkDrives-GUI.ps1" (
    echo [OK] GUI script found
) else (
    echo [ERROR] Remove-NetworkDrives-GUI.ps1 not found
)

echo.
echo Dependencies checked. Starting application...
echo.

:run_powershell
:: First try to run dependency installer
if exist "%SCRIPT_DIR%Install-Dependencies.ps1" (
    echo Running dependency checker...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Install-Dependencies.ps1"
    echo.
    echo Press any key to continue to main application...
    pause >nul
    echo.
)

:: Try multiple methods to launch the application
echo Starting Network Drive Removal Tool...
echo.

:: Method 1: Try the bypass launcher first
if exist "%SCRIPT_DIR%Start-NetworkDriveRemover.ps1" (
    echo [Method 1] Using execution policy bypass launcher...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Start-NetworkDriveRemover.ps1"
    goto :check_result
)

:: Method 2: Try direct launch with bypass
if exist "%SCRIPT_DIR%NetworkDriveRemover-Launcher.ps1" (
    echo [Method 2] Direct launch with execution policy bypass...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%NetworkDriveRemover-Launcher.ps1"
    goto :check_result
)

:: Method 3: Try individual components
echo [Method 3] Trying individual components...
if exist "%SCRIPT_DIR%Remove-NetworkDrives-GUI.ps1" (
    echo GUI version found, launching...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Remove-NetworkDrives-GUI.ps1"
    goto :check_result
)

if exist "%SCRIPT_DIR%Remove-NetworkDrives.ps1" (
    echo CLI version found, launching...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Remove-NetworkDrives.ps1"
    goto :check_result
)

echo [ERROR] No PowerShell scripts found to launch
goto :execution_failed

:check_result
if %errorLevel% equ 0 (
    echo.
    echo [SUCCESS] Application completed successfully
    goto :exit
)

:execution_failed
echo.
echo [ERROR] Application failed to start.
echo.
echo Common fixes:
echo 1. Run this batch file as Administrator
echo 2. Copy files to local machine (option 2 at startup)
echo 3. Try the alternative launcher commands below:
echo.
echo Alternative commands to try:
echo   powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Start-NetworkDriveRemover.ps1"
echo   powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Remove-NetworkDrives-GUI.ps1"
echo   powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Remove-NetworkDrives.ps1"
echo.

:exit
echo.
echo Press any key to exit...
pause >nul