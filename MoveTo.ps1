# MoveTo.ps1 - Clipboard CUT + smart paste (fire-and-forget)
# Reads selected items, clipboard CUT, finds/opens destination, Ctrl+V, EXIT.
# Script exits immediately — Explorer handles transfer in background.

param(
    [string]$SourcePath,
    [string]$DestPath
)

Add-Type -AssemblyName System.Windows.Forms

# P/Invoke for window focus
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinFocus {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

$shell = New-Object -ComObject Shell.Application
$sourceParent = Split-Path $SourcePath -Parent

# ===== Read ALL selected items from Explorer =====
$selectedPaths = @()

foreach ($win in $shell.Windows()) {
    try {
        $winPath = $win.Document.Folder.Self.Path
        if ($winPath -eq $sourceParent) {
            foreach ($item in $win.Document.SelectedItems()) {
                $selectedPaths += $item.Path
            }
            break
        }
    } catch { }
}

if ($selectedPaths.Count -eq 0) {
    $selectedPaths = @($SourcePath)
}

# ===== Clipboard CUT (same as Ctrl+X) =====
$files = New-Object System.Collections.Specialized.StringCollection
foreach ($p in $selectedPaths) { [void]$files.Add($p) }

$data = New-Object System.Windows.Forms.DataObject
$data.SetFileDropList($files)

$moveBytes = [byte[]]@(2, 0, 0, 0)
$stream = New-Object System.IO.MemoryStream(, $moveBytes)
$data.SetData("Preferred DropEffect", $stream)

[System.Windows.Forms.Clipboard]::SetDataObject($data, $true)

# ===== Find existing destination window OR open new =====
$destWin = $null

foreach ($win in $shell.Windows()) {
    try {
        if ($win.Document.Folder.Self.Path -eq $DestPath) {
            $destWin = $win
            break
        }
    } catch { }
}

if ($destWin) {
    # Destination already open — just bring to front (NO new window)
    $hwnd = [IntPtr]$destWin.HWND
    [WinFocus]::ShowWindow($hwnd, 9) | Out-Null   # SW_RESTORE
    [WinFocus]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 400
} else {
    # Not open — open new Explorer window
    $shell.Open($DestPath)
    Start-Sleep -Milliseconds 900
}

# ===== Paste (Ctrl+V) — fire and forget =====
[System.Windows.Forms.SendKeys]::SendWait("^v")

# ===== EXIT IMMEDIATELY — no blocking, no ghost process =====
try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null } catch { }
