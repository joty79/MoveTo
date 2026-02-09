# AddMoveToDestination.ps1 - Batch collector for adding destinations
# Collects multiple folder paths, then creates shortcuts and syncs once

param([string]$folderPath)

if (-not $folderPath -and $args.Count -gt 0) {
    $folderPath = $args[0]
}

$destinationsFolder = "D:\Users\joty79\scripts\MoveTo\destinations"
$tempFile = "$env:TEMP\AddDestination_paths.txt"
$lockFile = "$env:TEMP\AddDestination.lock"

# Validate folder
if (-not $folderPath -or -not (Test-Path $folderPath -PathType Container)) {
    exit 1
}

# Add to temp file
Add-Content -Path $tempFile -Value $folderPath -Force

# Wait for other instances
Start-Sleep -Milliseconds 300

# Try to acquire lock
$lockAcquired = $false
try {
    $lockStream = [System.IO.File]::Open($lockFile, 'OpenOrCreate', 'ReadWrite', 'None')
    $lockAcquired = $true
}
catch {
    # Another instance has the lock - exit silently
    exit 0
}

if ($lockAcquired) {
    try {
        # Wait a bit for any remaining instances
        Start-Sleep -Milliseconds 300
        
        if (Test-Path $tempFile) {
            $paths = Get-Content $tempFile -ErrorAction SilentlyContinue | Where-Object { $_ -and (Test-Path $_ -PathType Container) } | Select-Object -Unique
            
            if ($paths) {
                $shell = New-Object -ComObject WScript.Shell
                $added = 0
                
                foreach ($path in $paths) {
                    $folderName = Split-Path $path -Leaf
                    $shortcutPath = Join-Path $destinationsFolder "$folderName.lnk"
                    
                    # Skip if already exists
                    if (-not (Test-Path $shortcutPath)) {
                        $shortcut = $shell.CreateShortcut($shortcutPath)
                        $shortcut.TargetPath = $path
                        $shortcut.Save()
                        $added++
                    }
                }
                
                # Sync menu once for all
                if ($added -gt 0) {
                    & "D:\Users\joty79\scripts\MoveTo\SyncMoveToMenu.ps1"
                }
            }
            
            # Cleanup
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
    finally {
        $lockStream.Close()
        Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
    }
}
