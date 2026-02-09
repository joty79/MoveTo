$script = "D:\Users\joty79\scripts\MoveTo\ApplyMoveTo.cmd"
if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
    Write-Error "ApplyMoveTo.cmd not found."
    exit 1
}
cmd /c "`"$script`""
