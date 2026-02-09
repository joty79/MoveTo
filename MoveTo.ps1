# MoveTo.ps1 - Alternative PowerShell version (backup)
# The primary mover is MoveTo.vbs (uses Shell.Application.MoveHere)
# This file is kept as reference / fallback

param(
    [string]$SourcePath,
    [string]$ShortcutName
)

if (-not $SourcePath -and $args.Count -ge 1) { $SourcePath = $args[0] }
if (-not $ShortcutName -and $args.Count -ge 2) { $ShortcutName = $args[1] }

$destinationsFolder = "D:\Users\joty79\scripts\MoveTo\destinations"

# Validate source
if (-not (Test-Path -LiteralPath $SourcePath)) { exit 1 }

# Resolve destination
$shortcutPath = Join-Path $destinationsFolder "$ShortcutName.lnk"
if (-not (Test-Path -LiteralPath $shortcutPath -PathType Leaf)) { exit 1 }

$wshell = New-Object -ComObject WScript.Shell
$lnk = $wshell.CreateShortcut($shortcutPath)
$destPath = $lnk.TargetPath

if (-not $destPath -or -not (Test-Path -LiteralPath $destPath -PathType Container)) { exit 1 }

# Move using native Windows Explorer mechanism
$shell = New-Object -ComObject Shell.Application
$destFolder = $shell.NameSpace($destPath)
if ($destFolder) {
    # Flag 0 = full native dialog (progress + conflict resolution)
    $destFolder.MoveHere($SourcePath, 0)
}
