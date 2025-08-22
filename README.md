# Network Drive Removal Tool

**Administrative utility for permanently removing persistent network drives from Windows systems.**

Completely removes network drive mappings, registry entries, stored credentials, and mount points to prevent automatic reconnection after reboot.

---

## Quick Start

### For Helpdesk/End Users (Launcher)
1. Download `NetworkDriveRemover-Launcher.ps1`
2. Right-click → **Run with PowerShell**
3. Select **[1] GUI Application**
4. Select drives to remove → Click **Remove Selected**
5. Done.

### For IT Professionals (CLI)
```powershell
# Run as Administrator
.\Remove-NetworkDrives.ps1
```

---

## System Requirements

- **Windows 7+** (Windows 10/11 preferred)
- **Administrator privileges** (required for complete cleanup)
- **PowerShell 5.0+** (required for all scripts)

---

## Installation Options

### Option 1: PowerShell Launcher (Recommended)
- Download: `NetworkDriveRemover-Launcher.ps1`
- Menu-driven interface to select GUI or CLI
- No installation required
- Works on any Windows system with PowerShell

### Option 2: Individual Scripts
- Download: `Remove-NetworkDrives.ps1` (CLI) or `Remove-NetworkDrives-GUI.ps1` (GUI)
- Direct access to specific interface
- Full source code access

---

## Usage Instructions

### PowerShell Launcher (Recommended)

**Step 1: Launch Launcher**
- Right-click `NetworkDriveRemover-Launcher.ps1` → "Run with PowerShell"
- **IMPORTANT**: Choose "Run as Administrator" if prompted for full functionality

**Step 2: Select Interface**
- **[1] GUI Application** - Windows Forms interface (best for helpdesk)
- **[2] CLI Application** - Interactive console (best for IT pros)
- **[3] Help** - Built-in documentation
- **[4] System Info** - Compatibility check

### GUI Application (Via Launcher)

**After selecting [1] GUI Application from launcher:**

**Step 1: Review Detected Drives**
- Left panel shows all network drives with status:
  - **Persistent** = Will reconnect at startup (TARGET FOR REMOVAL)
  - **Temporary** = Session-only connection
- Right panel shows stored network credentials

**Step 2: Select Drives to Remove**
- Click drives to select (Ctrl+click for multiple)
- **DO NOT** select drives still needed by user
- Use "Select All" only if removing ALL network access

**Step 3: Configure Options**
- ☑ **Clear stored credentials**: Recommended (prevents auto-reconnect)
- ☐ **Restart Windows Explorer**: Only if immediate effect needed

**Step 4: Execute Removal**
- Click **Remove Selected**
- Confirm when prompted
- Monitor progress window for any errors
- **Success** = All steps show [OK] or [SKIP]

### CLI Application (Via Launcher or Direct)

**Method 1: Via Launcher**
- Select **[2] CLI Application** from launcher menu

**Method 2: Direct Execution**
```powershell
# Enable script execution (first time only)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Run CLI directly
.\Remove-NetworkDrives.ps1

# Auto-confirm mode (advanced)
.\Remove-NetworkDrives.ps1 -AutoConfirm
```

**CLI Process:**
- Review drive table (Persistent drives marked in RED)
- Enter drive numbers to remove: `1,2,3` or `ALL`
- Confirm with `Y`
- Monitor 5-step removal process per drive

---

## Removal Process Explained

**Each drive undergoes 5 cleanup steps:**

1. **[1/5] Disconnect Drive** - `net use X: /delete`
2. **[2/5] Registry Cleanup** - Remove `HKCU:\Network\[Drive]`
3. **[3/5] Mount Points** - Clear Explorer mount cache
4. **[4/5] Credentials** - Remove stored passwords via `cmdkey`
5. **[5/5] Group Policy** - Clear GP-managed mappings

**Status Indicators:**
- **[OK]** = Step completed successfully
- **[SKIP]** = Nothing to clean (normal)
- **[WARN]** = Minor issue, continuing
- **[FAIL]** = Step failed (may need manual intervention)

---

## Common Issues & Solutions

### "Access Denied" Errors
**Solution**: Must run as Administrator
```powershell
# Check if running as admin
[Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains 'S-1-5-32-544'
```

### "Script Execution Disabled"
**Solution**: Adjust PowerShell execution policy
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Drive Reappears After Removal
**Cause**: Group Policy or login script re-mapping
**Solution**: Contact IT administrator to check:
- Computer Configuration → Preferences → Drive Maps
- Login scripts in `\\domain\SYSVOL`
- Third-party management software

### Incomplete Removal
**Verification Commands:**
```powershell
# Check remaining drives
net use

# Check registry persistence
Get-ChildItem "HKCU:\Network\" -ErrorAction SilentlyContinue

# Check credentials
cmdkey /list | findstr "Target:"
```

### Manual Cleanup (If Tool Fails)
```powershell
# Force disconnect
net use X: /delete /y

# Manual registry cleanup
Remove-Item "HKCU:\Network\X" -Recurse -Force

# Manual credential removal
cmdkey /delete:"\\server"
```

---

## Safety & Security

### Pre-Removal Checklist
- [ ] User has alternative access to needed resources
- [ ] No open files on target drives
- [ ] Backup important UNC paths for re-mapping
- [ ] Verify drives aren't managed by Group Policy

### What This Tool Does NOT Do
- ❌ Delete user data
- ❌ Modify server-side permissions  
- ❌ Affect other users' access
- ❌ Remove actual network shares

### Audit Trail
- All actions logged to console/GUI
- Registry changes are reversible
- Credentials can be re-entered manually

---

## Technical Details

### Registry Locations Cleaned
```
HKCU:\Network\[DriveLetter]
HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2\
HKCU:\Software\Microsoft\Windows\CurrentVersion\Group Policy\Drives\
```

### Credential Storage
- Windows Credential Manager (`cmdkey.exe`)
- Multiple formats checked: server name, FQDN, UNC path

### Network Commands Used
- `Get-PSDrive` - Drive enumeration
- `net use` - Drive disconnection
- `cmdkey` - Credential management

---

## Distribution Files

| File | Purpose | Best For |
|------|---------|----------|
| `NetworkDriveRemover-Launcher.ps1` | Menu-driven launcher | Universal distribution |
| `Remove-NetworkDrives.ps1` | CLI PowerShell script | IT automation |
| `Remove-NetworkDrives-GUI.ps1` | GUI PowerShell script | Direct GUI access |
| `README.md` | Documentation | Setup instructions |

---

## Support

**For Technical Issues:**
1. Check Windows Event Logs (Application/System)
2. Run with Administrator privileges
3. Verify PowerShell execution policy
4. Test with single drive first

**For Policy Issues:**
1. Check Group Policy Management Console
2. Review login scripts
3. Verify user permissions
4. Contact domain administrator

---

---

## License & Attribution

**License**: Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)

**Terms:**
- ✅ **Free use** for personal, educational, and non-commercial purposes
- ✅ **Attribution required** - Must credit original author
- ✅ **Modification allowed** - Can adapt and build upon
- ✅ **Distribution allowed** - Can share with proper attribution
- ❌ **No commercial use** - Cannot sell or use commercially without permission
- ❌ **No warranty** - Provided as-is

**Attribution Format:**
```
Network Mount Destroyer by z3r0-c001
https://github.com/z3r0-c001/network-mount-destroyer
Licensed under CC BY-NC 4.0
```

**Disclaimer**: This tool modifies Windows system configuration. Ensure proper authorization before use in corporate environments. Author assumes no liability for system changes or data loss.