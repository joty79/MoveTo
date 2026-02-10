# MoveTo.ps1 - Pure COM MoveHere (no new Explorer window, no clipboard)
# Reads ALL selected items from Explorer via COM, moves them to destination
# using Shell.NameSpace.MoveHere. Explorer handles transfer natively.

param(
    [string]$SourcePath,
    [string]$DestPath
)

$shell = New-Object -ComObject Shell.Application
$sourceParent = Split-Path $SourcePath -Parent

# ===== Find Explorer window with selected items =====
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

# Fallback: single source path from args
if ($selectedPaths.Count -eq 0) {
    $selectedPaths = @($SourcePath)
}

# ===== Release source COM references =====
try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null } catch { }
$shell = $null
[System.GC]::Collect()
Start-Sleep -Milliseconds 100

# ===== MoveHere via fresh Shell (no window opens) =====
$moveShell = New-Object -ComObject Shell.Application
$destFolder = $moveShell.NameSpace($DestPath)

if (-not $destFolder) {
    exit 1
}

# Move each item — Explorer shows native progress + conflict dialog
foreach ($path in $selectedPaths) {
    $destFolder.MoveHere($path, 0x0)
}

# ===== Cleanup =====
try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($moveShell) | Out-Null } catch { }
