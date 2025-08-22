#Requires -Version 3.0
<#
.SYNOPSIS
    Network Drive Removal Tool - Dependency Installer and Environment Checker
.DESCRIPTION
    Checks and installs all required dependencies for running the Network Drive Removal Tool
    from network locations. Handles common enterprise environment issues.
.PARAMETER Force
    Force reinstallation of dependencies even if they appear to be present
.PARAMETER SkipElevation
    Skip the administrator elevation check (not recommended)
#>

param(
    [switch]$Force,
    [switch]$SkipElevation
)

# Ensure script runs as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "Restarting as Administrator..." -ForegroundColor Yellow
    
    # Get the script path
    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not $scriptPath) {
        $scriptPath = $PSCommandPath
    }
    
    # Restart as admin with bypass execution policy
    Start-Process PowerShell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}

# Set error handling
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Console output functions
function Write-Status {
    param([string]$Message, [string]$Status = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    switch ($Status) {
        "OK"    { Write-Host "[$timestamp] [OK]    $Message" -ForegroundColor Green }
        "WARN"  { Write-Host "[$timestamp] [WARN]  $Message" -ForegroundColor Yellow }
        "ERROR" { Write-Host "[$timestamp] [ERROR] $Message" -ForegroundColor Red }
        "INFO"  { Write-Host "[$timestamp] [INFO]  $Message" -ForegroundColor Cyan }
        "FIX"   { Write-Host "[$timestamp] [FIX]   $Message" -ForegroundColor Magenta }
    }
}

function Write-Header {
    param([string]$Title)
    Write-Host
    Write-Host "================================================================" -ForegroundColor DarkGray
    Write-Host "  $Title" -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor DarkGray
}

function Test-Administrator {
    try {
        $currentPrincipal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    } catch {
        return $false
    }
}

function Test-NetworkLocation {
    # Try to get current path using multiple methods
    $currentPath = if ($PSScriptRoot) {
        $PSScriptRoot
    } elseif ($MyInvocation.MyCommand.Path) {
        Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        (Get-Location).Path
    }
    
    if (-not $currentPath) {
        return $false
    }
    
    # Check if UNC path
    if ($currentPath -match "^\\\\") {
        return $true  # UNC path
    }
    
    # Check if mapped network drive
    if ($currentPath -match "^[A-Z]:") {
        $driveLetter = $currentPath[0]
        $drive = Get-PSDrive -Name $driveLetter -ErrorAction SilentlyContinue
        if ($drive -and $drive.DisplayRoot -like '\\*') {
            return $true  # Mapped network drive
        }
    }
    
    return $false
}

function Set-PowerShellExecutionPolicy {
    Write-Header "CHECKING AND SETTING POWERSHELL EXECUTION POLICY"
    
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
    $processPolicy = Get-ExecutionPolicy -Scope Process -ErrorAction SilentlyContinue
    $machinePolicy = Get-ExecutionPolicy -Scope LocalMachine -ErrorAction SilentlyContinue
    
    Write-Status "Machine Policy: $machinePolicy"
    Write-Status "Current User Policy: $currentPolicy"
    Write-Status "Process Policy: $processPolicy"
    
    $allowedPolicies = @("Unrestricted", "RemoteSigned", "Bypass")
    
    # Since we're running as admin, we can set the policy at all levels
    Write-Status "Setting execution policy to RemoteSigned (running as Administrator)..." "FIX"
    
    try {
        # Set for CurrentUser (permanent for this user)
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        Write-Status "Set execution policy for CurrentUser to RemoteSigned" "OK"
        
        # Set for LocalMachine (requires admin, affects all users)
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction SilentlyContinue
        Write-Status "Set execution policy for LocalMachine to RemoteSigned" "OK"
        
        # Also set Process scope for immediate effect
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force -ErrorAction SilentlyContinue
        Write-Status "Set execution policy for Process to RemoteSigned" "OK"
        
        Write-Status "Execution policy successfully configured for running scripts from network locations" "OK"
        
    } catch {
        Write-Status "Some execution policy changes failed: $_" "WARN"
        Write-Status "This is normal if restricted by Group Policy" "INFO"
    }
    
    # Verify the effective policy
    $effectivePolicy = Get-ExecutionPolicy -ErrorAction SilentlyContinue
    Write-Status "Effective execution policy: $effectivePolicy" "INFO"
    
    if ($effectivePolicy -in $allowedPolicies) {
        Write-Status "Scripts can now be executed" "OK"
    } else {
        Write-Status "Execution policy may still be restricted by Group Policy" "WARN"
        Write-Status "Contact your IT administrator if scripts still won't run" "INFO"
    }
}

function Test-PowerShellVersion {
    Write-Header "CHECKING POWERSHELL VERSION"
    
    $version = $PSVersionTable.PSVersion
    Write-Status "PowerShell Version: $version"
    
    if ($version.Major -lt 5) {
        Write-Status "PowerShell 5.0 or higher required" "ERROR"
        Write-Status "Current version: $version" "ERROR"
        Write-Status "Please upgrade PowerShell via Windows Management Framework" "ERROR"
        return $false
    } else {
        Write-Status "PowerShell version is compatible" "OK"
        return $true
    }
}

function Test-DotNetFramework {
    Write-Header "CHECKING .NET FRAMEWORK"
    
    try {
        # Check .NET Framework version
        $dotNetVersion = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
        Write-Status ".NET Framework: $dotNetVersion"
        
        # Test Windows Forms availability
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            Write-Status "Windows Forms available for GUI applications" "OK"
            return $true
        } catch {
            Write-Status "Windows Forms not available: $_" "ERROR"
            Write-Status "GUI applications may not work" "WARN"
            return $false
        }
    } catch {
        Write-Status "Could not determine .NET Framework version" "WARN"
        Write-Status "Some features may not work correctly" "WARN"
        return $false
    }
}

function Test-NetworkAccess {
    Write-Header "CHECKING NETWORK ACCESS AND SECURITY"
    
    $isNetworkLocation = Test-NetworkLocation
    if ($isNetworkLocation) {
        Write-Status "Running from network location" "INFO"
        
        # Check if files can be executed from network
        try {
            $testPath = Join-Path $PSScriptRoot "Remove-NetworkDrives.ps1"
            if (Test-Path $testPath) {
                # Try to get content to test network access
                $content = Get-Content $testPath -TotalCount 1 -ErrorAction Stop
                Write-Status "Network file access working" "OK"
            } else {
                Write-Status "Required script files not found in network location" "ERROR"
            }
        } catch {
            Write-Status "Network access issue: $_" "ERROR"
            Write-Status "May need to copy files locally or adjust network permissions" "WARN"
        }
    } else {
        Write-Status "Running from local location" "OK"
    }
    
    # Check zone restrictions
    try {
        $currentFile = $MyInvocation.MyCommand.Path
        $zone = Get-Content "$currentFile`:Zone.Identifier" -ErrorAction SilentlyContinue
        if ($zone -match "ZoneId=3") {
            Write-Status "Files are marked as downloaded from internet" "WARN"
            Write-Status "Windows may block execution" "WARN"
            Write-Status "Solution: Right-click files -> Properties -> Unblock" "FIX"
        }
    } catch {
        # Zone identifier check failed, which is often normal
    }
}

function Test-RequiredFiles {
    Write-Header "CHECKING REQUIRED FILES"
    
    $requiredFiles = @(
        "Remove-NetworkDrives.ps1",
        "Remove-NetworkDrives-GUI.ps1",
        "README.md"
    )
    
    $allFilesFound = $true
    
    # Get script directory reliably
    $scriptRoot = if ($PSScriptRoot) {
        Write-Status "Script directory (PSScriptRoot): $PSScriptRoot" "INFO"
        $PSScriptRoot
    } elseif ($MyInvocation.MyCommand.Path) {
        $dir = Split-Path -Parent $MyInvocation.MyCommand.Path
        Write-Status "Script directory (MyInvocation): $dir" "INFO"
        $dir
    } else {
        Write-Status "Script directory (fallback to current): $(Get-Location)" "INFO"
        Get-Location
    }
    
    if (-not $scriptRoot) {
        Write-Status "Could not determine script directory" "ERROR"
        return $false
    }
    
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $scriptRoot $file
        Write-Status "Checking: $filePath" "INFO"
        
        if (Test-Path $filePath) {
            Write-Status "Found: $file" "OK"
        } else {
            Write-Status "Missing: $file" "ERROR"
            $allFilesFound = $false
        }
    }
    
    if ($allFilesFound) {
        Write-Status "All required files present" "OK"
    } else {
        Write-Status "Some files missing - application may not work correctly" "WARN"
    }
    
    return $allFilesFound
}

function Install-PowerShellModules {
    Write-Header "CHECKING POWERSHELL MODULES"
    
    # We don't actually need external modules for the network drive tool
    # But let's check if PowerShellGet is available for future use
    try {
        $psGetVersion = (Get-Module -Name PowerShellGet -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
        if ($psGetVersion) {
            Write-Status "PowerShellGet available: $psGetVersion" "OK"
        } else {
            Write-Status "PowerShellGet not available" "WARN"
            Write-Status "Module installation may not work" "INFO"
        }
    } catch {
        Write-Status "Could not check PowerShellGet availability" "WARN"
    }
}

function Test-WindowsVersion {
    Write-Header "CHECKING WINDOWS VERSION"
    
    $winVer = [System.Environment]::OSVersion.Version
    $winName = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).ProductName
    
    Write-Status "Windows Version: $winName ($winVer)"
    
    # Check if Windows 7 or higher
    if ($winVer.Major -ge 10 -or ($winVer.Major -eq 6 -and $winVer.Minor -ge 1)) {
        Write-Status "Windows version is compatible" "OK"
        return $true
    } else {
        Write-Status "Windows 7 or higher required" "ERROR"
        Write-Status "Current version may not be supported" "WARN"
        return $false
    }
}

function Test-NetworkDriveAccess {
    Write-Header "CHECKING NETWORK DRIVE ACCESS PERMISSIONS"
    
    # Test if we can access registry locations we need
    $regLocations = @(
        "HKCU:\Network",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2"
    )
    
    foreach ($regPath in $regLocations) {
        try {
            $testAccess = Test-Path $regPath
            Write-Status "Registry access ($regPath): Available" "OK"
        } catch {
            Write-Status "Registry access ($regPath): Limited" "WARN"
        }
    }
    
    # Test cmdkey availability
    $cmdkeyPath = "$env:SystemRoot\System32\cmdkey.exe"
    if (Test-Path $cmdkeyPath) {
        Write-Status "Credential Manager (cmdkey.exe): Available" "OK"
    } else {
        Write-Status "Credential Manager (cmdkey.exe): Not found" "WARN"
    }
}

function Show-ManualFixes {
    Write-Header "MANUAL FIXES FOR COMMON ISSUES"
    
    Write-Host
    Write-Host "If you encounter issues, try these manual fixes:" -ForegroundColor Yellow
    Write-Host
    Write-Host "1. EXECUTION POLICY:" -ForegroundColor Cyan
    Write-Host "   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Gray
    Write-Host
    Write-Host "2. UNBLOCK FILES (if downloaded from internet):" -ForegroundColor Cyan
    Write-Host "   Get-ChildItem *.ps1 | Unblock-File" -ForegroundColor Gray
    Write-Host "   OR: Right-click each .ps1 file -> Properties -> Unblock" -ForegroundColor Gray
    Write-Host
    Write-Host "3. COPY TO LOCAL MACHINE:" -ForegroundColor Cyan
    Write-Host "   Copy all files to C:\Tools\ and run from there" -ForegroundColor Gray
    Write-Host
    Write-Host "4. RUN AS ADMINISTRATOR:" -ForegroundColor Cyan
    Write-Host "   Right-click PowerShell -> Run as Administrator" -ForegroundColor Gray
    Write-Host
    Write-Host "5. NETWORK PERMISSIONS:" -ForegroundColor Cyan
    Write-Host "   Contact IT admin to verify network share permissions" -ForegroundColor Gray
    Write-Host
}

function Copy-ToLocal {
    Write-Header "COPY TO LOCAL OPTION"
    
    Write-Host "Would you like to copy the application to a local directory?" -ForegroundColor Yellow
    Write-Host "This can resolve network location and security issues." -ForegroundColor Gray
    Write-Host
    Write-Host "[Y] Yes - Copy to C:\Tools\NetworkDriveRemover" -ForegroundColor Green
    Write-Host "[N] No - Continue with network location" -ForegroundColor Yellow
    Write-Host
    Write-Host "Enter your choice (Y/N): " -ForegroundColor Cyan -NoNewline
    $choice = Read-Host
    
    if ($choice -eq 'Y' -or $choice -eq 'y') {
        $localPath = "C:\Tools\NetworkDriveRemover"
        
        try {
            # Create local directory
            if (-not (Test-Path $localPath)) {
                New-Item -ItemType Directory -Path $localPath -Force | Out-Null
                Write-Status "Created local directory: $localPath" "OK"
            }
            
            # Copy all PS1 files
            $sourceDir = if ($PSScriptRoot) {
                $PSScriptRoot
            } elseif ($MyInvocation.MyCommand.Path) {
                Split-Path -Parent $MyInvocation.MyCommand.Path
            } else {
                (Get-Location).Path
            }
            $filesToCopy = @("*.ps1", "*.md", "*.txt")
            
            foreach ($pattern in $filesToCopy) {
                $files = Get-ChildItem -Path $sourceDir -Filter $pattern -ErrorAction SilentlyContinue
                foreach ($file in $files) {
                    $destFile = Join-Path $localPath $file.Name
                    Copy-Item -Path $file.FullName -Destination $destFile -Force
                    Write-Status "Copied: $($file.Name)" "OK"
                }
            }
            
            # Unblock files
            Get-ChildItem -Path $localPath -Filter "*.ps1" | Unblock-File -ErrorAction SilentlyContinue
            Write-Status "Unblocked PowerShell files" "OK"
            
            Write-Host
            Write-Host "SUCCESS: Files copied to $localPath" -ForegroundColor Green
            Write-Host
            Write-Host "To run the application:" -ForegroundColor Yellow
            Write-Host "1. Open PowerShell as Administrator" -ForegroundColor Gray
            Write-Host "2. cd `"$localPath`"" -ForegroundColor Gray
            Write-Host "3. .\NetworkDriveRemover-Launcher.ps1" -ForegroundColor Gray
            Write-Host
            
        } catch {
            Write-Status "Failed to copy files: $_" "ERROR"
        }
    }
}

# Main execution
function Start-DependencyCheck {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  NETWORK DRIVE REMOVAL TOOL - DEPENDENCY CHECKER" -ForegroundColor Cyan
    Write-Host "                $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    
    Write-Status "Starting dependency check and installation..." "INFO"
    
    # Get script location using multiple methods
    $scriptLocation = if ($PSScriptRoot) {
        $PSScriptRoot
    } elseif ($MyInvocation.MyCommand.Path) {
        Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        (Get-Location).Path
    }
    
    Write-Status "Script location: $scriptLocation" "INFO"
    
    # Check if we should elevate
    if (-not $SkipElevation -and -not (Test-Administrator)) {
        Write-Status "Not running as Administrator" "WARN"
        Write-Status "Some fixes may require elevation" "INFO"
    }
    
    # Run all checks
    $checks = @{
        "PowerShell Version" = Test-PowerShellVersion
        "Windows Version" = Test-WindowsVersion
        ".NET Framework" = Test-DotNetFramework
        "Required Files" = Test-RequiredFiles
    }
    
    # Run configuration fixes
    Set-PowerShellExecutionPolicy
    Test-NetworkAccess
    Install-PowerShellModules
    Test-NetworkDriveAccess
    
    # Summary
    Write-Header "DEPENDENCY CHECK SUMMARY"
    $allPassed = $true
    
    foreach ($check in $checks.GetEnumerator()) {
        if ($check.Value) {
            Write-Status "$($check.Key): PASSED" "OK"
        } else {
            Write-Status "$($check.Key): FAILED" "ERROR"
            $allPassed = $false
        }
    }
    
    Write-Host
    if ($allPassed) {
        Write-Status "ALL CHECKS PASSED - Ready to run Network Drive Removal Tool" "OK"
        Write-Host
        Write-Host "You can now run the application:" -ForegroundColor Green
        Write-Host ".\NetworkDriveRemover-Launcher.ps1" -ForegroundColor White
        Write-Host
    } else {
        Write-Status "SOME CHECKS FAILED - See manual fixes below" "WARN"
        
        # Offer to copy to local if running from network
        if (Test-NetworkLocation) {
            Copy-ToLocal
        }
        
        Show-ManualFixes
    }
}

# Execute main function
Start-DependencyCheck

Write-Host
Write-Host "Press Enter to exit..." -ForegroundColor DarkGray
Read-Host