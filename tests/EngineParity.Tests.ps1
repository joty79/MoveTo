Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$engineFiles = @(
    (Join-Path $repoRoot "rcp.ps1"),
    (Join-Path $repoRoot "rcopySingle.ps1")
)

foreach ($engineFile in $engineFiles) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $engineFile,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        throw "Parser errors in $engineFile`n$($parseErrors | Out-String)"
    }
}

$rcpSource = Get-Content -LiteralPath (Join-Path $repoRoot "rcp.ps1") -Raw
$stageSource = Get-Content -LiteralPath (Join-Path $repoRoot "rcopySingle.ps1") -Raw

$requiredRcpMarkers = @(
    "function Test-IsSnapshotFreshForResolve",
    "Stage resolve waiting for fresh snapshot",
    "ActiveMarkerSeen"
)
$requiredStageMarkers = @(
    "function Get-ExistingStageHeader",
    "EmptySelectionGuard",
    "SingleMismatchGuard",
    "AllTopLevelFilesToken",
    "DesktopDirectEnterLogged"
)

foreach ($marker in $requiredRcpMarkers) {
    if (-not $rcpSource.Contains($marker)) { throw "Missing rcp.ps1 safety marker: $marker" }
}
foreach ($marker in $requiredStageMarkers) {
    if (-not $stageSource.Contains($marker)) { throw "Missing rcopySingle.ps1 safety marker: $marker" }
}

if (-not $rcpSource.Contains('Join-Path $PSScriptRoot "MoveTune.json"')) {
    throw "rcp.ps1 must use MoveTune.json"
}
if (-not $stageSource.Contains('Join-Path $PSScriptRoot "MoveTune.json"')) {
    throw "rcopySingle.ps1 must use MoveTune.json"
}
if (($rcpSource + $stageSource) -match 'RoboTune\.(ps1|json)') {
    throw "MoveTo engine must not reference RoboTune.ps1 or RoboTune.json"
}

Write-Output "PASS: MoveTo engine parser, safety markers, and MoveTune-only policy"
