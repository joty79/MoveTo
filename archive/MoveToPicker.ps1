param([string]$SourcePath)

if (-not $SourcePath -and $args.Count -gt 0) {
    $SourcePath = $args[0]
}

if (-not $SourcePath -or -not (Test-Path -LiteralPath $SourcePath)) {
    exit 1
}

$basePath = "D:\Users\joty79\scripts\MoveTo"
$destinationsFolder = Join-Path $basePath "destinations"
$moveScript = Join-Path $basePath "MoveTo.ps1"
$editScript = Join-Path $basePath "EditDestinations.ps1"

if (-not (Test-Path -LiteralPath $destinationsFolder -PathType Container)) {
    New-Item -Path $destinationsFolder -ItemType Directory -Force | Out-Null
}

$links = Get-ChildItem -LiteralPath $destinationsFolder -Filter *.lnk -File | Sort-Object Name
if (-not $links -or $links.Count -eq 0) {
    Write-Host "No destinations found. Use 'Add as destination' first." -ForegroundColor Yellow
    Start-Sleep 2
    exit 1
}

Write-Host ""
Write-Host "Move To - choose destination:" -ForegroundColor Cyan

$i = 1
foreach ($lnk in $links) {
    Write-Host ("[{0}] {1}" -f $i, [IO.Path]::GetFileNameWithoutExtension($lnk.Name))
    $i++
}
Write-Host "[E] Edit destinations"
Write-Host "[Q] Cancel"

$choice = Read-Host "Choice"

if ($choice -match '^[Qq]$') { exit 0 }
if ($choice -match '^[Ee]$') {
    & $editScript
    exit 0
}

$selected = 0
if (-not [int]::TryParse($choice, [ref]$selected)) { exit 1 }
if ($selected -lt 1 -or $selected -gt $links.Count) { exit 1 }

$shortcutName = [IO.Path]::GetFileNameWithoutExtension($links[$selected - 1].Name)
& $moveScript $SourcePath $shortcutName
