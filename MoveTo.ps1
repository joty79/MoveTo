# MoveTo.ps1 - Moves files/folders using native Windows dialog
# Called by MoveTo.vbs after collecting all paths
# Uses Shell.Application.MoveHere() for native progress + conflict resolution

$tempFile = "$env:TEMP\MoveTo_paths.txt"

if (-not (Test-Path $tempFile)) { exit 0 }

# Read and parse all collected paths
$lines = Get-Content $tempFile -ErrorAction SilentlyContinue | Where-Object { $_ -and $_ -match '\|' }

# Cleanup temp file immediately
Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

if (-not $lines -or $lines.Count -eq 0) { exit 0 }

# Group by destination
$groups = @{}
foreach ($line in $lines) {
    $parts = $line -split '\|', 2
    if ($parts.Count -eq 2) {
        $dest = $parts[0]
        $source = $parts[1]
        if (-not $groups.ContainsKey($dest)) {
            $groups[$dest] = @()
        }
        $groups[$dest] += $source
    }
}

# Move using Shell.Application for native dialog
$shell = New-Object -ComObject Shell.Application

foreach ($dest in $groups.Keys) {
    $destFolder = $shell.NameSpace($dest)
    if (-not $destFolder) { continue }

    $sources = $groups[$dest]
    foreach ($source in $sources) {
        if (Test-Path -LiteralPath $source) {
            # Flag 0 = full native dialog (progress bar + conflict resolution)
            $destFolder.MoveHere($source, 0)
        }
    }
}
