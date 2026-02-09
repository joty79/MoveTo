# MoveTo.ps1 - Moves file/folder to destination
# Reads ALL shortcuts first to trigger Windows link resolution

param(
    [string]$SourcePath,
    [string]$ShortcutName
)

if (-not $SourcePath -and $args.Count -ge 1) { $SourcePath = $args[0] }
if (-not $ShortcutName -and $args.Count -ge 2) { $ShortcutName = $args[1] }

$destinationsFolder = "D:\Users\joty79\scripts\MoveTo\destinations"
$shell = New-Object -ComObject WScript.Shell

# Read ALL shortcuts to trigger link resolution
Get-ChildItem -Path $destinationsFolder -Filter "*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
    try { $null = $shell.CreateShortcut($_.FullName).TargetPath } catch { }
}

# Check source exists
if (-not (Test-Path -LiteralPath $SourcePath)) {
    exit 1
}

# Get destination
$shortcutPath = Join-Path $destinationsFolder "$ShortcutName.lnk"
if (-not (Test-Path -LiteralPath $shortcutPath -PathType Leaf)) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("Destination '$ShortcutName' not found.", "Move To", 0, 16) | Out-Null
    exit 1
}

$lnk = $shell.CreateShortcut($shortcutPath)
$destinationFolder = $lnk.TargetPath

if (-not $destinationFolder -or -not (Test-Path -LiteralPath $destinationFolder -PathType Container)) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("Destination path not found:`n$destinationFolder", "Move To", 0, 16) | Out-Null
    exit 1
}

# Move
try {
    Move-Item -LiteralPath $SourcePath -Destination $destinationFolder -Force
}
catch {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("Move failed: $($_.Exception.Message)", "Move To", 0, 16) | Out-Null
}
