#Requires -Version 5.0
<#
.SYNOPSIS
    Network Drive Removal Tool - Application Launcher
.DESCRIPTION
    Simple menu-driven launcher to select between GUI and CLI versions
    of the Network Drive Removal Tool
#>

param(
    [switch]$AutoGUI,
    [switch]$AutoCLI
)

# Clear screen and show header
Clear-Host
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "          NETWORK DRIVE REMOVAL TOOL - LAUNCHER" -ForegroundColor Cyan
Write-Host "                   $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "WARNING: Not running as Administrator" -ForegroundColor Yellow
    Write-Host "   Some features may not work correctly" -ForegroundColor DarkYellow
    Write-Host "   For best results: Right-click -> 'Run as Administrator'" -ForegroundColor DarkYellow
    Write-Host
}

# Auto-launch options
if ($AutoGUI) {
    Write-Host "Auto-launching GUI version..." -ForegroundColor Green
    & ".\Remove-NetworkDrives-GUI.ps1"
    exit 0
}

if ($AutoCLI) {
    Write-Host "Auto-launching CLI version..." -ForegroundColor Green
    & ".\Remove-NetworkDrives.ps1"
    exit 0
}

# Determine script directory reliably
$scriptDir = if ($PSScriptRoot) {
    $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    # Fallback
    Get-Location
}

# Check if required files exist
$guiScript = Join-Path $scriptDir "Remove-NetworkDrives-GUI.ps1"
$cliScript = Join-Path $scriptDir "Remove-NetworkDrives.ps1"
$guiExists = Test-Path $guiScript
$cliExists = Test-Path $cliScript

Write-Host "Available Applications:" -ForegroundColor Yellow
Write-Host

# Option 1: GUI Version
Write-Host "[1] " -ForegroundColor Cyan -NoNewline
if ($guiExists) {
    Write-Host "GUI Application (Windows Forms)" -ForegroundColor White
    Write-Host "    + User-friendly interface" -ForegroundColor Green
    Write-Host "    + Point-and-click operation" -ForegroundColor Green
    Write-Host "    + Real-time progress tracking" -ForegroundColor Green
    Write-Host "    + Best for helpdesk/end users" -ForegroundColor Green
} else {
    Write-Host "GUI Application (Windows Forms)" -ForegroundColor DarkGray
    Write-Host "    X File not found: $guiScript" -ForegroundColor Red
}
Write-Host

# Option 2: CLI Version
Write-Host "[2] " -ForegroundColor Cyan -NoNewline
if ($cliExists) {
    Write-Host "Command Line Interface" -ForegroundColor White
    Write-Host "    + Interactive console menu" -ForegroundColor Green
    Write-Host "    + Color-coded output" -ForegroundColor Green
    Write-Host "    + Detailed step-by-step process" -ForegroundColor Green
    Write-Host "    + Best for IT professionals" -ForegroundColor Green
} else {
    Write-Host "Command Line Interface" -ForegroundColor DarkGray
    Write-Host "    X File not found: $cliScript" -ForegroundColor Red
}
Write-Host

# Option 3: Help
Write-Host "[3] " -ForegroundColor Cyan -NoNewline
Write-Host "View Help and Documentation" -ForegroundColor White
Write-Host "    + Usage instructions" -ForegroundColor Green
Write-Host "    + Troubleshooting guide" -ForegroundColor Green
Write-Host "    + Technical details" -ForegroundColor Green
Write-Host

# Option 4: System Info
Write-Host "[4] " -ForegroundColor Cyan -NoNewline
Write-Host "System Information and Requirements" -ForegroundColor White
Write-Host "    + Check PowerShell version" -ForegroundColor Green
Write-Host "    + Check execution policy" -ForegroundColor Green
Write-Host "    + Check administrator status" -ForegroundColor Green
Write-Host

# Exit option
Write-Host "[Q] " -ForegroundColor Cyan -NoNewline
Write-Host "Exit" -ForegroundColor White
Write-Host

# Get user selection
Write-Host "================================================================" -ForegroundColor DarkGray
Write-Host "Select an option [1-4, Q]: " -ForegroundColor Yellow -NoNewline
$selection = Read-Host

switch ($selection.ToUpper()) {
    "1" {
        if ($guiExists) {
            Write-Host
            Write-Host "Launching GUI Application..." -ForegroundColor Green
            Write-Host "Loading Windows Forms interface..." -ForegroundColor DarkGray
            try {
                & $guiScript
            } catch {
                Write-Host
                Write-Host "ERROR: Failed to launch GUI application:" -ForegroundColor Red
                Write-Host "   $_" -ForegroundColor DarkRed
                Write-Host
                Write-Host "Troubleshooting:" -ForegroundColor Yellow
                Write-Host "• Ensure you have .NET Framework installed" -ForegroundColor Gray
                Write-Host "• Try running as Administrator" -ForegroundColor Gray
                Write-Host "• Check PowerShell execution policy" -ForegroundColor Gray
            }
        } else {
            Write-Host
            Write-Host "ERROR: GUI script not found: $guiScript" -ForegroundColor Red
            Write-Host "   Please ensure all files are in the same directory" -ForegroundColor Yellow
        }
    }
    
    "2" {
        if ($cliExists) {
            Write-Host
            Write-Host "Launching CLI Application..." -ForegroundColor Green
            Write-Host "Starting interactive console interface..." -ForegroundColor DarkGray
            try {
                & $cliScript
            } catch {
                Write-Host
                Write-Host "ERROR: Failed to launch CLI application:" -ForegroundColor Red
                Write-Host "   $_" -ForegroundColor DarkRed
                Write-Host
                Write-Host "Troubleshooting:" -ForegroundColor Yellow
                Write-Host "• Try running as Administrator" -ForegroundColor Gray
                Write-Host "• Check PowerShell execution policy" -ForegroundColor Gray
                Write-Host "• Verify script file is not corrupted" -ForegroundColor Gray
            }
        } else {
            Write-Host
            Write-Host "ERROR: CLI script not found: $cliScript" -ForegroundColor Red
            Write-Host "   Please ensure all files are in the same directory" -ForegroundColor Yellow
        }
    }
    
    "3" {
        Write-Host
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host "                    HELP & DOCUMENTATION" -ForegroundColor Cyan
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host
        Write-Host "WHAT THIS TOOL DOES:" -ForegroundColor Yellow
        Write-Host "• Permanently removes network drive mappings" -ForegroundColor White
        Write-Host "• Cleans registry entries to prevent reconnection" -ForegroundColor White
        Write-Host "• Removes stored credentials" -ForegroundColor White
        Write-Host "• Clears mount points and Group Policy settings" -ForegroundColor White
        Write-Host
        Write-Host "BEFORE USING:" -ForegroundColor Yellow
        Write-Host "• Ensure you have alternative access to network resources" -ForegroundColor White
        Write-Host "• Save and close any files on network drives" -ForegroundColor White
        Write-Host "• Run as Administrator for complete functionality" -ForegroundColor White
        Write-Host "• Note down important UNC paths for future reference" -ForegroundColor White
        Write-Host
        Write-Host "GUI vs CLI SELECTION:" -ForegroundColor Yellow
        Write-Host "• GUI: Best for helpdesk staff and end users" -ForegroundColor White
        Write-Host "• CLI: Best for IT professionals and automation" -ForegroundColor White
        Write-Host
        Write-Host "COMMON ISSUES:" -ForegroundColor Yellow
        Write-Host "• 'Access Denied': Run as Administrator" -ForegroundColor White
        Write-Host "• 'Script Execution Disabled': Set-ExecutionPolicy RemoteSigned" -ForegroundColor White
        Write-Host "• Drive reappears: Check Group Policy for auto-mapping" -ForegroundColor White
        Write-Host
        Write-Host "For detailed documentation, see README.md" -ForegroundColor Green
        Write-Host
        Write-Host "Press Enter to return to main menu..." -ForegroundColor DarkGray
        Read-Host
        # Re-run the script properly
        $scriptPath = if ($MyInvocation.MyCommand.Path) {
            $MyInvocation.MyCommand.Path
        } else {
            Join-Path $scriptDir "NetworkDriveRemover-Launcher.ps1"
        }
        & $scriptPath
    }
    
    "4" {
        Write-Host
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host "                  SYSTEM INFORMATION" -ForegroundColor Cyan
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host
        
        # PowerShell Version
        Write-Host "PowerShell Version: " -ForegroundColor Yellow -NoNewline
        Write-Host "$($PSVersionTable.PSVersion)" -ForegroundColor White
        if ($PSVersionTable.PSVersion.Major -ge 5) {
            Write-Host "   OK - Compatible (5.0+ required)" -ForegroundColor Green
        } else {
            Write-Host "   ERROR - Incompatible (5.0+ required)" -ForegroundColor Red
        }
        Write-Host
        
        # Windows Version
        Write-Host "Windows Version: " -ForegroundColor Yellow -NoNewline
        $winVer = [System.Environment]::OSVersion.Version
        Write-Host "$winVer" -ForegroundColor White
        if ($winVer.Major -ge 10 -or ($winVer.Major -eq 6 -and $winVer.Minor -ge 1)) {
            Write-Host "   OK - Compatible (Windows 7+ required)" -ForegroundColor Green
        } else {
            Write-Host "   ERROR - Incompatible (Windows 7+ required)" -ForegroundColor Red
        }
        Write-Host
        
        # Administrator Status
        Write-Host "Administrator Status: " -ForegroundColor Yellow -NoNewline
        if ($isAdmin) {
            Write-Host "Running as Administrator" -ForegroundColor Green
            Write-Host "   OK - Full functionality available" -ForegroundColor Green
        } else {
            Write-Host "Standard User" -ForegroundColor Yellow
            Write-Host "   WARNING - Limited functionality - some features may fail" -ForegroundColor Yellow
        }
        Write-Host
        
        # Execution Policy
        Write-Host "Execution Policy: " -ForegroundColor Yellow -NoNewline
        $execPolicy = Get-ExecutionPolicy
        Write-Host "$execPolicy" -ForegroundColor White
        if ($execPolicy -in @("Unrestricted", "RemoteSigned", "Bypass")) {
            Write-Host "   OK - Scripts can execute" -ForegroundColor Green
        } else {
            Write-Host "   ERROR - Scripts blocked - run: Set-ExecutionPolicy RemoteSigned" -ForegroundColor Red
        }
        Write-Host
        
        # File Check
        Write-Host "Required Files:" -ForegroundColor Yellow
        Write-Host "• GUI Script: " -NoNewline
        if ($guiExists) {
            Write-Host "Found" -ForegroundColor Green
        } else {
            Write-Host "Missing" -ForegroundColor Red
        }
        Write-Host "• CLI Script: " -NoNewline
        if ($cliExists) {
            Write-Host "Found" -ForegroundColor Green
        } else {
            Write-Host "Missing" -ForegroundColor Red
        }
        Write-Host
        
        # Current Directory
        Write-Host "Current Directory: " -ForegroundColor Yellow -NoNewline
        Write-Host "$PWD" -ForegroundColor White
        Write-Host
        
        Write-Host "Press Enter to return to main menu..." -ForegroundColor DarkGray
        Read-Host
        # Re-run the script properly
        $scriptPath = if ($MyInvocation.MyCommand.Path) {
            $MyInvocation.MyCommand.Path
        } else {
            Join-Path $scriptDir "NetworkDriveRemover-Launcher.ps1"
        }
        & $scriptPath
    }
    
    "Q" {
        Write-Host
        Write-Host "Exiting..." -ForegroundColor Green
        Write-Host "Thank you for using Network Drive Removal Tool" -ForegroundColor Cyan
        exit 0
    }
    
    default {
        Write-Host
        Write-Host "ERROR: Invalid selection: $selection" -ForegroundColor Red
        Write-Host "Please enter 1, 2, 3, 4, or Q" -ForegroundColor Yellow
        Write-Host
        Start-Sleep -Seconds 2
        # Re-run the script properly
        $scriptPath = if ($MyInvocation.MyCommand.Path) {
            $MyInvocation.MyCommand.Path
        } else {
            Join-Path $scriptDir "NetworkDriveRemover-Launcher.ps1"
        }
        & $scriptPath
    }
}

Write-Host
Write-Host "Press Enter to return to launcher..." -ForegroundColor DarkGray
Read-Host
# Re-run the script properly
$scriptPath = if ($MyInvocation.MyCommand.Path) {
    $MyInvocation.MyCommand.Path
} else {
    Join-Path $scriptDir "NetworkDriveRemover-Launcher.ps1"
}
& $scriptPath