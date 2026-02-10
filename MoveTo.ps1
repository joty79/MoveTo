# MoveTo.ps1 - Clipboard CUT + COM InvokeVerb paste
# ONE batch operation, ONE dialog, Cancel stops ALL, no new Explorer window.

param(
    [string]$SourcePath,
    [string]$DestPath
)

Add-Type -AssemblyName System.Windows.Forms

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

# Preferred DropEffect = MOVE (2) = CUT
$moveBytes = [byte[]]@(2, 0, 0, 0)
$stream = New-Object System.IO.MemoryStream(, $moveBytes)
$data.SetData("Preferred DropEffect", $stream)

[System.Windows.Forms.Clipboard]::SetDataObject($data, $true)

# ===== Paste to destination via COM (NO new window) =====
$destFolder = $shell.NameSpace($DestPath)

if ($destFolder) {
    # InvokeVerb("paste") = same as right-click folder → Paste
    # ONE operation, native dialog, Cancel stops ALL
    $destFolder.Self.InvokeVerb("paste")
}

# ===== Cleanup =====
try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null } catch { }
