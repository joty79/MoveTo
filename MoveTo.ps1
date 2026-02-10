# MoveTo.ps1 - Pure SendKeys (Explorer does EVERYTHING natively)
# Step 1: Focus source window → Ctrl+X (Explorer handles cut)
# Step 2: Navigate address bar to destination → Enter
# Step 3: Ctrl+V (Explorer handles paste)
# Script exits immediately — ZERO clipboard manipulation from our side.

param(
    [string]$SourcePath,
    [string]$DestPath
)

Add-Type -AssemblyName System.Windows.Forms

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

# ===== Find source Explorer window =====
$sourceWin = $null
foreach ($win in $shell.Windows()) {
    try {
        if ($win.Document.Folder.Self.Path -eq $sourceParent) {
            $sourceWin = $win
            break
        }
    } catch { }
}

if (-not $sourceWin) {
    Log "ERROR: Source window not found"
    exit 1
}

$hwnd = [IntPtr]$sourceWin.HWND
Log "Source window found: HWND=$hwnd"

# ===== Step 1: Focus source window + Ctrl+X (EXPLORER cuts natively) =====
[WinFocus]::ShowWindow($hwnd, 9) | Out-Null
[WinFocus]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 300

[System.Windows.Forms.SendKeys]::SendWait("^x")
Start-Sleep -Milliseconds 300
Log "Ctrl+X sent (Explorer native cut)"

# ===== Step 2: Navigate to destination via address bar =====
# Alt+D = focus address bar (standard Windows shortcut)
[System.Windows.Forms.SendKeys]::SendWait("%d")
Start-Sleep -Milliseconds 300

# Escape SendKeys special chars in path: + ^ % ~ ( ) { }
$escapedPath = $DestPath -replace '([+^%~{}()])', '{$1}'
[System.Windows.Forms.SendKeys]::SendWait($escapedPath)
Start-Sleep -Milliseconds 200

[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Log "Address bar navigation sent: $DestPath"

# Wait for navigation to complete (path changes)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
while ($sw.ElapsedMilliseconds -lt 15000) {
    try {
        if ($sourceWin.Document.Folder.Self.Path -eq $DestPath) { break }
    } catch { }
    Start-Sleep -Milliseconds 200
}
Log "Navigation done in $($sw.ElapsedMilliseconds)ms"

Start-Sleep -Milliseconds 400

# ===== Step 3: Ctrl+V (EXPLORER pastes natively) =====
[WinFocus]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 200

[System.Windows.Forms.SendKeys]::SendWait("^v")
Log "Ctrl+V sent (Explorer native paste)"

Log "===== END ====="

# EXIT — Explorer handles transfer in background via IFileOperation
try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null } catch { }
