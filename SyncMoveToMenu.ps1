# SyncMoveToMenu.ps1 - Syncs destinations with registry menu (with icons)

$destinationsFolder = "D:\Users\joty79\scripts\MoveTo\destinations"

$menuRootName = "Z_MoveTo"
$legacyMenuRootName = "MoveToCustom"

$regPathFiles = "Registry::HKEY_CURRENT_USER\Software\Classes\*\shell\$menuRootName\shell"
$regPathDirs = "Registry::HKEY_CURRENT_USER\Software\Classes\Directory\shell\$menuRootName\shell"
$legacyRegPathFiles = "Registry::HKEY_CURRENT_USER\Software\Classes\*\shell\$legacyMenuRootName\shell"
$legacyRegPathDirs = "Registry::HKEY_CURRENT_USER\Software\Classes\Directory\shell\$legacyMenuRootName\shell"
$reservedShortcutNames = @(
    "add as destination",
    "add to destinations",
    "edit destinations"
)

Write-Host "`n=== Syncing Move To Menu ===" -ForegroundColor Cyan

$shortcuts = Get-ChildItem -Path $destinationsFolder -Filter "*.lnk" -File -ErrorAction SilentlyContinue

if (-not $shortcuts) {
    Write-Host "No shortcuts found." -ForegroundColor Yellow
    exit
}

# Clear old dest_ entries (active + legacy root for safe migration)
foreach ($regPath in @($regPathFiles, $regPathDirs, $legacyRegPathFiles, $legacyRegPathDirs)) {
    if (Test-Path -LiteralPath $regPath) {
        Get-ChildItem -LiteralPath $regPath -ErrorAction SilentlyContinue | Where-Object {
            $_.PSChildName -like "dest_*"
        } | ForEach-Object {
            Remove-Item -LiteralPath $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

$shell = New-Object -ComObject WScript.Shell
$count = 0

foreach ($sc in $shortcuts) {
    $name = $sc.BaseName
    $normalizedName = (($name -replace '\s+', ' ').Trim()).ToLowerInvariant()

    # Never sync menu-infrastructure shortcuts as normal destinations.
    if ($reservedShortcutNames -contains $normalizedName) {
        continue
    }

    $safeName = $name -replace '[^a-zA-Z0-9]', '_'
    $keyName = "dest_$safeName"
    
    # Read shortcut
    $lnk = $shell.CreateShortcut($sc.FullName)
    $targetPath = $lnk.TargetPath
    $arguments = [string]$lnk.Arguments
    $iconFromLnk = $lnk.IconLocation

    $combinedShortcutCmd = ([string]$targetPath + " " + $arguments)
    if (
        $combinedShortcutCmd -match "(?i)\\AddMoveToDestination\.(vbs|ps1)\b" -or
        $combinedShortcutCmd -match "(?i)\\EditDestinations\.(vbs|ps1)\b"
    ) {
        continue
    }
    
    # Determine icon
    $icon = "shell32.dll,3"  # Default Windows folder icon
    
    # 1. Try shortcut's IconLocation
    if ($iconFromLnk -and $iconFromLnk -ne ",0") {
        $icon = $iconFromLnk
    }
    # 2. Try target folder's desktop.ini
    elseif ($targetPath -and (Test-Path $targetPath -PathType Container)) {
        $desktopIni = Join-Path $targetPath "desktop.ini"
        if (Test-Path $desktopIni) {
            $content = Get-Content $desktopIni -Raw -ErrorAction SilentlyContinue
            if ($content -match 'IconResource=(.+)') {
                $icon = $matches[1].Trim()
            }
        }
    }
    
    $command = "wscript.exe `"D:\Users\joty79\scripts\MoveTo\MoveTo.vbs`" `"%1`" `"$name`""
    
    foreach ($regPath in @($regPathFiles, $regPathDirs)) {
        $keyPath = "$regPath\$keyName"
        
        New-Item -Path $keyPath -Force -ErrorAction SilentlyContinue | Out-Null
        New-Item -Path "$keyPath\command" -Force -ErrorAction SilentlyContinue | Out-Null
        
        Set-ItemProperty -LiteralPath $keyPath -Name "MUIVerb" -Value $name -ErrorAction SilentlyContinue
        Set-ItemProperty -LiteralPath $keyPath -Name "Icon" -Value $icon -ErrorAction SilentlyContinue
        Set-ItemProperty -LiteralPath "$keyPath\command" -Name "(Default)" -Value $command -ErrorAction SilentlyContinue
    }
    
    Write-Host "  + $name [$icon]" -ForegroundColor Green
    $count++
}

Write-Host "`nDone! $count destinations." -ForegroundColor Blue
