#Requires -Version 5.0
<#
.SYNOPSIS
    Interactive tool to permanently remove persistent network drives
.DESCRIPTION
    Removes network drives and all associated registry entries, credentials, and mount points
    to prevent them from reconnecting after reboot
#>

param(
    [switch]$AutoConfirm
)

# Console colors
function Write-ColorText {
    param(
        [string]$Text,
        [ConsoleColor]$Color = [ConsoleColor]::White,
        [switch]$NoNewline
    )
    $oldColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $Color
    if ($NoNewline) {
        Write-Host $Text -NoNewline
    } else {
        Write-Host $Text
    }
    $Host.UI.RawUI.ForegroundColor = $oldColor
}

function Show-Header {
    Clear-Host
    Write-ColorText "`n================================================================" -Color Cyan
    Write-ColorText "          NETWORK DRIVE PERMANENT REMOVAL TOOL               " -Color Cyan
    Write-ColorText "                   $(Get-Date -Format 'yyyy-MM-dd HH:mm')                        " -Color Cyan
    Write-ColorText "================================================================" -Color Cyan
    Write-Host
}

function Get-NetworkDrives {
    $drives = @()
    
    # Get mapped network drives
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -like '\\*' } | ForEach-Object {
        $drives += [PSCustomObject]@{
            Letter = $_.Name
            Path = $_.DisplayRoot
            Used = if ($_.Used) { [math]::Round($_.Used/1GB, 2) } else { 0 }
            Free = if ($_.Free) { [math]::Round($_.Free/1GB, 2) } else { 0 }
            Persistent = (Test-Path "HKCU:\Network\$($_.Name)")
        }
    }
    
    return $drives | Sort-Object Letter
}

function Show-DriveList {
    param($Drives)
    
    if ($Drives.Count -eq 0) {
        Write-ColorText "`n[OK] No network drives found!" -Color Green
        return $false
    }
    
    Write-ColorText "`n+-------------------------------------------------------------+" -Color DarkGray
    Write-ColorText "|                   DETECTED NETWORK DRIVES                   |" -Color Yellow
    Write-ColorText "+-----+------------------------------------+------------------+" -Color DarkGray
    Write-ColorText "| Drv | Network Path                       | Status           |" -Color Yellow
    Write-ColorText "+-----+------------------------------------+------------------+" -Color DarkGray
    
    $index = 1
    foreach ($drive in $Drives) {
        $pathDisplay = if ($drive.Path.Length -gt 34) { 
            $drive.Path.Substring(0, 31) + "..." 
        } else { 
            $drive.Path.PadRight(34) 
        }
        
        $status = if ($drive.Persistent) { "Persistent" } else { "Temporary" }
        $statusColor = if ($drive.Persistent) { "Red" } else { "Yellow" }
        
        Write-ColorText "| " -Color DarkGray -NoNewline
        Write-ColorText "$($drive.Letter):" -Color Cyan -NoNewline
        Write-ColorText "  | " -Color DarkGray -NoNewline
        Write-ColorText $pathDisplay -Color White -NoNewline
        Write-ColorText " | " -Color DarkGray -NoNewline
        Write-ColorText $status.PadRight(16) -Color $statusColor -NoNewline
        Write-ColorText "|" -Color DarkGray
    }
    
    Write-ColorText "+-----+------------------------------------+------------------+" -Color DarkGray
    
    return $true
}

function Remove-NetworkDrive {
    param(
        [string]$DriveLetter,
        [string]$Path
    )
    
    $letter = $DriveLetter.TrimEnd(':')
    $success = $true
    $errors = @()
    
    Write-Host
    Write-ColorText "----------------------------------------------------------------" -Color DarkGray
    Write-ColorText "  Removing Drive ${letter}: ($Path)" -Color Yellow
    Write-ColorText "----------------------------------------------------------------" -Color DarkGray
    
    # Step 1: Disconnect network drive
    Write-ColorText "  [1/5] Disconnecting network drive... " -Color Cyan -NoNewline
    try {
        $result = net use "${letter}:" /delete /y 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorText "[OK]" -Color Green
        } else {
            Write-ColorText "[WARN]" -Color Yellow
            $errors += "Disconnect warning: May already be disconnected"
        }
    } catch {
        Write-ColorText "[FAIL]" -Color Red
        $errors += "Disconnect failed: $_"
        $success = $false
    }
    
    # Step 2: Remove registry entry
    Write-ColorText "  [2/5] Removing registry entries... " -Color Cyan -NoNewline
    try {
        $regPath = "HKCU:\Network\$letter"
        if (Test-Path $regPath) {
            Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
            Write-ColorText "[OK]" -Color Green
        } else {
            Write-ColorText "[SKIP]" -Color Gray
        }
    } catch {
        Write-ColorText "[FAIL]" -Color Red
        $errors += "Registry removal failed: $_"
    }
    
    # Step 3: Remove mount points
    Write-ColorText "  [3/5] Cleaning mount points... " -Color Cyan -NoNewline
    try {
        $mountPoints = Get-ChildItem "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2" -ErrorAction SilentlyContinue
        $server = ($Path -split '\\')[2]
        $removed = 0
        
        foreach ($mp in $mountPoints) {
            if ($mp.PSChildName -like "*$server*") {
                Remove-Item $mp.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                $removed++
            }
        }
        
        if ($removed -gt 0) {
            Write-ColorText "[OK] ($removed removed)" -Color Green
        } else {
            Write-ColorText "[SKIP]" -Color Gray
        }
    } catch {
        Write-ColorText "[WARN]" -Color Yellow
    }
    
    # Step 4: Remove credentials
    Write-ColorText "  [4/5] Removing stored credentials... " -Color Cyan -NoNewline
    try {
        $cmdkeyPath = "$env:SystemRoot\System32\cmdkey.exe"
        if (Test-Path $cmdkeyPath) {
            $server = ($Path -split '\\')[2]
            $credsRemoved = 0
            
            # Try different credential formats
            @($server, $server.ToUpper(), $server.ToLower(), "TERMSRV/$server", $Path) | ForEach-Object {
                $result = & $cmdkeyPath /delete:"$_" 2>&1
                if ($LASTEXITCODE -eq 0) { $credsRemoved++ }
            }
            
            if ($credsRemoved -gt 0) {
                Write-ColorText "[OK] ($credsRemoved removed)" -Color Green
            } else {
                Write-ColorText "[SKIP]" -Color Gray
            }
        } else {
            Write-ColorText "[SKIP]" -Color Gray
        }
    } catch {
        Write-ColorText "[WARN]" -Color Yellow
    }
    
    # Step 5: Clear from Group Policy (if exists)
    Write-ColorText "  [5/5] Checking Group Policy... " -Color Cyan -NoNewline
    try {
        $gpPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Group Policy\Drives\$letter"
        if (Test-Path $gpPath) {
            Remove-Item -Path $gpPath -Recurse -Force
            Write-ColorText "[OK]" -Color Green
        } else {
            Write-ColorText "[SKIP]" -Color Gray
        }
    } catch {
        Write-ColorText "[SKIP]" -Color Gray
    }
    
    Write-Host
    if ($errors.Count -gt 0) {
        Write-ColorText "  [!] Completed with warnings:" -Color Yellow
        $errors | ForEach-Object { Write-ColorText "    - $_" -Color DarkYellow }
    } else {
        Write-ColorText "  [OK] Drive $letter successfully removed!" -Color Green
    }
    
    return $success
}

function Show-CredentialInfo {
    Write-Host
    Write-ColorText "+-------------------------------------------------------------+" -Color DarkGray
    Write-ColorText "|                   STORED CREDENTIALS                        |" -Color Yellow
    Write-ColorText "+-------------------------------------------------------------+" -Color DarkGray
    
    try {
        $cmdkeyPath = "$env:SystemRoot\System32\cmdkey.exe"
        if (Test-Path $cmdkeyPath) {
            $creds = & $cmdkeyPath /list 2>&1 | Out-String
        } else {
            $creds = ""
        }
        $networkCreds = $creds -split "`n" | Where-Object { $_ -match "Target:.*\\\\|TERMSRV" }
        
        if ($networkCreds.Count -gt 0) {
            Write-ColorText "  Found network credentials:" -Color Cyan
            $networkCreds | ForEach-Object {
                if ($_ -match "Target:\s+(.+)") {
                    Write-ColorText "    * $($matches[1])" -Color DarkYellow
                }
            }
        } else {
            Write-ColorText "  [OK] No network credentials found" -Color Green
        }
    } catch {
        Write-ColorText "  [SKIP] Could not check credentials" -Color Gray
    }
}

# Main Script
Show-Header

Write-ColorText "Scanning for network drives..." -Color Cyan
$drives = Get-NetworkDrives

if (-not (Show-DriveList -Drives $drives)) {
    Write-Host
    Write-ColorText "Press Enter to exit..." -Color DarkGray
    Read-Host
    exit 0
}

# Show credentials
Show-CredentialInfo

# Interactive drive selection
Write-Host
Write-ColorText "+-------------------------------------------------------------+" -Color Magenta
Write-ColorText "|           SELECT DRIVES TO PERMANENTLY REMOVE               |" -Color Magenta
Write-ColorText "+-------------------------------------------------------------+" -Color Magenta
Write-Host
Write-ColorText "Which drives do you want to permanently remove?" -Color Yellow
Write-ColorText "(They will NOT reconnect at startup)" -Color Red
Write-Host

# Show drives with numbers for selection
$driveIndex = 1
$driveMap = @{}
foreach ($drive in $drives) {
    $driveMap[$driveIndex] = $drive
    Write-ColorText "  [$driveIndex] " -Color Cyan -NoNewline
    Write-ColorText "$($drive.Letter): " -Color White -NoNewline
    Write-ColorText "-> $($drive.Path)" -Color DarkYellow
    if ($drive.Persistent) {
        Write-ColorText "      +- " -Color DarkGray -NoNewline
        Write-ColorText "[!] Currently set to reconnect at startup" -Color Red
    }
    $driveIndex++
}

Write-Host
Write-ColorText "Enter your selection:" -Color Cyan
Write-ColorText "  * Single drive: Enter number (e.g., '1')" -Color DarkGray
Write-ColorText "  * Multiple drives: Enter numbers separated by commas (e.g., '1,2,3')" -Color DarkGray
Write-ColorText "  * All drives: Enter 'ALL'" -Color DarkGray
Write-ColorText "  * Cancel: Enter 'Q' or press Enter" -Color DarkGray
Write-Host

Write-ColorText "Your choice: " -Color Yellow -NoNewline
$selection = Read-Host

if ([string]::IsNullOrWhiteSpace($selection) -or $selection.ToUpper() -eq 'Q') {
    Write-ColorText "`nNo changes made. Exiting..." -Color Cyan
    exit 0
}

$drivesToRemove = @()

if ($selection.ToUpper() -eq 'ALL') {
    Write-Host
    Write-ColorText "[!] WARNING: This will permanently remove ALL network drives!" -Color Red
    Write-ColorText "They will NOT reconnect at startup." -Color Yellow
    Write-ColorText "Are you sure? Type 'YES' to confirm: " -Color Red -NoNewline
    $confirm = Read-Host
    if ($confirm -ne 'YES') {
        Write-ColorText "`nOperation cancelled." -Color Yellow
        exit 0
    }
    $drivesToRemove = $drives
} else {
    # Parse selected numbers
    $selectedNumbers = $selection -split ',' | ForEach-Object { 
        $num = $_.Trim()
        if ($num -match '^\d+$') { [int]$num } 
    }
    
    foreach ($num in $selectedNumbers) {
        if ($driveMap.ContainsKey($num)) {
            $drivesToRemove += $driveMap[$num]
        } else {
            Write-ColorText "  [!] Invalid selection: $num (skipped)" -Color Yellow
        }
    }
}

if ($drivesToRemove.Count -eq 0) {
    Write-ColorText "`nNo valid drives selected. Exiting..." -Color Yellow
    exit 0
}

# Confirm selection
Write-Host
Write-ColorText "----------------------------------------------------------------" -Color DarkGray
Write-ColorText "You have selected the following drives for PERMANENT removal:" -Color Yellow
foreach ($drive in $drivesToRemove) {
    Write-ColorText "  * $($drive.Letter): -> $($drive.Path)" -Color Cyan
}
Write-ColorText "----------------------------------------------------------------" -Color DarkGray

Write-Host
Write-ColorText "Proceed with removal? (Y/N): " -Color Yellow -NoNewline
$proceed = Read-Host

if ($proceed.ToUpper() -ne 'Y') {
    Write-ColorText "`nOperation cancelled." -Color Yellow
    exit 0
}

# Remove selected drives
foreach ($drive in $drivesToRemove) {
    Remove-NetworkDrive -DriveLetter $drive.Letter -Path $drive.Path
}

# Ask about credentials
Write-Host
Write-ColorText "----------------------------------------------------------------" -Color DarkGray
Write-ColorText "Do you also want to clear stored credentials for these drives?" -Color Yellow
Write-ColorText "(This ensures they won't auto-reconnect with saved passwords)" -Color DarkGray
Write-ColorText "Clear credentials? (Y/N): " -Color Cyan -NoNewline
$clearCreds = Read-Host

if ($clearCreds.ToUpper() -eq 'Y') {
    Write-Host
    Write-ColorText "Clearing related credentials..." -Color Cyan
    $cmdkeyPath = "$env:SystemRoot\System32\cmdkey.exe"
    if (Test-Path $cmdkeyPath) {
        foreach ($drive in $drivesToRemove) {
            $server = ($drive.Path -split '\\')[2]
            @($server, $server.ToUpper(), $server.ToLower(), "TERMSRV/$server", $drive.Path) | ForEach-Object {
                $result = & $cmdkeyPath /delete:"$_" 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorText "  Removed credential: $_" -Color DarkYellow
                }
            }
        }
        Write-ColorText "[OK] Credentials cleared!" -Color Green
    } else {
        Write-ColorText "[SKIP] Could not access credential manager" -Color Yellow
    }
}

# Offer to restart Explorer
Write-Host
Write-ColorText "----------------------------------------------------------------" -Color DarkGray
Write-ColorText "To apply all changes, Windows Explorer needs to restart." -Color Yellow
Write-ColorText "Restart Explorer now? (Y/N): " -Color Cyan -NoNewline
$restart = Read-Host

if ($restart -eq 'Y' -or $restart -eq 'y') {
    Write-ColorText "Restarting Explorer..." -Color Yellow
    Stop-Process -Name explorer -Force
    Start-Sleep -Seconds 2
    Start-Process explorer
    Write-ColorText "[OK] Explorer restarted successfully!" -Color Green
}

Write-Host
Write-ColorText "================================================================" -Color Cyan
Write-ColorText "                     OPERATION COMPLETE                        " -Color Green
Write-ColorText "================================================================" -Color Cyan
Write-Host
Write-ColorText "Press Enter to exit..." -Color DarkGray
Read-Host