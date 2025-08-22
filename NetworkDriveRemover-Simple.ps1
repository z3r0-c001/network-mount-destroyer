#Requires -Version 5.0
<#
.SYNOPSIS
    Simple Network Drive Removal Tool Launcher
.DESCRIPTION
    Simplified launcher that just works - minimal dependencies and error handling
#>

# Basic error handling
$ErrorActionPreference = "Continue"

try {
    Clear-Host
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "    NETWORK DRIVE REMOVAL TOOL" -ForegroundColor Green  
    Write-Host "================================================" -ForegroundColor Green
    Write-Host

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Host "ERROR: PowerShell 5.0 or higher required" -ForegroundColor Red
        Write-Host "Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }

    # Determine script directory reliably
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
    Write-Host

    $guiScript = Join-Path $scriptDir "Remove-NetworkDrives-GUI.ps1"
    $cliScript = Join-Path $scriptDir "Remove-NetworkDrives.ps1"

    Write-Host "Available Options:" -ForegroundColor Yellow
    Write-Host

    # Option 1: GUI
    Write-Host "[1] GUI Version" -ForegroundColor Cyan
    if (Test-Path $guiScript) {
        Write-Host "    Status: Ready" -ForegroundColor Green
    } else {
        Write-Host "    Status: FILE NOT FOUND" -ForegroundColor Red
        Write-Host "    Missing: $guiScript" -ForegroundColor DarkRed
    }
    Write-Host

    # Option 2: CLI  
    Write-Host "[2] CLI Version" -ForegroundColor Cyan
    if (Test-Path $cliScript) {
        Write-Host "    Status: Ready" -ForegroundColor Green
    } else {
        Write-Host "    Status: FILE NOT FOUND" -ForegroundColor Red
        Write-Host "    Missing: $cliScript" -ForegroundColor DarkRed
    }
    Write-Host

    # Option 3: Exit
    Write-Host "[3] Exit" -ForegroundColor Cyan
    Write-Host

    # Get user choice
    Write-Host "Enter your choice (1, 2, or 3): " -ForegroundColor Yellow -NoNewline
    $choice = Read-Host

    switch ($choice) {
        "1" {
            if (Test-Path $guiScript) {
                Write-Host "Starting GUI application..." -ForegroundColor Green
                try {
                    & $guiScript
                } catch {
                    Write-Host "ERROR running GUI: $_" -ForegroundColor Red
                    Write-Host "Try running as Administrator" -ForegroundColor Yellow
                }
            } else {
                Write-Host "GUI script not found: $guiScript" -ForegroundColor Red
            }
        }
        
        "2" {
            if (Test-Path $cliScript) {
                Write-Host "Starting CLI application..." -ForegroundColor Green
                try {
                    & $cliScript
                } catch {
                    Write-Host "ERROR running CLI: $_" -ForegroundColor Red
                    Write-Host "Try running as Administrator" -ForegroundColor Yellow
                }
            } else {
                Write-Host "CLI script not found: $cliScript" -ForegroundColor Red
            }
        }
        
        "3" {
            Write-Host "Goodbye!" -ForegroundColor Green
            exit 0
        }
        
        default {
            Write-Host "Invalid choice: $choice" -ForegroundColor Red
            Write-Host "Please run the script again and choose 1, 2, or 3" -ForegroundColor Yellow
        }
    }

} catch {
    Write-Host "LAUNCHER ERROR: $_" -ForegroundColor Red
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "Current Directory: $(Get-Location)" -ForegroundColor Gray
    Write-Host "Execution Policy: $(Get-ExecutionPolicy)" -ForegroundColor Gray
}

Write-Host
Write-Host "Press Enter to exit..." -ForegroundColor DarkGray
Read-Host