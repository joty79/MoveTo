# MoveTo.ps1 - Clipboard CUT + Navigate2 + SendKeys Ctrl+V
# Reuses EXISTING Explorer window (no new window), fire-and-forget.
# Explorer handles transfer natively via IFileOperation (background).

param(
    [string]$SourcePath,
    [string]$DestPath
)

Add-Type -AssemblyName System.Windows.Forms

# ===== Debug Log =====
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

# ===== Find source window + read ALL selected items =====
$sourceWin = $null
$selectedPaths = [System.Collections.Generic.List[string]]::new()

foreach ($win in $shell.Windows()) {
    try {
        $winPath = $win.Document.Folder.Self.Path
        if ($winPath -eq $sourceParent) {
            $sourceWin = $win
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

# ===== Navigate SAME window to destination (NO new window!) =====
if ($sourceWin) {
    $sourceWin.Navigate2($DestPath)

    # Wait until path changes to destination (max 10 sec)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt 10000) {
        try {
            if ($sourceWin.Document.Folder.Self.Path -eq $DestPath) { break }
        } catch { }
        Start-Sleep -Milliseconds 100
    }
    Start-Sleep -Milliseconds 300
    Log "Navigated to destination in $($sw.ElapsedMilliseconds)ms"
} else {
    # Fallback: open new window (only if source window not found)
    Log "No source window found, opening new"
    $shell.Open($DestPath)
    Start-Sleep -Milliseconds 900
}

# ===== Paste — fire and forget =====
[System.Windows.Forms.SendKeys]::SendWait("^v")
Log "Paste sent"

# ===== EXIT IMMEDIATELY — Explorer handles everything =====
try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null } catch { }
Log "===== END ====="
