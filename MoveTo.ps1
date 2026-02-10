# MoveTo.ps1 - Clipboard CUT + Shell paste (fire-and-forget)
# Reuses existing destination window if found, otherwise opens new.
# Script exits immediately after paste — Explorer handles transfer.

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

# Debug log
$logFile = "$env:TEMP\MoveTo_debug.log"
function Log($msg) {
    "$((Get-Date).ToString('HH:mm:ss.fff')) | $msg" | Out-File $logFile -Append -Encoding utf8
}

Log "===== START ====="
Log "Source: $SourcePath"
Log "Dest:   $DestPath"
Log "PID:    $PID"

$shell = New-Object -ComObject Shell.Application
$sourceParent = Split-Path $SourcePath -Parent

# ===== Read ALL selected items from source Explorer window =====
$selectedPaths = [System.Collections.Generic.List[string]]::new()

foreach ($win in $shell.Windows()) {
    try {
        $winPath = $win.Document.Folder.Self.Path
        if ($winPath -eq $sourceParent) {
            foreach ($item in $win.Document.SelectedItems()) {
                $selectedPaths.Add($item.Path)
            }
            break
        }
    } catch { }
}

if ($selectedPaths.Count -eq 0) {
    $selectedPaths.Add($SourcePath)
}

Log "Selected: $($selectedPaths.Count) items"

# ===== Clipboard CUT (same as Ctrl+X) =====
$files = New-Object System.Collections.Specialized.StringCollection
foreach ($p in $selectedPaths) { [void]$files.Add($p) }

$data = New-Object System.Windows.Forms.DataObject
$data.SetFileDropList($files)
$data.SetData("Preferred DropEffect", [System.IO.MemoryStream]::new([byte[]]@(2,0,0,0)))
[System.Windows.Forms.Clipboard]::SetDataObject($data, $true)

Log "Clipboard CUT done"

# ===== Find existing dest window OR open new =====
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
    # Destination already open — just focus it
    Log "Destination already open, focusing"
    $hwnd = [IntPtr]$destWin.HWND
    [WinFocus]::ShowWindow($hwnd, 9) | Out-Null
    [WinFocus]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 400
} else {
    # Open destination in new Explorer window
    Log "Opening destination in new window"
    $shell.Open($DestPath)
    Start-Sleep -Milliseconds 1200

    # Find and focus the new window
    foreach ($win in $shell.Windows()) {
        try {
            if ($win.Document.Folder.Self.Path -eq $DestPath) {
                $hwnd = [IntPtr]$win.HWND
                [WinFocus]::SetForegroundWindow($hwnd) | Out-Null
                break
            }
        } catch { }
    }
    Start-Sleep -Milliseconds 300
}

Log "Window ready, sending Ctrl+V"

# ===== Paste — fire and forget =====
[System.Windows.Forms.SendKeys]::SendWait("^v")

Log "Paste sent"
Log "===== END ====="

# EXIT — Explorer handles transfer in background
try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null } catch { }
