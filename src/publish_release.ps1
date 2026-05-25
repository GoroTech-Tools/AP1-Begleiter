# src\publish_release.ps1 - Komfort-Wrapper
param(
    [string]$Version,
    [switch]$SkipBuild,
    [switch]$Draft,
    [switch]$PreRelease,
    [switch]$Help
)

$coreScript = Join-Path $PSScriptRoot "publish_release_core.ps1"
if (-not (Test-Path -LiteralPath $coreScript -PathType Leaf)) {
    throw "Core-Skript nicht gefunden: $coreScript"
}

& $coreScript @PSBoundParameters
exit $LASTEXITCODE
