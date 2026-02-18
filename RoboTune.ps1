param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$PassThruArgs
)

$moveTunePath = Join-Path $PSScriptRoot 'MoveTune.ps1'
if (-not (Test-Path -LiteralPath $moveTunePath)) {
    Write-Host ("MoveTune.ps1 not found: {0}" -f $moveTunePath) -ForegroundColor Red
    exit 1
}

& $moveTunePath @PassThruArgs
exit $LASTEXITCODE
