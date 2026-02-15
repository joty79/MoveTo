# SyncMoveToMenu.ps1 - Syncs destinations with registry menu (with icons)

$destinationsFolder = "D:\Users\joty79\scripts\MoveTo\destinations"

$menuRootName = "Z_MoveTo"
$legacyMenuRootName = "MoveToCustom"
$scriptRoot = Split-Path -Path $PSCommandPath -Parent
$actionsKeyName = "aaa_Actions"

$regPathFiles = "Registry::HKEY_CURRENT_USER\Software\Classes\*\shell\$menuRootName\shell"
$regPathDirs = "Registry::HKEY_CURRENT_USER\Software\Classes\Directory\shell\$menuRootName\shell"
$legacyRegPathFiles = "Registry::HKEY_CURRENT_USER\Software\Classes\*\shell\$legacyMenuRootName\shell"
$legacyRegPathDirs = "Registry::HKEY_CURRENT_USER\Software\Classes\Directory\shell\$legacyMenuRootName\shell"
$reservedShortcutNames = @(
    "add as destination",
    "add to destinations",
    "edit destinations",
    "[add as destination]",
    "[add to destinations]",
    "[edit destinations]"
)

function Ensure-StaticActionEntries {
    param(
        [Parameter(Mandatory = $true)][string]$FilesShellPath,
        [Parameter(Mandatory = $true)][string]$DirsShellPath,
        [Parameter(Mandatory = $true)][string]$ScriptRootPath
    )

    function Add-RegValue {
        param(
            [Parameter(Mandatory = $true)][string]$Key,
            [string]$Name,
            [Parameter(Mandatory = $true)][string]$Type,
            [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Data,
            [switch]$DefaultValue
        )

        $regArgs = New-Object System.Collections.Generic.List[string]
        [void]$regArgs.Add("add")
        [void]$regArgs.Add($Key)
        [void]$regArgs.Add("/f")

        if ($DefaultValue) {
            [void]$regArgs.Add("/ve")
        }
        else {
            [void]$regArgs.Add("/v")
            [void]$regArgs.Add($Name)
        }

        [void]$regArgs.Add("/t")
        [void]$regArgs.Add($Type)
        [void]$regArgs.Add("/d")
        [void]$regArgs.Add($Data)

        $null = & reg.exe @regArgs 2>$null
    }

    function Remove-RegKeyTree {
        param([Parameter(Mandatory = $true)][string]$Key)
        $null = & reg.exe delete $Key /f 2>$null
    }

    $editVbs = Join-Path $ScriptRootPath "EditDestinations.vbs"
    $addVbs = Join-Path $ScriptRootPath "AddMoveToDestination.vbs"
    $editCmd = "wscript.exe `"$editVbs`""
    $addCmd = "wscript.exe `"$addVbs`" `"%1`""

    $fileActionsKey = "HKCU\Software\Classes\*\shell\$menuRootName\shell\$actionsKeyName"
    $dirActionsKey = "HKCU\Software\Classes\Directory\shell\$menuRootName\shell\$actionsKeyName"

    # Cleanup legacy direct static keys (old layout)
    foreach ($oldKey in @(
        "HKCU\Software\Classes\*\shell\$menuRootName\shell\zzz_Edit",
        "HKCU\Software\Classes\Directory\shell\$menuRootName\shell\yyy_Add",
        "HKCU\Software\Classes\Directory\shell\$menuRootName\shell\zzz_Edit"
    )) {
        Remove-RegKeyTree -Key $oldKey
    }

    # Create Actions submenus (new layout)
    Add-RegValue -Key $fileActionsKey -Name "MUIVerb" -Type "REG_SZ" -Data "[Actions]"
    Add-RegValue -Key $fileActionsKey -Name "SubCommands" -Type "REG_SZ" -Data ""
    Add-RegValue -Key $fileActionsKey -Name "Icon" -Type "REG_SZ" -Data "shell32.dll,-16710"
    Add-RegValue -Key "$fileActionsKey\shell" -Name "MUIVerb" -Type "REG_SZ" -Data ""

    Add-RegValue -Key $dirActionsKey -Name "MUIVerb" -Type "REG_SZ" -Data "[Actions]"
    Add-RegValue -Key $dirActionsKey -Name "SubCommands" -Type "REG_SZ" -Data ""
    Add-RegValue -Key $dirActionsKey -Name "Icon" -Type "REG_SZ" -Data "shell32.dll,-16710"
    Add-RegValue -Key "$dirActionsKey\shell" -Name "MUIVerb" -Type "REG_SZ" -Data ""

    $fileEditKey = "$fileActionsKey\shell\zz_Edit"
    $dirAddKey = "$dirActionsKey\shell\yy_Add"
    $dirEditKey = "$dirActionsKey\shell\zz_Edit"

    Add-RegValue -Key $fileEditKey -Name "MUIVerb" -Type "REG_SZ" -Data "[Edit destinations]"
    Add-RegValue -Key $fileEditKey -Name "Icon" -Type "REG_SZ" -Data "shell32.dll,-16710"
    Add-RegValue -Key "$fileEditKey\command" -Type "REG_SZ" -Data $editCmd -DefaultValue

    Add-RegValue -Key $dirAddKey -Name "MUIVerb" -Type "REG_SZ" -Data "[Add as destination]"
    Add-RegValue -Key $dirAddKey -Name "Icon" -Type "REG_SZ" -Data "shell32.dll,-16769"
    Add-RegValue -Key "$dirAddKey\command" -Type "REG_SZ" -Data $addCmd -DefaultValue

    Add-RegValue -Key $dirEditKey -Name "MUIVerb" -Type "REG_SZ" -Data "[Edit destinations]"
    Add-RegValue -Key $dirEditKey -Name "Icon" -Type "REG_SZ" -Data "shell32.dll,-16710"
    Add-RegValue -Key "$dirEditKey\command" -Type "REG_SZ" -Data $editCmd -DefaultValue
}

Write-Host "`n=== Syncing Move To Menu ===" -ForegroundColor Cyan

$shortcuts = Get-ChildItem -Path $destinationsFolder -Filter "*.lnk" -File -ErrorAction SilentlyContinue

if (-not $shortcuts) {
    Write-Host "No shortcuts found." -ForegroundColor Yellow
    $shortcuts = @()
}

# Clear old dest_ entries (active + legacy root for safe migration)
foreach ($regPath in @($regPathFiles, $regPathDirs, $legacyRegPathFiles, $legacyRegPathDirs)) {
    if (Test-Path -LiteralPath $regPath) {
        Get-ChildItem -LiteralPath $regPath -ErrorAction SilentlyContinue | Where-Object {
            $_.PSChildName -like "dest_*" -or
            $_.PSChildName -in @("yyy_Add", "zzz_Edit", "aaa_Actions", "zzz_Actions")
        } | ForEach-Object {
            Remove-Item -LiteralPath $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Ensure static menu infrastructure exists on every refresh.
Ensure-StaticActionEntries -FilesShellPath $regPathFiles -DirsShellPath $regPathDirs -ScriptRootPath $scriptRoot

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
