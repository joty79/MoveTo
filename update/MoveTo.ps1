# MoveTo.ps1 - Collects paths, then spawns wt.exe for the paste (dialog)
# File-based lock for synchronization

param(
    [string]$SourcePath,
    [string]$ShortcutName
)

if (-not $SourcePath -and $args.Count -ge 1) { $SourcePath = $args[0] }
if (-not $ShortcutName -and $args.Count -ge 2) { $ShortcutName = $args[1] }

$destinationsFolder = "D:\Users\joty79\scripts\MoveTo\destinations"
$tempFile = "$env:TEMP\MoveTo_paths.txt"
$lockFile = "$env:TEMP\MoveTo.lock"

# Read shortcut to get destination
$wshell = New-Object -ComObject WScript.Shell

# Trigger link resolution
Get-ChildItem -Path $destinationsFolder -Filter "*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
    try { $null = $wshell.CreateShortcut($_.FullName).TargetPath } catch { }
}

$shortcutPath = Join-Path $destinationsFolder "$ShortcutName.lnk"
if (-not (Test-Path -LiteralPath $shortcutPath -PathType Leaf)) { exit 1 }

$lnk = $wshell.CreateShortcut($shortcutPath)
$destinationFolder = $lnk.TargetPath
if (-not $destinationFolder -or -not (Test-Path -LiteralPath $destinationFolder -PathType Container)) { exit 1 }

# Check source
if (-not (Test-Path -LiteralPath $SourcePath)) { exit 1 }

# Add source to temp file
Add-Content -Path $tempFile -Value "$destinationFolder|$SourcePath" -Force

# Wait for other instances
Start-Sleep -Milliseconds 500

# Try to acquire file lock
$lockAcquired = $false
try {
    $lockStream = [System.IO.File]::Open($lockFile, 'OpenOrCreate', 'ReadWrite', 'None')
    $lockAcquired = $true
}
catch {
    exit 0
}

if ($lockAcquired) {
    try {
        Start-Sleep -Milliseconds 400
        
        # Read all collected paths
        if (Test-Path $tempFile) {
            # Spawn VBS wrapper which runs wt.exe hidden
            $pasteVbs = "D:\Users\joty79\scripts\MoveTo\MoveToPaste.vbs"
            Start-Process "wscript.exe" -ArgumentList "`"$pasteVbs`""
        }
    }
    finally {
        $lockStream.Close()
        Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
    }
}
