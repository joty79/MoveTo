#requires -version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Install', 'Update', 'Uninstall')]
    [string]$Action = 'Install',
    [string]$InstallPath = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'MoveToContext'),
    [string]$SourcePath = $PSScriptRoot,
    [ValidateSet('Local', 'GitHub')]
    [string]$PackageSource = 'Local',
    [string]$GitHubRepo = 'joty79/MoveTo',
    [string]$GitHubRef = 'master',
    [string]$GitHubZipUrl = '',
    [switch]$Force,
    [switch]$NoExplorerRestart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:InstallerVersion = '1.0.0'
$script:LegacyRoot = 'D:\Users\joty79\scripts\MoveTo'
$script:UninstallKeyPath = 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall\MoveToContext'
$script:Warnings = [System.Collections.Generic.List[string]]::new()
$script:TempPackageRoots = [System.Collections.Generic.List[string]]::new()
$script:HasCliArgs = $PSBoundParameters.Count -gt 0

function Resolve-NormalizedPath {
    param([Parameter(Mandatory)][string]$Path)
    [System.IO.Path]::GetFullPath($Path.Trim())
}

$InstallPath = Resolve-NormalizedPath -Path $InstallPath
$SourcePath = Resolve-NormalizedPath -Path $SourcePath

function Add-Warning {
    param([Parameter(Mandatory)][string]$Message)
    $script:Warnings.Add($Message) | Out-Null
}

function Write-Banner {
    param([string]$Title = 'MoveTo Context Installer')
    try { Clear-Host } catch {}
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ('  {0}  v{1}' -f $Title, $script:InstallerVersion) -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
}

function Write-Step {
    param(
        [Parameter(Mandatory)][string]$Text,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )
    Write-Host ('[>] {0}' -f $Text) -ForegroundColor $Color
}

function Test-IsProcessElevated {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        if (-not $identity) { return $false }
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Invoke-SelfElevatedUninstall {
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$InstallSourceRoot,
        [switch]$NoRestartExplorer
    )

    $selfPath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($selfPath) -and $MyInvocation.MyCommand) {
        $selfPath = $MyInvocation.MyCommand.Definition
    }
    if ([string]::IsNullOrWhiteSpace($selfPath) -or -not (Test-Path -LiteralPath $selfPath)) {
        throw 'Cannot locate installer script path for elevation.'
    }

    $pwshCmd = Get-Command -Name 'pwsh.exe' -ErrorAction SilentlyContinue
    if (-not $pwshCmd) {
        throw 'pwsh.exe is required for elevated uninstall.'
    }

    $argList = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $selfPath),
        '-Action', 'Uninstall',
        '-InstallPath', ('"{0}"' -f $InstallRoot),
        '-SourcePath', ('"{0}"' -f $InstallSourceRoot),
        '-PackageSource', 'Local',
        '-Force'
    )
    if ($NoRestartExplorer) {
        $argList += '-NoExplorerRestart'
    }

    $argumentString = [string]::Join(' ', $argList)
    $process = Start-Process -FilePath $pwshCmd.Source -ArgumentList $argumentString -Verb RunAs -Wait -PassThru
    if ($null -eq $process) {
        throw 'Failed to start elevated uninstall process.'
    }
    return [int]$process.ExitCode
}

function Ensure-Directory {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Test-CommandExists {
    param([Parameter(Mandatory)][string]$Name)
    [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Invoke-Preflight {
    Write-Step -Text 'Running preflight checks...' -Color Cyan
    $required = @('pwsh.exe', 'wscript.exe', 'robocopy.exe')
    $missing = @()
    foreach ($cmd in $required) {
        if (-not (Test-CommandExists -Name $cmd)) {
            $missing += $cmd
        }
    }
    if ($missing.Count -gt 0) {
        Write-Step -Text ("Missing required commands: {0}" -f ($missing -join ', ')) -Color Red
        return $false
    }
    return $true
}

function Get-RequiredPackageEntries {
    @(
        'MoveTo.vbs',
        'AddMoveToDestination.vbs',
        'AddMoveToDestination.ps1',
        'EditDestinations.vbs',
        'EditDestinations.ps1',
        'SyncMoveToMenu.ps1',
        'rcopySingle.ps1',
        'rcp.ps1',
        'RoboCopy_Silent.vbs',
        'RoboPaste_Admin.vbs',
        'MoveTune.ps1',
        'MoveTune.json'
    )
}

function Assert-RequiredPackageFiles {
    param([Parameter(Mandatory)][string]$Root)
    foreach ($entry in @(Get-RequiredPackageEntries)) {
        $full = Join-Path $Root $entry
        if (-not (Test-Path -LiteralPath $full)) {
            throw "Missing source file: $full"
        }
    }
}

function Get-GitHubZipUrl {
    if (-not [string]::IsNullOrWhiteSpace($GitHubZipUrl)) { return $GitHubZipUrl }
    return ("https://codeload.github.com/{0}/zip/refs/heads/{1}" -f $GitHubRepo, $GitHubRef)
}

function Resolve-PackageSourceRoot {
    if ($PackageSource -eq 'Local') {
        Assert-RequiredPackageFiles -Root $SourcePath
        return $SourcePath
    }

    $zipUrl = Get-GitHubZipUrl
    Write-Step -Text ("Downloading package: {0}" -f $zipUrl) -Color Cyan
    $tempRoot = Join-Path $env:TEMP ("MoveToContextPkg_{0}" -f ([Guid]::NewGuid().ToString('N')))
    Ensure-Directory -Path $tempRoot
    $zipPath = Join-Path $tempRoot 'package.zip'
    $extractPath = Join-Path $tempRoot 'extract'
    [void]$script:TempPackageRoots.Add($tempRoot)

    try {
        Invoke-WebRequest -Uri $zipUrl -UseBasicParsing -OutFile $zipPath -Headers @{ 'User-Agent' = 'MoveToContextInstaller/1.0' }
    }
    catch {
        throw "Failed to download package from GitHub. URL: $zipUrl | Error: $($_.Exception.Message)"
    }

    try {
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force
    }
    catch {
        throw "Failed to extract downloaded package. Error: $($_.Exception.Message)"
    }

    $roots = @(Get-ChildItem -LiteralPath $extractPath -Directory -ErrorAction SilentlyContinue)
    if ($roots.Count -eq 0) { throw 'Downloaded package extraction produced no root folder.' }
    $packageRoot = $roots[0].FullName

    $candidateRoots = @($packageRoot) + @(Get-ChildItem -LiteralPath $extractPath -Directory -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    $selectedRoot = $null
    foreach ($candidate in $candidateRoots) {
        if ((Test-Path -LiteralPath (Join-Path $candidate 'MoveTo.vbs')) -and (Test-Path -LiteralPath (Join-Path $candidate 'SyncMoveToMenu.ps1'))) {
            $selectedRoot = $candidate
            break
        }
    }
    if (-not $selectedRoot) { throw 'Could not locate valid package root after extraction.' }
    Assert-RequiredPackageFiles -Root $selectedRoot
    Write-Step -Text ("Using downloaded package root: {0}" -f $selectedRoot) -Color DarkGray
    return $selectedRoot
}

function Copy-FileIfNeeded {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )
    $sourceNorm = Resolve-NormalizedPath -Path $Source
    $destNorm = Resolve-NormalizedPath -Path $Destination
    if ([string]::Equals($sourceNorm, $destNorm, [System.StringComparison]::OrdinalIgnoreCase)) { return }
    $dir = Split-Path -Path $Destination -Parent
    Ensure-Directory -Path $dir
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Patch-HardcodedMoveToPaths {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$SourceRoot
    )

    $text = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8
    $installEscaped = $InstallRoot.Replace('\', '\\')
    $sourceEscaped = $SourceRoot.Replace('\', '\\')
    $legacyEscaped = $script:LegacyRoot.Replace('\', '\\')

    $patched = $text
    $patched = $patched.Replace($script:LegacyRoot, $InstallRoot)
    $patched = $patched.Replace($SourceRoot, $InstallRoot)
    $patched = $patched.Replace($legacyEscaped, $installEscaped)
    $patched = $patched.Replace($sourceEscaped, $installEscaped)

    if ($patched -ne $text) {
        Set-Content -LiteralPath $FilePath -Value $patched -Encoding UTF8
    }
}

function Deploy-PackageFiles {
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$InstallRoot
    )
    foreach ($entry in @(Get-RequiredPackageEntries)) {
        $src = Join-Path $SourceRoot $entry
        $dst = Join-Path $InstallRoot $entry
        Copy-FileIfNeeded -Source $src -Destination $dst
    }

    # One-time cleanup of legacy tune artifacts from older installs.
    foreach ($legacyEntry in @('RoboTune.ps1', 'RoboTune.json')) {
        $legacyPath = Join-Path $InstallRoot $legacyEntry
        if (Test-Path -LiteralPath $legacyPath) {
            Remove-Item -LiteralPath $legacyPath -Force -ErrorAction SilentlyContinue
        }
    }

    $installerSource = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($installerSource) -and $MyInvocation.MyCommand) {
        $installerSource = $MyInvocation.MyCommand.Definition
    }
    if (-not [string]::IsNullOrWhiteSpace($installerSource) -and (Test-Path -LiteralPath $installerSource)) {
        Copy-FileIfNeeded -Source $installerSource -Destination (Join-Path $InstallRoot 'Install.ps1')
    }

    Ensure-Directory -Path (Join-Path $InstallRoot 'destinations')
    Ensure-Directory -Path (Join-Path $InstallRoot 'logs')
    Ensure-Directory -Path (Join-Path $InstallRoot 'state')
    Ensure-Directory -Path (Join-Path $InstallRoot 'state\staging')
}

function Migrate-LegacyData {
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$SourceRoot
    )

    $legacyRootNorm = Resolve-NormalizedPath -Path $script:LegacyRoot
    $installRootNorm = Resolve-NormalizedPath -Path $InstallRoot
    if ($legacyRootNorm -ieq $installRootNorm) { return }

    $candidateRoots = @($SourceRoot, $script:LegacyRoot) | Select-Object -Unique
    foreach ($root in $candidateRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }

        $srcDest = Join-Path $root 'destinations'
        $dstDest = Join-Path $InstallRoot 'destinations'
        if (Test-Path -LiteralPath $srcDest) {
            Get-ChildItem -LiteralPath $srcDest -File -Filter '*.lnk' -ErrorAction SilentlyContinue | ForEach-Object {
                $target = Join-Path $dstDest $_.Name
                if (-not (Test-Path -LiteralPath $target)) {
                    Copy-Item -LiteralPath $_.FullName -Destination $target -Force
                }
            }
        }

        $srcLogs = Join-Path $root 'logs'
        $dstLogs = Join-Path $InstallRoot 'logs'
        if (Test-Path -LiteralPath $srcLogs) {
            Get-ChildItem -LiteralPath $srcLogs -File -ErrorAction SilentlyContinue | ForEach-Object {
                $target = Join-Path $dstLogs $_.Name
                if (-not (Test-Path -LiteralPath $target)) {
                    Copy-Item -LiteralPath $_.FullName -Destination $target -Force
                }
            }
        }
    }
}

function Invoke-RegCommand {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Arguments,
        [switch]$IgnoreNotFound
    )
    $output = & reg.exe @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        $text = ($output | Out-String).Trim()
        if ($IgnoreNotFound -and $text -match 'unable to find the specified registry key or value') {
            return $null
        }
        throw "reg.exe failed (exit $exitCode): reg $($Arguments -join ' ')`n$text"
    }
    return $output
}

function Add-RegStringValue {
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )
    Invoke-RegCommand -Arguments @('add', $Key, '/v', $Name, '/t', 'REG_SZ', '/d', $Value, '/f') | Out-Null
}

function Add-RegDefaultValue {
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )
    Invoke-RegCommand -Arguments @('add', $Key, '/ve', '/t', 'REG_SZ', '/d', $Value, '/f') | Out-Null
}

function Remove-RegTree {
    param([Parameter(Mandatory)][string]$Key)
    Invoke-RegCommand -Arguments @('delete', $Key, '/f') -IgnoreNotFound | Out-Null
}

function Remove-MoveToRegistryKeys {
    Write-Step -Text 'Cleaning old MoveTo registry keys...' -Color Cyan
    $paths = @(
        'HKCU\Software\Classes\*\shell\MoveToCustom',
        'HKCU\Software\Classes\Directory\shell\MoveToCustom',
        'HKCU\Software\Classes\*\shell\Z_MoveTo',
        'HKCU\Software\Classes\Directory\shell\Z_MoveTo',
        'HKCR\*\shell\MoveToCustom',
        'HKCR\Directory\shell\MoveToCustom',
        'HKCR\*\shell\Z_MoveTo',
        'HKCR\Directory\shell\Z_MoveTo'
    )
    foreach ($path in $paths) {
        try { Remove-RegTree -Key $path } catch { Add-Warning -Message ("Failed to remove key: {0}" -f $path) }
    }
}

function Write-MoveToRegistry {
    param([Parameter(Mandatory)][string]$InstallRoot)

    Remove-MoveToRegistryKeys

    $editVbs = Join-Path $InstallRoot 'EditDestinations.vbs'
    $addVbs = Join-Path $InstallRoot 'AddMoveToDestination.vbs'

    $fileRoot = 'HKCU\Software\Classes\*\shell\Z_MoveTo'
    $dirRoot  = 'HKCU\Software\Classes\Directory\shell\Z_MoveTo'

    Add-RegStringValue -Key $fileRoot -Name 'MUIVerb' -Value 'Move To'
    Add-RegStringValue -Key $fileRoot -Name 'Icon' -Value 'shell32.dll,-16761'
    Add-RegStringValue -Key $fileRoot -Name 'SubCommands' -Value ''
    Invoke-RegCommand -Arguments @('add', "$fileRoot\shell", '/f') | Out-Null

    $fileActions = "$fileRoot\shell\aaa_Actions"
    Add-RegStringValue -Key $fileActions -Name 'MUIVerb' -Value '[Actions]'
    Add-RegStringValue -Key $fileActions -Name 'Icon' -Value 'shell32.dll,-16710'
    Add-RegStringValue -Key $fileActions -Name 'SubCommands' -Value ''
    Invoke-RegCommand -Arguments @('add', "$fileActions\shell", '/f') | Out-Null

    $fileEdit = "$fileActions\shell\zz_Edit"
    Add-RegStringValue -Key $fileEdit -Name 'MUIVerb' -Value '[Edit destinations]'
    Add-RegStringValue -Key $fileEdit -Name 'Icon' -Value 'shell32.dll,-16710'
    Add-RegDefaultValue -Key "$fileEdit\command" -Value ("wscript.exe `"$editVbs`"")

    Add-RegStringValue -Key $dirRoot -Name 'MUIVerb' -Value 'Move To'
    Add-RegStringValue -Key $dirRoot -Name 'Icon' -Value 'shell32.dll,-16761'
    Add-RegStringValue -Key $dirRoot -Name 'SubCommands' -Value ''
    Invoke-RegCommand -Arguments @('add', "$dirRoot\shell", '/f') | Out-Null

    $dirActions = "$dirRoot\shell\aaa_Actions"
    Add-RegStringValue -Key $dirActions -Name 'MUIVerb' -Value '[Actions]'
    Add-RegStringValue -Key $dirActions -Name 'Icon' -Value 'shell32.dll,-16710'
    Add-RegStringValue -Key $dirActions -Name 'SubCommands' -Value ''
    Invoke-RegCommand -Arguments @('add', "$dirActions\shell", '/f') | Out-Null

    $dirAdd = "$dirActions\shell\yy_Add"
    Add-RegStringValue -Key $dirAdd -Name 'MUIVerb' -Value '[Add as destination]'
    Add-RegStringValue -Key $dirAdd -Name 'Icon' -Value 'shell32.dll,-16769'
    Add-RegDefaultValue -Key "$dirAdd\command" -Value ("wscript.exe `"$addVbs`" `"%1`"")

    $dirEdit = "$dirActions\shell\zz_Edit"
    Add-RegStringValue -Key $dirEdit -Name 'MUIVerb' -Value '[Edit destinations]'
    Add-RegStringValue -Key $dirEdit -Name 'Icon' -Value 'shell32.dll,-16710'
    Add-RegDefaultValue -Key "$dirEdit\command" -Value ("wscript.exe `"$editVbs`"")
}

function Set-UninstallEntry {
    param([Parameter(Mandatory)][string]$InstallRoot)
    $parent = Split-Path -Path $script:UninstallKeyPath -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -Path $parent -Force | Out-Null
    }
    New-Item -Path $script:UninstallKeyPath -Force | Out-Null
    New-ItemProperty -Path $script:UninstallKeyPath -Name 'DisplayName' -Value 'MoveTo Context Menu' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $script:UninstallKeyPath -Name 'DisplayVersion' -Value $script:InstallerVersion -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $script:UninstallKeyPath -Name 'Publisher' -Value 'joty79' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $script:UninstallKeyPath -Name 'InstallLocation' -Value $InstallRoot -PropertyType String -Force | Out-Null
    $uninstallCmd = "pwsh -NoProfile -ExecutionPolicy Bypass -File `"$InstallRoot\Install.ps1`" -Action Uninstall -Force"
    New-ItemProperty -Path $script:UninstallKeyPath -Name 'UninstallString' -Value $uninstallCmd -PropertyType String -Force | Out-Null
}

function Remove-UninstallEntry {
    if (Test-Path -LiteralPath $script:UninstallKeyPath) {
        Remove-Item -LiteralPath $script:UninstallKeyPath -Recurse -Force
    }
}

function Restart-ExplorerShell {
    if ($NoExplorerRestart) {
        Add-Warning -Message 'Explorer restart skipped by -NoExplorerRestart.'
        return
    }
    if (-not $Force) {
        $answer = (Read-Host 'Restart Explorer now to refresh context menus? [Y/n]').Trim().ToLowerInvariant()
        if ($answer -in @('n', 'no')) {
            Add-Warning -Message 'Explorer restart skipped by user.'
            return
        }
    }
    try {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Process explorer.exe
        Write-Step -Text 'Explorer restarted.' -Color Green
    }
    catch {
        Add-Warning -Message 'Explorer restart failed. Restart Explorer manually.'
    }
}

function Invoke-SyncMoveToMenu {
    param([Parameter(Mandatory)][string]$InstallRoot)
    $syncScript = Join-Path $InstallRoot 'SyncMoveToMenu.ps1'
    if (-not (Test-Path -LiteralPath $syncScript)) { return }
    try {
        & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $syncScript | Out-Null
    }
    catch {
        Add-Warning -Message ("SyncMoveToMenu failed: {0}" -f $_.Exception.Message)
    }
}

function Verify-CoreRuntimeFiles {
    param([Parameter(Mandatory)][string]$InstallRoot)
    $required = @(Get-RequiredPackageEntries) + @('Install.ps1', 'destinations', 'logs', 'state')
    $allOk = $true
    Write-Host ''
    Write-Host 'Core file verification:' -ForegroundColor Cyan
    foreach ($entry in $required) {
        $full = Join-Path $InstallRoot $entry
        if (Test-Path -LiteralPath $full) {
            Write-Host ("[+] {0}" -f $entry) -ForegroundColor Green
        }
        else {
            $allOk = $false
            Write-Host ("[x] {0}" -f $entry) -ForegroundColor Red
            Add-Warning -Message ("Core item missing: {0}" -f $entry)
        }
    }
    return $allOk
}

function Invoke-InstallOrUpdate {
    param([Parameter(Mandatory)][ValidateSet('Install', 'Update')][string]$Mode)

    Write-Banner
    Write-Step -Text ("Starting {0} to {1}" -f $Mode, $InstallPath) -Color Cyan
    Write-Step -Text ("Package source mode: {0}" -f $PackageSource) -Color DarkGray
    Write-Step -Text ("Source path: {0}" -f $SourcePath) -Color DarkGray

    if (-not (Invoke-Preflight)) {
        Write-Host ''
        Write-Host 'Operation aborted: missing required dependencies.' -ForegroundColor Red
        return 1
    }

    Ensure-Directory -Path $InstallPath
    Ensure-Directory -Path (Join-Path $InstallPath 'logs')
    Ensure-Directory -Path (Join-Path $InstallPath 'state')
    Ensure-Directory -Path (Join-Path $InstallPath 'state\staging')
    Ensure-Directory -Path (Join-Path $InstallPath 'destinations')

    $effectiveSourceRoot = $null
    try {
        $effectiveSourceRoot = Resolve-PackageSourceRoot
        Deploy-PackageFiles -SourceRoot $effectiveSourceRoot -InstallRoot $InstallPath
    }
    finally {
        foreach ($temp in $script:TempPackageRoots) {
            try {
                if (Test-Path -LiteralPath $temp) {
                    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            catch {}
        }
        $script:TempPackageRoots.Clear()
    }

    Migrate-LegacyData -InstallRoot $InstallPath -SourceRoot $SourcePath

    foreach ($entry in @(
        'AddMoveToDestination.vbs',
        'EditDestinations.vbs',
        'AddMoveToDestination.ps1',
        'EditDestinations.ps1',
        'SyncMoveToMenu.ps1'
    )) {
        Patch-HardcodedMoveToPaths -FilePath (Join-Path $InstallPath $entry) -InstallRoot $InstallPath -SourceRoot $SourcePath
    }

    Write-MoveToRegistry -InstallRoot $InstallPath
    Invoke-SyncMoveToMenu -InstallRoot $InstallPath
    Set-UninstallEntry -InstallRoot $InstallPath
    $coreOk = Verify-CoreRuntimeFiles -InstallRoot $InstallPath
    Restart-ExplorerShell

    Write-Host ''
    if ($script:Warnings.Count -gt 0 -or -not $coreOk) {
        Write-Host ("{0} completed with warnings." -f $Mode) -ForegroundColor Yellow
        return 2
    }
    Write-Host ("{0} completed successfully." -f $Mode) -ForegroundColor Green
    return 0
}

function Invoke-Uninstall {
    Write-Banner
    Write-Step -Text ("Starting uninstall from {0}" -f $InstallPath) -Color Cyan
    try {
        Remove-MoveToRegistryKeys
        Remove-UninstallEntry

        if (Test-Path -LiteralPath $InstallPath) {
            $selfPath = $PSCommandPath
            if ([string]::IsNullOrWhiteSpace($selfPath) -and $MyInvocation.MyCommand) {
                $selfPath = $MyInvocation.MyCommand.Definition
            }

            $installerKeepPath = Join-Path $InstallPath 'Install.ps1'
            $moveTuneKeepPath = Join-Path $InstallPath 'MoveTune.ps1'
            $preserveNames = @('Install.ps1', 'MoveTune.ps1')
            if (-not [string]::IsNullOrWhiteSpace($selfPath) -and (Test-Path -LiteralPath $selfPath)) {
                $selfNorm = Resolve-NormalizedPath -Path $selfPath
                $keepNorm = Resolve-NormalizedPath -Path $installerKeepPath
                if (-not $selfNorm.Equals($keepNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
                    Copy-Item -LiteralPath $selfPath -Destination $installerKeepPath -Force
                    Write-Step -Text 'Refreshed preserved Install.ps1 in install directory.' -Color Gray
                }
            }

            foreach ($item in @(Get-ChildItem -LiteralPath $InstallPath -Force -ErrorAction SilentlyContinue)) {
                if ($preserveNames -contains $item.Name) { continue }
                try {
                    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                }
                catch {
                    Add-Warning -Message ("Could not remove item during uninstall cleanup: {0}" -f $item.FullName)
                }
            }

            Write-Step -Text ("Uninstall cleanup complete. Preserved: {0}, {1}" -f $installerKeepPath, $moveTuneKeepPath) -Color Gray
        }

        Restart-ExplorerShell
        Write-Host 'Uninstall completed successfully.' -ForegroundColor Green
        return 0
    }
    catch {
        Write-Host ("Uninstall failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
        return 3
    }
}

function Show-InteractiveMenu {
    while ($true) {
        Write-Banner
        Write-Host ('Source:  {0}' -f $SourcePath) -ForegroundColor DarkGray
        Write-Host ('Install: {0}' -f $InstallPath) -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '[1] Install' -ForegroundColor Green
        Write-Host '[2] Update' -ForegroundColor Yellow
        Write-Host '[3] Uninstall' -ForegroundColor Red
        Write-Host '[4] Open install directory' -ForegroundColor Cyan
        Write-Host '[5] Launch MoveTune' -ForegroundColor Cyan
        Write-Host '[0] Exit' -ForegroundColor Gray
        Write-Host ''
        $choice = (Read-Host 'Select option').Trim()
        switch ($choice) {
            '1' { return 'Install' }
            '2' { return 'Update' }
            '3' { return 'Uninstall' }
            '4' { return 'OpenInstallDirectory' }
            '5' { return 'LaunchMoveTune' }
            '0' { return 'Exit' }
            default {
                Write-Host 'Invalid option. Press any key...' -ForegroundColor Red
                [void][System.Console]::ReadKey($true)
            }
        }
    }
}

function Confirm-Action {
    param([Parameter(Mandatory)][string]$Prompt)
    if ($Force) { return $true }
    $answer = (Read-Host "$Prompt [y/N]").Trim().ToLowerInvariant()
    $answer -eq 'y'
}

function Get-GitHubBranchNames {
    param([Parameter(Mandatory)][string]$Repo)

    $apiUrl = "https://api.github.com/repos/$Repo/branches?per_page=100"
    try {
        $resp = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'MoveToContextInstaller/1.0' } -Method Get
        if (-not $resp) { return @() }
        $names = @($resp | ForEach-Object { [string]$_.name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        return @($names | Select-Object -Unique)
    }
    catch {
        Write-Host ("[!] Could not fetch branch list from GitHub: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
        return @()
    }
}

function Read-GitHubRefInteractive {
    param(
        [string]$DefaultRef = 'master',
        [string]$Repo = 'joty79/MoveTo'
    )

    $normalizedDefault = if ([string]::IsNullOrWhiteSpace($DefaultRef)) { 'master' } else { $DefaultRef.Trim() }
    $branches = @(Get-GitHubBranchNames -Repo $Repo)

    if ($branches.Count -gt 0) {
        if ($branches -notcontains $normalizedDefault) {
            $branches = @($normalizedDefault) + @($branches)
        }
        else {
            $branches = @($normalizedDefault) + @($branches | Where-Object { $_ -ne $normalizedDefault })
        }
        $branches = @($branches | Select-Object -Unique)

        Write-Host ''
        Write-Host ("Available branches for {0}:" -f $Repo) -ForegroundColor Cyan
        for ($i = 0; $i -lt $branches.Count; $i++) {
            $n = $i + 1
            $name = $branches[$i]
            $suffix = if ($name -eq $normalizedDefault) { " (default)" } else { "" }
            Write-Host ("[{0}] {1}{2}" -f $n, $name, $suffix) -ForegroundColor Gray
        }
        Write-Host "[M] Manual branch/ref input" -ForegroundColor Gray
        Write-Host "[Enter] Use default" -ForegroundColor Gray

        while ($true) {
            $choice = (Read-Host ("Select branch number (blank = {0})" -f $normalizedDefault)).Trim()
            if ([string]::IsNullOrWhiteSpace($choice)) {
                return $normalizedDefault
            }
            if ($choice.Equals('m', [System.StringComparison]::OrdinalIgnoreCase)) {
                break
            }
            if ($choice -match '^\d+$') {
                $index = [int]$choice
                if ($index -ge 1 -and $index -le $branches.Count) {
                    return $branches[$index - 1]
                }
            }
            Write-Host 'Invalid selection. Choose a number, M, or Enter.' -ForegroundColor Yellow
        }
    }

    while ($true) {
        $raw = Read-Host ("GitHub branch/ref (blank = {0})" -f $normalizedDefault)
        $candidate = if ($null -eq $raw) { '' } else { $raw.Trim() }
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            return $normalizedDefault
        }

        if ($candidate.StartsWith('refs/heads/', [System.StringComparison]::OrdinalIgnoreCase)) {
            $candidate = $candidate.Substring('refs/heads/'.Length)
        }

        if ([string]::IsNullOrWhiteSpace($candidate)) {
            Write-Host 'Invalid branch/ref. Try again.' -ForegroundColor Yellow
            continue
        }

        return $candidate
    }
}

function Open-InstallDirectory {
    if (-not (Test-Path -LiteralPath $InstallPath)) {
        Write-Host ("Install directory not found: {0}" -f $InstallPath) -ForegroundColor Yellow
        return 1
    }
    Start-Process explorer.exe -ArgumentList $InstallPath
    return 0
}

function Launch-MoveTune {
    $scriptPath = Join-Path $InstallPath 'MoveTune.ps1'
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        Write-Host ("MoveTune is not installed yet: {0}" -f $scriptPath) -ForegroundColor Yellow
        return 1
    }
    Start-Process pwsh.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath)
    return 0
}

function Invoke-Main {
    if (-not $script:HasCliArgs) {
        $menuAction = Show-InteractiveMenu
        if ($menuAction -eq 'Exit') { return 0 }
        if ($menuAction -eq 'OpenInstallDirectory') { return (Open-InstallDirectory) }
        if ($menuAction -eq 'LaunchMoveTune') { return (Launch-MoveTune) }
        $Action = $menuAction
    }

    switch ($Action) {
        'Install' {
            $PackageSource = 'GitHub'
            if (-not $script:HasCliArgs) {
                $GitHubRef = Read-GitHubRefInteractive -DefaultRef $GitHubRef -Repo $GitHubRepo
            }
            Write-Host ("Using GitHub ref: {0}" -f $GitHubRef) -ForegroundColor DarkCyan
            if (-not (Confirm-Action -Prompt "Install MoveTo Context Menu to '$InstallPath'?")) { Write-Host 'Cancelled.' -ForegroundColor Yellow; return 0 }
            return (Invoke-InstallOrUpdate -Mode 'Install')
        }
        'Update' {
            $PackageSource = 'GitHub'
            if (-not $script:HasCliArgs) {
                $GitHubRef = Read-GitHubRefInteractive -DefaultRef $GitHubRef -Repo $GitHubRepo
            }
            Write-Host ("Using GitHub ref: {0}" -f $GitHubRef) -ForegroundColor DarkCyan
            if (-not (Confirm-Action -Prompt "Update MoveTo Context Menu at '$InstallPath'?")) { Write-Host 'Cancelled.' -ForegroundColor Yellow; return 0 }
            return (Invoke-InstallOrUpdate -Mode 'Update')
        }
        'Uninstall' {
            if (-not (Confirm-Action -Prompt "Uninstall MoveTo Context Menu from '$InstallPath'?")) { Write-Host 'Cancelled.' -ForegroundColor Yellow; return 0 }
            if (-not (Test-IsProcessElevated)) {
                Write-Step -Text 'Uninstall requires elevation for full registry cleanup. Requesting admin rights...' -Color Yellow
                return (Invoke-SelfElevatedUninstall -InstallRoot $InstallPath -InstallSourceRoot $SourcePath -NoRestartExplorer:$NoExplorerRestart)
            }
            return (Invoke-Uninstall)
        }
        default {
            Write-Host "Unknown action: $Action" -ForegroundColor Red
            return 1
        }
    }
}

exit (Invoke-Main)
