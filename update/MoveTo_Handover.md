# Move To - Handover & Restoration Instructions

Use these instructions in a NEW CHAT to restore the `EditDestinations` Menu and the `Icon Fix` logic, even when starting from an older backup.

## 1. Goal
We need to add the **"Edit Destinations" Menu** (CLI) and the **"Icon Fix" logic** to our project as companion scripts.

## 2. File: `SyncMoveToMenu.ps1` (with Icon Fix)
This script syncs shortcuts to the Registry **AND** extracts their icons correctly (from `.lnk` or `desktop.ini`).

**Crucial Logic to Add:**
```powershell
    # Read shortcut
    $lnk = $shell.CreateShortcut($sc.FullName)
    $targetPath = $lnk.TargetPath
    $iconFromLnk = $lnk.IconLocation
    
    # Default icon
    $icon = "imageres.dll,-3"
    
    # 1. Try shortcut's IconLocation
    if ($iconFromLnk -and $iconFromLnk -ne ",0") {
        $icon = $iconFromLnk
    }
    # 2. Try target folder's desktop.ini (The "Icon Fix")
    elseif ($targetPath -and (Test-Path $targetPath -PathType Container)) {
        $desktopIni = Join-Path $targetPath "desktop.ini"
        if (Test-Path $desktopIni) {
            $content = Get-Content $desktopIni -Raw -ErrorAction SilentlyContinue
            if ($content -match 'IconResource=(.+)') {
                $icon = $matches[1].Trim()
            }
        }
    }
    
    # Apply to Registry
    Set-ItemProperty -LiteralPath $keyPath -Name "Icon" -Value $icon
```

## 3. File: `EditDestinations.ps1` (The Menu)
This script allows adding/removing destinations and refreshing the menu.

**Logic to Create:**
```powershell
# EditDestinations.ps1 - Interactive Menu
$destinationsFolder = "D:\Users\joty79\scripts\MoveTo\destinations"
$syncScript = "D:\Users\joty79\scripts\MoveTo\SyncMoveToMenu.ps1"

function Show-Menu {
    Clear-Host
    Write-Host "MOVE TO - EDIT DESTINATIONS" -ForegroundColor Cyan
    $shortcuts = Get-ChildItem -Path $destinationsFolder -Filter "*.lnk"
    
    if (-not $shortcuts) { Write-Host "(no destinations)" -ForegroundColor Yellow }
    else {
        $i = 1
        foreach ($sc in $shortcuts) {
            $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut($sc.FullName)
            Write-Host "[$i] $($sc.BaseName) -> $($lnk.TargetPath)"
            $i++
        }
    }
    
    Write-Host "`n[R] Refresh Menu (Sync & Fix Icons)" -ForegroundColor Green
    Write-Host "[O] Open Folder" -ForegroundColor Green
    Write-Host "[Q] Quit" -ForegroundColor Green
    Write-Host "Type number to DELETE" -ForegroundColor Red
    return $shortcuts
}

while ($true) {
    if (Test-Path $destinationsFolder) {
        $shortcuts = Show-Menu
        $input = Read-Host ">"
        if ($input -eq 'q') { break }
        if ($input -eq 'r') { & $syncScript; Read-Host "Done!" }
        if ($input -eq 'o') { Invoke-Item $destinationsFolder }
        if ($input -match '^\d+$') {
            $idx = [int]$input - 1
            if ($shortcuts[$idx]) {
                Remove-Item $shortcuts[$idx].FullName
                & $syncScript
            }
        }
    }
}
```

## 4. Connection
- **EditDestinations.ps1** allows you to manage the folder.
- When you press **[R]**, it calls **SyncMoveToMenu.ps1**.
- **SyncMoveToMenu.ps1** reads the folder, fixes the icons (using the logic above), and updates the Context Menu.
