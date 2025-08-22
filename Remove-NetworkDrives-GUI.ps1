#Requires -Version 5.0
<#
.SYNOPSIS
    GUI application to permanently remove persistent network drives
.DESCRIPTION
    Windows Forms-based GUI for removing network drives and all associated 
    registry entries, credentials, and mount points to prevent reconnection
#>

param(
    [switch]$DebugMode
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global variables
$script:drives = @()
$script:selectedDrives = @()

#region Core Functions (from original script)
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

function Remove-NetworkDrive {
    param(
        [string]$DriveLetter,
        [string]$Path,
        [System.Windows.Forms.TextBox]$LogTextBox
    )
    
    $letter = $DriveLetter.TrimEnd(':')
    $success = $true
    $errors = @()
    
    $LogTextBox.AppendText("`r`n================================================================`r`n")
    $LogTextBox.AppendText("Removing Drive ${letter}: ($Path)`r`n")
    $LogTextBox.AppendText("================================================================`r`n")
    $LogTextBox.Refresh()
    
    # Step 1: Disconnect network drive
    $LogTextBox.AppendText("[1/5] Disconnecting network drive... ")
    $LogTextBox.Refresh()
    try {
        $result = net use "${letter}:" /delete /y 2>&1
        if ($LASTEXITCODE -eq 0) {
            $LogTextBox.AppendText("[OK]`r`n")
        } else {
            $LogTextBox.AppendText("[WARN] - May already be disconnected`r`n")
            $errors += "Disconnect warning: May already be disconnected"
        }
    } catch {
        $LogTextBox.AppendText("[FAIL]`r`n")
        $errors += "Disconnect failed: $_"
        $success = $false
    }
    $LogTextBox.Refresh()
    
    # Step 2: Remove registry entry
    $LogTextBox.AppendText("[2/5] Removing registry entries... ")
    $LogTextBox.Refresh()
    try {
        $regPath = "HKCU:\Network\$letter"
        if (Test-Path $regPath) {
            Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
            $LogTextBox.AppendText("[OK]`r`n")
        } else {
            $LogTextBox.AppendText("[SKIP] - No registry entry found`r`n")
        }
    } catch {
        $LogTextBox.AppendText("[FAIL]`r`n")
        $errors += "Registry removal failed: $_"
    }
    $LogTextBox.Refresh()
    
    # Step 3: Remove mount points
    $LogTextBox.AppendText("[3/5] Cleaning mount points... ")
    $LogTextBox.Refresh()
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
            $LogTextBox.AppendText("[OK] ($removed removed)`r`n")
        } else {
            $LogTextBox.AppendText("[SKIP] - No mount points found`r`n")
        }
    } catch {
        $LogTextBox.AppendText("[WARN]`r`n")
    }
    $LogTextBox.Refresh()
    
    # Step 4: Remove credentials
    $LogTextBox.AppendText("[4/5] Removing stored credentials... ")
    $LogTextBox.Refresh()
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
                $LogTextBox.AppendText("[OK] ($credsRemoved removed)`r`n")
            } else {
                $LogTextBox.AppendText("[SKIP] - No credentials found`r`n")
            }
        } else {
            $LogTextBox.AppendText("[SKIP] - cmdkey not available`r`n")
        }
    } catch {
        $LogTextBox.AppendText("[WARN]`r`n")
    }
    $LogTextBox.Refresh()
    
    # Step 5: Clear from Group Policy (if exists)
    $LogTextBox.AppendText("[5/5] Checking Group Policy... ")
    $LogTextBox.Refresh()
    try {
        $gpPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Group Policy\Drives\$letter"
        if (Test-Path $gpPath) {
            Remove-Item -Path $gpPath -Recurse -Force
            $LogTextBox.AppendText("[OK]`r`n")
        } else {
            $LogTextBox.AppendText("[SKIP] - No GP entries found`r`n")
        }
    } catch {
        $LogTextBox.AppendText("[SKIP]`r`n")
    }
    $LogTextBox.Refresh()
    
    if ($errors.Count -gt 0) {
        $LogTextBox.AppendText("`r`nCompleted with warnings:`r`n")
        $errors | ForEach-Object { $LogTextBox.AppendText("  - $_`r`n") }
    } else {
        $LogTextBox.AppendText("`r`n[SUCCESS] Drive $letter successfully removed!`r`n")
    }
    $LogTextBox.Refresh()
    
    return $success
}

function Get-StoredCredentials {
    try {
        $cmdkeyPath = "$env:SystemRoot\System32\cmdkey.exe"
        if (Test-Path $cmdkeyPath) {
            $creds = & $cmdkeyPath /list 2>&1 | Out-String
        } else {
            return @()
        }
        $networkCreds = $creds -split "`n" | Where-Object { $_ -match "Target:.*\\\\|TERMSRV" }
        
        $credList = @()
        $networkCreds | ForEach-Object {
            if ($_ -match "Target:\s+(.+)") {
                $credList += $matches[1].Trim()
            }
        }
        return $credList
    } catch {
        return @()
    }
}
#endregion

#region GUI Functions
function Update-DriveList {
    param($ListBox)
    
    $script:drives = Get-NetworkDrives
    $ListBox.Items.Clear()
    
    foreach ($drive in $script:drives) {
        $status = if ($drive.Persistent) { "Persistent" } else { "Temporary" }
        $item = "$($drive.Letter): -> $($drive.Path) [$status]"
        $ListBox.Items.Add($item)
    }
    
    if ($script:drives.Count -eq 0) {
        $ListBox.Items.Add("No network drives found")
    }
}

function Update-CredentialsList {
    param($ListBox)
    
    $creds = Get-StoredCredentials
    $ListBox.Items.Clear()
    
    if ($creds.Count -gt 0) {
        foreach ($cred in $creds) {
            $ListBox.Items.Add($cred)
        }
    } else {
        $ListBox.Items.Add("No network credentials found")
    }
}

function Show-RemovalProcess {
    param($DrivesToRemove)
    
    # Create progress form
    $progressForm = New-Object System.Windows.Forms.Form
    $progressForm.Text = "Removing Network Drives"
    $progressForm.Size = New-Object System.Drawing.Size(600, 500)
    $progressForm.StartPosition = "CenterParent"
    $progressForm.FormBorderStyle = "FixedDialog"
    $progressForm.MaximizeBox = $false
    
    # Progress bar
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 20)
    $progressBar.Size = New-Object System.Drawing.Size(540, 23)
    $progressBar.Maximum = $DrivesToRemove.Count
    $progressForm.Controls.Add($progressBar)
    
    # Log text box
    $logTextBox = New-Object System.Windows.Forms.TextBox
    $logTextBox.Location = New-Object System.Drawing.Point(20, 60)
    $logTextBox.Size = New-Object System.Drawing.Size(540, 350)
    $logTextBox.Multiline = $true
    $logTextBox.ScrollBars = "Vertical"
    $logTextBox.ReadOnly = $true
    $logTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $progressForm.Controls.Add($logTextBox)
    
    # Close button
    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Point(480, 430)
    $closeButton.Size = New-Object System.Drawing.Size(80, 25)
    $closeButton.Text = "Close"
    $closeButton.Enabled = $false
    $closeButton.Add_Click({ $progressForm.Close() })
    $progressForm.Controls.Add($closeButton)
    
    $progressForm.Show()
    
    # Process removals
    $counter = 0
    foreach ($drive in $DrivesToRemove) {
        $counter++
        $progressBar.Value = $counter
        
        Remove-NetworkDrive -DriveLetter $drive.Letter -Path $drive.Path -LogTextBox $logTextBox
        
        [System.Windows.Forms.Application]::DoEvents()
    }
    
    $logTextBox.AppendText("`r`n================================================================`r`n")
    $logTextBox.AppendText("OPERATION COMPLETE - All selected drives have been processed`r`n")
    $logTextBox.AppendText("================================================================`r`n")
    
    $closeButton.Enabled = $true
    $progressForm.ShowDialog()
}
#endregion

#region Main GUI
function Show-MainForm {
    # Main form
    $mainForm = New-Object System.Windows.Forms.Form
    $mainForm.Text = "Network Drive Removal Tool"
    $mainForm.Size = New-Object System.Drawing.Size(800, 600)
    $mainForm.StartPosition = "CenterScreen"
    $mainForm.MaximizeBox = $false
    
    # Title label
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $titleLabel.Size = New-Object System.Drawing.Size(740, 30)
    $titleLabel.Text = "Network Drive Permanent Removal Tool"
    $titleLabel.Font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold)
    $titleLabel.TextAlign = "MiddleCenter"
    $mainForm.Controls.Add($titleLabel)
    
    # Warning label
    $warningLabel = New-Object System.Windows.Forms.Label
    $warningLabel.Location = New-Object System.Drawing.Point(20, 60)
    $warningLabel.Size = New-Object System.Drawing.Size(740, 40)
    $warningLabel.Text = "WARNING: This tool permanently removes network drives. They will NOT reconnect at startup."
    $warningLabel.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $warningLabel.ForeColor = [System.Drawing.Color]::Red
    $warningLabel.TextAlign = "MiddleCenter"
    $mainForm.Controls.Add($warningLabel)
    
    # Drives group box
    $drivesGroupBox = New-Object System.Windows.Forms.GroupBox
    $drivesGroupBox.Location = New-Object System.Drawing.Point(20, 110)
    $drivesGroupBox.Size = New-Object System.Drawing.Size(360, 300)
    $drivesGroupBox.Text = "Network Drives"
    $mainForm.Controls.Add($drivesGroupBox)
    
    # Drives list box
    $drivesListBox = New-Object System.Windows.Forms.ListBox
    $drivesListBox.Location = New-Object System.Drawing.Point(10, 25)
    $drivesListBox.Size = New-Object System.Drawing.Size(340, 240)
    $drivesListBox.SelectionMode = "MultiExtended"
    $drivesGroupBox.Controls.Add($drivesListBox)
    
    # Refresh drives button
    $refreshButton = New-Object System.Windows.Forms.Button
    $refreshButton.Location = New-Object System.Drawing.Point(10, 270)
    $refreshButton.Size = New-Object System.Drawing.Size(80, 25)
    $refreshButton.Text = "Refresh"
    $refreshButton.Add_Click({ Update-DriveList -ListBox $drivesListBox })
    $drivesGroupBox.Controls.Add($refreshButton)
    
    # Select all button
    $selectAllButton = New-Object System.Windows.Forms.Button
    $selectAllButton.Location = New-Object System.Drawing.Point(100, 270)
    $selectAllButton.Size = New-Object System.Drawing.Size(80, 25)
    $selectAllButton.Text = "Select All"
    $selectAllButton.Add_Click({ 
        for ($i = 0; $i -lt $drivesListBox.Items.Count; $i++) {
            $drivesListBox.SetSelected($i, $true)
        }
    })
    $drivesGroupBox.Controls.Add($selectAllButton)
    
    # Clear selection button
    $clearButton = New-Object System.Windows.Forms.Button
    $clearButton.Location = New-Object System.Drawing.Point(190, 270)
    $clearButton.Size = New-Object System.Drawing.Size(80, 25)
    $clearButton.Text = "Clear"
    $clearButton.Add_Click({ $drivesListBox.ClearSelected() })
    $drivesGroupBox.Controls.Add($clearButton)
    
    # Credentials group box
    $credsGroupBox = New-Object System.Windows.Forms.GroupBox
    $credsGroupBox.Location = New-Object System.Drawing.Point(400, 110)
    $credsGroupBox.Size = New-Object System.Drawing.Size(360, 200)
    $credsGroupBox.Text = "Stored Network Credentials"
    $mainForm.Controls.Add($credsGroupBox)
    
    # Credentials list box
    $credsListBox = New-Object System.Windows.Forms.ListBox
    $credsListBox.Location = New-Object System.Drawing.Point(10, 25)
    $credsListBox.Size = New-Object System.Drawing.Size(340, 140)
    $credsGroupBox.Controls.Add($credsListBox)
    
    # Refresh credentials button
    $refreshCredsButton = New-Object System.Windows.Forms.Button
    $refreshCredsButton.Location = New-Object System.Drawing.Point(10, 170)
    $refreshCredsButton.Size = New-Object System.Drawing.Size(100, 25)
    $refreshCredsButton.Text = "Refresh Creds"
    $refreshCredsButton.Add_Click({ Update-CredentialsList -ListBox $credsListBox })
    $credsGroupBox.Controls.Add($refreshCredsButton)
    
    # Options group box
    $optionsGroupBox = New-Object System.Windows.Forms.GroupBox
    $optionsGroupBox.Location = New-Object System.Drawing.Point(400, 330)
    $optionsGroupBox.Size = New-Object System.Drawing.Size(360, 80)
    $optionsGroupBox.Text = "Options"
    $mainForm.Controls.Add($optionsGroupBox)
    
    # Clear credentials checkbox
    $clearCredsCheckBox = New-Object System.Windows.Forms.CheckBox
    $clearCredsCheckBox.Location = New-Object System.Drawing.Point(20, 25)
    $clearCredsCheckBox.Size = New-Object System.Drawing.Size(200, 20)
    $clearCredsCheckBox.Text = "Clear stored credentials"
    $clearCredsCheckBox.Checked = $true
    $optionsGroupBox.Controls.Add($clearCredsCheckBox)
    
    # Restart Explorer checkbox
    $restartExplorerCheckBox = New-Object System.Windows.Forms.CheckBox
    $restartExplorerCheckBox.Location = New-Object System.Drawing.Point(20, 50)
    $restartExplorerCheckBox.Size = New-Object System.Drawing.Size(200, 20)
    $restartExplorerCheckBox.Text = "Restart Windows Explorer"
    $restartExplorerCheckBox.Checked = $false
    $optionsGroupBox.Controls.Add($restartExplorerCheckBox)
    
    # Remove button
    $removeButton = New-Object System.Windows.Forms.Button
    $removeButton.Location = New-Object System.Drawing.Point(600, 500)
    $removeButton.Size = New-Object System.Drawing.Size(120, 35)
    $removeButton.Text = "Remove Selected"
    $removeButton.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $removeButton.BackColor = [System.Drawing.Color]::IndianRed
    $removeButton.ForeColor = [System.Drawing.Color]::White
    $removeButton.Add_Click({
        $selectedIndices = $drivesListBox.SelectedIndices
        if ($selectedIndices.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select at least one drive to remove.", "No Selection", "OK", "Warning")
            return
        }
        
        $selectedDrives = @()
        foreach ($index in $selectedIndices) {
            if ($index -lt $script:drives.Count) {
                $selectedDrives += $script:drives[$index]
            }
        }
        
        $driveList = ($selectedDrives | ForEach-Object { "$($_.Letter): -> $($_.Path)" }) -join "`n"
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Are you sure you want to permanently remove these drives?`n`n$driveList`n`nThey will NOT reconnect at startup.",
            "Confirm Removal",
            "YesNo",
            "Warning"
        )
        
        if ($result -eq "Yes") {
            Show-RemovalProcess -DrivesToRemove $selectedDrives
            
            # Clear credentials if requested
            if ($clearCredsCheckBox.Checked) {
                # This would be handled in the removal process
            }
            
            # Restart Explorer if requested
            if ($restartExplorerCheckBox.Checked) {
                try {
                    Stop-Process -Name explorer -Force
                    Start-Sleep -Seconds 2
                    Start-Process explorer
                    [System.Windows.Forms.MessageBox]::Show("Windows Explorer has been restarted.", "Explorer Restarted", "OK", "Information")
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Failed to restart Explorer: $_", "Error", "OK", "Error")
                }
            }
            
            # Refresh the lists
            Update-DriveList -ListBox $drivesListBox
            Update-CredentialsList -ListBox $credsListBox
        }
    })
    $mainForm.Controls.Add($removeButton)
    
    # Exit button
    $exitButton = New-Object System.Windows.Forms.Button
    $exitButton.Location = New-Object System.Drawing.Point(470, 500)
    $exitButton.Size = New-Object System.Drawing.Size(120, 35)
    $exitButton.Text = "Exit"
    $exitButton.Add_Click({ $mainForm.Close() })
    $mainForm.Controls.Add($exitButton)
    
    # Help button
    $helpButton = New-Object System.Windows.Forms.Button
    $helpButton.Location = New-Object System.Drawing.Point(20, 500)
    $helpButton.Size = New-Object System.Drawing.Size(80, 35)
    $helpButton.Text = "Help"
    $helpButton.Add_Click({
        $helpText = @"
Network Drive Removal Tool - Help

This tool permanently removes network drives from your system.

Usage:
1. The tool automatically scans for network drives when started
2. Select one or more drives from the list on the left
3. Review stored credentials on the right (optional)
4. Choose options:
   - Clear stored credentials: Removes saved passwords
   - Restart Explorer: Applies changes immediately
5. Click 'Remove Selected' to begin removal

Important Notes:
- This action is permanent
- Drives will NOT reconnect at startup
- Ensure you have alternative access to network resources
- Save any open files on network drives before removal

For detailed information, see the README.md file.
"@
        [System.Windows.Forms.MessageBox]::Show($helpText, "Help", "OK", "Information")
    })
    $mainForm.Controls.Add($helpButton)
    
    # Initialize data
    Update-DriveList -ListBox $drivesListBox
    Update-CredentialsList -ListBox $credsListBox
    
    # Show form
    [System.Windows.Forms.Application]::Run($mainForm)
}
#endregion

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin -and -not $DebugMode) {
    $result = [System.Windows.Forms.MessageBox]::Show(
        "This application works best when run as Administrator.`n`nWould you like to continue anyway?`n`n(Some features may not work correctly)",
        "Administrator Privileges Recommended",
        "YesNo",
        "Warning"
    )
    
    if ($result -eq "No") {
        exit 0
    }
}

# Start the GUI
Show-MainForm