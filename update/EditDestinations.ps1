# EditDestinations.ps1 - Interactive editor for Move To destinations

$destinationsFolder = "D:\Users\joty79\scripts\MoveTo\destinations"
$syncScript = "D:\Users\joty79\scripts\MoveTo\SyncMoveToMenu.ps1"

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "  ========================================" -ForegroundColor Cyan
    Write-Host "       MOVE TO - EDIT DESTINATIONS" -ForegroundColor Cyan
    Write-Host "  ========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $shortcuts = Get-ChildItem -Path $destinationsFolder -Filter "*.lnk" -File -ErrorAction SilentlyContinue
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
    Write-Host "  [R] Refresh menu" -ForegroundColor Green
    Write-Host "  [O] Open destinations folder" -ForegroundColor Green
    Write-Host "  [Q] Quit" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Type number to REMOVE, or letter for action" -ForegroundColor Cyan
    Write-Host ""
    
    return $shortcuts
}

# Main loop
while ($true) {
    $shortcuts = Show-Menu
    
    $input = Read-Host "  >"
    
    if ($input -eq 'q' -or $input -eq 'Q') {
        break
    }
    elseif ($input -eq 'r' -or $input -eq 'R') {
        Write-Host "`n  Refreshing menu..." -ForegroundColor Yellow
        & $syncScript
        Write-Host "  Done! Press Enter..." -ForegroundColor Green
        Read-Host
    }
    elseif ($input -eq 'o' -or $input -eq 'O') {
        Start-Process explorer.exe $destinationsFolder
    }
    elseif ($input -match '^\d+$') {
        $index = [int]$input - 1
        if ($shortcuts -and $index -ge 0 -and $index -lt $shortcuts.Count) {
            $toRemove = $shortcuts[$index]
            Write-Host "`n  Remove '$($toRemove.BaseName)'? [y/N]: " -NoNewline -ForegroundColor Red
            $confirm = Read-Host
            if ($confirm -eq 'y' -or $confirm -eq 'Y') {
                Remove-Item -LiteralPath $toRemove.FullName -Force
                Write-Host "  Removed! Refreshing menu..." -ForegroundColor Yellow
                & $syncScript
                Write-Host "  Done! Press Enter..." -ForegroundColor Green
                Read-Host
            }
        }
        else {
            Write-Host "`n  Invalid number!" -ForegroundColor Red
            Start-Sleep 1
        }
    }
}
