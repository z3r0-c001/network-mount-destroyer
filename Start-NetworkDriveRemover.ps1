#Requires -Version 5.0
<#
.SYNOPSIS
    Network Drive Removal Tool - Execution Policy Bypass Launcher
.DESCRIPTION
    Launches the Network Drive Removal Tool with execution policy bypass
    to handle network location security restrictions
#>

# Set execution policy for this session only
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    Write-Host "[OK] Execution policy set to Bypass for this session" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Could not set execution policy: $_" -ForegroundColor Yellow
}

# Get script directory reliably
$scriptDir = if ($PSScriptRoot) {
    $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    # Fallback - should rarely happen
    Write-Host "WARNING: Could not determine script directory, using current directory" -ForegroundColor Yellow
    Get-Location
}

Write-Host "Script directory: $scriptDir" -ForegroundColor Gray
Write-Host "Current directory: $(Get-Location)" -ForegroundColor Gray

# Check if launcher exists
$launcherPath = Join-Path $scriptDir "NetworkDriveRemover-Launcher.ps1"
if (Test-Path $launcherPath) {
    Write-Host "Starting Network Drive Removal Tool..." -ForegroundColor Cyan
    Write-Host
    
    # Launch with execution policy bypass
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcherPath
} else {
    Write-Host "[ERROR] NetworkDriveRemover-Launcher.ps1 not found" -ForegroundColor Red
    Write-Host "Expected location: $launcherPath" -ForegroundColor Gray
    
    # Try to find and run individual components
    $guiPath = Join-Path $scriptDir "Remove-NetworkDrives-GUI.ps1"
    $cliPath = Join-Path $scriptDir "Remove-NetworkDrives.ps1"
    
    Write-Host
    Write-Host "Alternative options:" -ForegroundColor Yellow
    
    if (Test-Path $guiPath) {
        Write-Host "[1] GUI Version Available" -ForegroundColor Green
    }
    
    if (Test-Path $cliPath) {
        Write-Host "[2] CLI Version Available" -ForegroundColor Green
    }
    
    Write-Host "[Q] Exit" -ForegroundColor Yellow
    Write-Host
    Write-Host "Enter choice (1, 2, or Q): " -ForegroundColor Cyan -NoNewline
    $choice = Read-Host
    
    switch ($choice) {
        "1" { 
            if (Test-Path $guiPath) {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $guiPath
            }
        }
        "2" { 
            if (Test-Path $cliPath) {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $cliPath
            }
        }
        default { 
            Write-Host "Exiting..." -ForegroundColor Gray
            exit 0
        }
    }
}

Write-Host
Write-Host "Press Enter to exit..." -ForegroundColor DarkGray
Read-Host