# MoveTo.ps1 - Native clipboard CUT + SendKeys paste
# Reads ALL selected items from Explorer, puts them on clipboard as CUT,
# opens destination folder, sends Ctrl+V. Explorer handles transfer in background.

param(
    [string]$SourcePath,
    [string]$DestPath
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

# Find the Explorer window that has our source files selected
$shell = New-Object -ComObject Shell.Application
$sourceParent = Split-Path $SourcePath -Parent
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

# Fallback: if couldn't read selection, use the single source path
if ($selectedPaths.Count -eq 0) {
    $selectedPaths = @($SourcePath)
}

# ===== NATIVE CUT (same as Ctrl+X) =====
$files = New-Object System.Collections.Specialized.StringCollection
foreach ($p in $selectedPaths) {
    $files.Add($p)
}

$data = New-Object System.Windows.Forms.DataObject
$data.SetFileDropList($files)

# Preferred DropEffect = MOVE (2) = CUT
$moveBytes = [byte[]]@(2, 0, 0, 0)
$stream = New-Object System.IO.MemoryStream(, $moveBytes)
$data.SetData("Preferred DropEffect", $stream)

[System.Windows.Forms.Clipboard]::SetDataObject($data, $true)

# Release COM references to source folder BEFORE paste
$shell = $null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) 2>$null
[System.GC]::Collect()

# ===== NATIVE PASTE (open destination + Ctrl+V) =====
# Open destination folder in Explorer
$destShell = New-Object -ComObject Shell.Application
$destShell.Open($DestPath)

# Wait for Explorer window to appear and get focus
Start-Sleep -Milliseconds 800

# Send Ctrl+V (exactly like user pressing Ctrl+V)
[System.Windows.Forms.SendKeys]::SendWait("^v")

# Cleanup
$destShell = $null

# Script exits - Explorer handles transfer in background
