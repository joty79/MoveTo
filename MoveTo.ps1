# MoveTo.ps1 - Pure COM MoveHere (single batch operation)
# Reads ALL selected items from Explorer via COM, passes the entire
# FolderItems collection to ONE MoveHere call. Cancel = cancel ALL.

param(
    [string]$SourcePath,
    [string]$DestPath
)

$shell = New-Object -ComObject Shell.Application
$sourceParent = Split-Path $SourcePath -Parent

# ===== Find Explorer window → get SelectedItems as COM collection =====
$selectedItems = $null

foreach ($win in $shell.Windows()) {
    try {
        $winPath = $win.Document.Folder.Self.Path
        if ($winPath -eq $sourceParent) {
            $selectedItems = $win.Document.SelectedItems()
            break
        }
    } catch { }
}

# ===== MoveHere — ONE call, ONE dialog =====
$destFolder = $shell.NameSpace($DestPath)

if (-not $destFolder) { exit 1 }

if ($selectedItems -and $selectedItems.Count -gt 0) {
    # Batch: entire FolderItems collection → one operation
    $destFolder.MoveHere($selectedItems, 0x0)
} else {
    # Fallback: single path from args
    $destFolder.MoveHere($SourcePath, 0x0)
}

# ===== Cleanup =====
try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null } catch { }
