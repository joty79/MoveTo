# MoveTo.ps1 - Native clipboard CUT + paste
# Reads ALL selected items from Explorer, puts them on clipboard as CUT,
# then pastes to destination. Explorer handles transfer in background.

param(
    [string]$SourcePath,
    [string]$DestPath
)

Add-Type -AssemblyName System.Windows.Forms

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
# Put files on clipboard with Preferred DropEffect = MOVE (2)
$files = New-Object System.Collections.Specialized.StringCollection
foreach ($p in $selectedPaths) {
    $files.Add($p)
}

$data = New-Object System.Windows.Forms.DataObject
$data.SetFileDropList($files)

# Preferred DropEffect = MOVE (2) = this makes it a CUT, not COPY
$moveBytes = [byte[]]@(2, 0, 0, 0)
$stream = New-Object System.IO.MemoryStream(, $moveBytes)
$data.SetData("Preferred DropEffect", $stream)

[System.Windows.Forms.Clipboard]::SetDataObject($data, $true)

# ===== NATIVE PASTE (same as Ctrl+V) =====
# Try InvokeVerb("paste") on destination folder
$destFolder = $shell.NameSpace($DestPath)
if ($destFolder) {
    $destFolder.Self.InvokeVerb("paste")
}

# Script exits immediately - Explorer handles transfer in background
