# EditDestinations.ps1 - Interactive editor for Move To destinations

$destinationsFolder = "D:\Users\joty79\scripts\MoveTo\destinations"
$syncScript = "D:\Users\joty79\scripts\MoveTo\SyncMoveToMenu.ps1"
$reservedDestinationNames = @(
    "Add as destination",
    "Add to destinations",
    "[Add to destinations]",
    "[Add as destination]",
    "Edit destinations",
    "[Edit destinations]"
)

function Test-IsReservedShortcut {
    param(
        [Parameter(Mandatory = $true)]$ShortcutFile,
        [Parameter(Mandatory = $true)]$Shell
    )

    $baseName = $ShortcutFile.BaseName.Trim()
    if ($reservedDestinationNames -contains $baseName) {
        return $true
    }

    # Filename-level guard (exact legacy/system shortcut names)
    if ($ShortcutFile.Name -match '^(?i)(Add to Destinations|Add as destination|Edit Destinations)\.lnk$') {
        return $true
    }

    # Defensive filter: hide menu-infra shortcuts even if renamed.
    try {
        $lnk = $Shell.CreateShortcut($ShortcutFile.FullName)
        $targetPath = [string]$lnk.TargetPath
        $arguments = [string]$lnk.Arguments
        $combinedShortcutCmd = ($targetPath + " " + $arguments)

        if (
            $combinedShortcutCmd -match "(?i)\\AddMoveToDestination\.(vbs|ps1)\b" -or
            $combinedShortcutCmd -match "(?i)\\EditDestinations\.(vbs|ps1)\b"
        ) {
            return $true
        }
    }
    catch {
        # If shortcut cannot be parsed, do not hide it.
    }

    return $false
}

function Get-VisibleShortcuts {
    $shell = New-Object -ComObject WScript.Shell
    Get-ChildItem -Path $destinationsFolder -Filter "*.lnk" -File -ErrorAction SilentlyContinue |
        Where-Object { -not (Test-IsReservedShortcut -ShortcutFile $_ -Shell $shell) }
}

function Read-Key {
    $key = [Console]::ReadKey($true)
    return $key
}

function Show-Menu {
    param([int]$count)
    
    Clear-Host
    Write-Host ""
    Write-Host "  ========================================" -ForegroundColor Cyan
    Write-Host "       MOVE TO - EDIT DESTINATIONS" -ForegroundColor Cyan
    Write-Host "  ========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $shortcuts = Get-VisibleShortcuts
    $shell = New-Object -ComObject WScript.Shell
    
    if (-not $shortcuts -or $shortcuts.Count -eq 0) {
        Write-Host "  (no destinations)" -ForegroundColor Yellow
        Write-Host ""
    }
    else {
        $i = 1
        foreach ($sc in $shortcuts) {
            $lnk = $shell.CreateShortcut($sc.FullName)
            $target = $lnk.TargetPath
            Write-Host "  [$i] " -NoNewline -ForegroundColor Yellow
            Write-Host "$($sc.BaseName)" -NoNewline -ForegroundColor White
            Write-Host " -> $target" -ForegroundColor DarkGray
            $i++
        }
        Write-Host ""
    }
    
    Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
    Write-Host "  [R] Refresh    [O] Open folder    [ESC] Quit" -ForegroundColor Green
    
    if ($shortcuts -and $shortcuts.Count -gt 9) {
        Write-Host "  Type number(s) + Enter to remove (e.g. 9,15)" -ForegroundColor DarkCyan
    }
    else {
        Write-Host "  Press number to remove" -ForegroundColor DarkCyan
    }
    Write-Host ""
    
    return $shortcuts
}

function Remove-Destination {
    param($shortcuts, [int]$index, [switch]$NoConfirm)
    
    if ($index -ge 0 -and $index -lt $shortcuts.Count) {
        $toRemove = $shortcuts[$index]
        if ($NoConfirm) {
            Remove-Item -LiteralPath $toRemove.FullName -Force
            return $true
        }
        Write-Host "`n  Remove '$($toRemove.BaseName)'? [Enter/ESC]: " -NoNewline -ForegroundColor Red
        $confirm = Read-Key
        if ($confirm.Key -eq 'Enter') {
            Remove-Item -LiteralPath $toRemove.FullName -Force
            Write-Host ""
            Write-Host "  Removed!" -ForegroundColor Green
            & $syncScript
            return $true
        }
    }
    else {
        Write-Host "`n  Invalid: $($index + 1)" -ForegroundColor Red
    }
    return $false
}

function Remove-MultipleDestinations {
    param($shortcuts, [int[]]$indices)
    
    # Get names for confirmation
    $names = @()
    foreach ($idx in $indices) {
        if ($idx -ge 0 -and $idx -lt $shortcuts.Count) {
            $names += $shortcuts[$idx].BaseName
        }
    }
    
    if ($names.Count -eq 0) {
        Write-Host "`n  No valid items!" -ForegroundColor Red
        Start-Sleep -Milliseconds 500
        return
    }
    
    Write-Host "`n  Remove: $($names -join ', ')? [Enter/ESC]: " -NoNewline -ForegroundColor Red
    $confirm = Read-Key
    if ($confirm.Key -eq 'Enter') {
        Write-Host ""
        $removed = 0
        # Delete in reverse order to preserve indices
        foreach ($idx in ($indices | Sort-Object -Descending)) {
            if (Remove-Destination -shortcuts $shortcuts -index $idx -NoConfirm) {
                $removed++
            }
        }
        Write-Host "  Removed $removed item(s)!" -ForegroundColor Green
        & $syncScript
    }
}

# Main loop
while ($true) {
    $shortcuts = Show-Menu
    $count = if ($shortcuts) { $shortcuts.Count } else { 0 }
    
    Write-Host "  > " -NoNewline -ForegroundColor White
    
    if ($count -le 9) {
        # Single keypress mode
        $key = Read-Key
        
        if ($key.Key -eq 'Escape') {
            break
        }
        elseif ($key.Key -eq 'R') {
            Write-Host "R"
            Write-Host "`n  Refreshing..." -ForegroundColor Yellow
            & $syncScript
        }
        elseif ($key.Key -eq 'O') {
            Write-Host "O"
            Start-Process explorer.exe $destinationsFolder
        }
        elseif ($key.KeyChar -match '^\d$') {
            $num = [int]$key.KeyChar.ToString()
            Write-Host $num
            if ($num -ge 1 -and $num -le $count) {
                Remove-Destination -shortcuts $shortcuts -index ($num - 1) | Out-Null
            }
            else {
                Write-Host "`n  Invalid number!" -ForegroundColor Red
                Start-Sleep -Milliseconds 500
            }
        }
    }
    else {
        # Multi-digit mode (>9 destinations)
        $inputStr = ""
        while ($true) {
            $key = Read-Key
            
            if ($key.Key -eq 'Escape') {
                if ($inputStr -eq "") {
                    # Exit app
                    break
                }
                # Cancel current input
                break
            }
            # R and O work immediately without Enter
            elseif ($key.Key -eq 'R' -and $inputStr -eq "") {
                Write-Host "R"
                Write-Host "`n  Refreshing..." -ForegroundColor Yellow
                & $syncScript
                break
            }
            elseif ($key.Key -eq 'O' -and $inputStr -eq "") {
                Write-Host "O"
                Start-Process explorer.exe $destinationsFolder
                break
            }
            elseif ($key.Key -eq 'Enter') {
                Write-Host ""
                if ($inputStr -match '^[\d,]+$' -and $inputStr -match '\d') {
                    # Parse comma-separated numbers
                    $numbers = $inputStr -split ',' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
                    
                    if ($numbers.Count -eq 1) {
                        # Single number
                        $num = $numbers[0]
                        if ($num -ge 1 -and $num -le $count) {
                            Remove-Destination -shortcuts $shortcuts -index ($num - 1) | Out-Null
                        }
                        else {
                            Write-Host "  Invalid number!" -ForegroundColor Red
                            Start-Sleep -Milliseconds 500
                        }
                    }
                    elseif ($numbers.Count -gt 1) {
                        # Multiple numbers - convert to 0-based indices
                        $indices = $numbers | Where-Object { $_ -ge 1 -and $_ -le $count } | ForEach-Object { $_ - 1 }
                        if ($indices.Count -gt 0) {
                            Remove-MultipleDestinations -shortcuts $shortcuts -indices $indices
                        }
                        else {
                            Write-Host "  No valid numbers!" -ForegroundColor Red
                            Start-Sleep -Milliseconds 500
                        }
                    }
                }
                break
            }
            elseif ($key.Key -eq 'Backspace') {
                if ($inputStr.Length -gt 0) {
                    $inputStr = $inputStr.Substring(0, $inputStr.Length - 1)
                    Write-Host "`b `b" -NoNewline
                }
            }
            elseif ($key.KeyChar -match '^[\d,]$') {
                # Allow digits and comma in >9 mode
                $inputStr += $key.KeyChar
                Write-Host $key.KeyChar -NoNewline
            }
        }
        
        # Check if we're exiting
        if ($key.Key -eq 'Escape' -and $inputStr -eq "") {
            break
        }
    }
}
