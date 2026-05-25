# src\publish_release.ps1 - Build + GitHub Release in einem Lauf
#
# Standardablauf:
# 1) Build ausführen (src\build.ps1)
# 2) Änderungen committen (falls vorhanden)
# 3) main pushen
# 4) Git-Tag anlegen/pushen
# 5) GitHub-Release anlegen/aktualisieren
#
# Beispiele:
#   .\src\publish_release.ps1
#   .\src\publish_release.ps1 -Version v1.0.2
#   .\src\publish_release.ps1 -SkipBuild
#   .\src\publish_release.ps1 -Draft
param(
    [string]$Version,
    [switch]$SkipBuild,
    [switch]$Draft,
    [switch]$PreRelease,
    [switch]$Help
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $OutputEncoding = [System.Text.Encoding]::UTF8
}

if ($Help) {
    Write-Host "AP1-Begleiter-Portable Publish-Release" -ForegroundColor DarkCyan
    Write-Host "  -Version    : Optionaler Tag (z. B. v1.0.2). Ohne Angabe aus src/version_info.txt" -ForegroundColor DarkGray
    Write-Host "  -SkipBuild  : Build-Schritt überspringen" -ForegroundColor DarkGray
    Write-Host "  -Draft      : Release als Entwurf anlegen" -ForegroundColor DarkGray
    Write-Host "  -PreRelease : Release als Pre-Release markieren" -ForegroundColor DarkGray
    Write-Host "  -Help       : Diese Hilfe anzeigen" -ForegroundColor DarkGray
    exit 0
}

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$ProjectRoot = Split-Path -Path $ScriptDir -Parent
Set-Location $ProjectRoot

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string]$ErrorMessage
    )

    Invoke-Expression $Command
    if ($LASTEXITCODE -ne 0) {
        throw $ErrorMessage
    }
}

function Get-NormalizedVersionTag {
    param([string]$RawVersion)

    $fallback = "v0.0.0"
    $candidate = if ([string]::IsNullOrWhiteSpace($RawVersion)) { $fallback } else { $RawVersion.Trim() }

    $normalized = if ($candidate -match '^[vV]') {
        "v{0}" -f $candidate.TrimStart('v', 'V')
    }
    else {
        "v{0}" -f $candidate
    }

    return ($normalized -replace '[^0-9A-Za-z._-]', '_')
}

Write-Host "`nAP1-Begleiter-Portable - Publish Release" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

# --- Voraussetzungen prüfen ---
Invoke-CheckedCommand -Command "git rev-parse --is-inside-work-tree" -ErrorMessage "Aktueller Ordner ist kein Git-Repository."
Invoke-CheckedCommand -Command "gh auth status" -ErrorMessage "GitHub CLI ist nicht authentifiziert. Bitte zuerst 'gh auth login' ausführen."

$branch = (git branch --show-current).Trim()
if ($branch -ne "main") {
    throw "Bitte auf Branch 'main' wechseln (aktuell: '$branch')."
}

# --- Version/Artefaktpfade bestimmen ---
$versionFile = Join-Path $ScriptDir "version_info.txt"
$rawVersionFromFile = if (Test-Path -Path $versionFile -PathType Leaf) {
    (Get-Content -Path $versionFile -Raw -Encoding UTF8).Trim()
}
else {
    ""
}

$versionTag = Get-NormalizedVersionTag -RawVersion (if ([string]::IsNullOrWhiteSpace($Version)) { $rawVersionFromFile } else { $Version })
$artifactBaseName = "AP1-Begleiter-Portable_{0}" -f $versionTag
$zipPath = Join-Path "release" ("{0}.zip" -f $artifactBaseName)
$releaseNotesPath = Join-Path "release" ("RELEASE_NOTES_{0}.md" -f $versionTag)

Write-Host "Version: $versionTag" -ForegroundColor DarkGray

# --- Optionaler Build ---
if (-not $SkipBuild) {
    Write-Host "1. Build läuft ..." -ForegroundColor Cyan
    & (Join-Path $ScriptDir "build.ps1")
    if ($LASTEXITCODE -ne 0) {
        throw "Build fehlgeschlagen."
    }
}
else {
    Write-Host "1. Build übersprungen (-SkipBuild)." -ForegroundColor Yellow
}

if (-not (Test-Path -Path $zipPath -PathType Leaf)) {
    throw "ZIP-Artefakt nicht gefunden: $zipPath"
}
if (-not (Test-Path -Path $releaseNotesPath -PathType Leaf)) {
    throw "Release Notes nicht gefunden: $releaseNotesPath"
}

# --- Commit + Push ---
$statusLines = @(git status --porcelain)
if ($statusLines.Count -gt 0) {
    Write-Host "2. Änderungen committen ..." -ForegroundColor Cyan
    Invoke-CheckedCommand -Command "git add -A" -ErrorMessage "git add fehlgeschlagen."
    $commitCmd = 'git commit -m "Release ' + $versionTag + '"'
    Invoke-CheckedCommand -Command $commitCmd -ErrorMessage "git commit fehlgeschlagen."
}
else {
    Write-Host "2. Keine uncommitteten Änderungen." -ForegroundColor DarkGray
}

Write-Host "3. Push nach origin/main ..." -ForegroundColor Cyan
Invoke-CheckedCommand -Command "git push origin main" -ErrorMessage "Push nach origin/main fehlgeschlagen."

# --- Tag erstellen/pushen ---
$tagExistsLocal = $false
try {
    git rev-parse -q --verify "refs/tags/$versionTag" *> $null
    $tagExistsLocal = ($LASTEXITCODE -eq 0)
}
catch {
    $tagExistsLocal = $false
}

if (-not $tagExistsLocal) {
    Write-Host "4. Tag anlegen: $versionTag" -ForegroundColor Cyan
    $tagCmd = 'git tag -a ' + $versionTag + ' -m "Release ' + $versionTag + '"'
    Invoke-CheckedCommand -Command $tagCmd -ErrorMessage "Tag-Anlage fehlgeschlagen."
}
else {
    Write-Host "4. Tag existiert bereits lokal: $versionTag" -ForegroundColor DarkGray
}

Write-Host "4b. Tag pushen ..." -ForegroundColor Cyan
Invoke-CheckedCommand -Command ("git push origin {0}" -f $versionTag) -ErrorMessage "Tag-Push fehlgeschlagen."

# --- GitHub Release erstellen/aktualisieren ---
$releaseExists = $false
try {
    gh release view $versionTag --json tagName *> $null
    $releaseExists = ($LASTEXITCODE -eq 0)
}
catch {
    $releaseExists = $false
}

if (-not $releaseExists) {
    Write-Host "5. GitHub Release erstellen ..." -ForegroundColor Cyan

    $flags = @()
    if ($Draft) { $flags += "--draft" }
    if ($PreRelease) { $flags += "--prerelease" }

    $flagText = if ($flags.Count -gt 0) { " " + ($flags -join " ") } else { "" }
    $cmd = "gh release create {0} '{1}#AP1-Begleiter-Portable_{0}.zip' --title '{0}' --notes-file '{2}'{3}" -f $versionTag, $zipPath, $releaseNotesPath, $flagText
    Invoke-CheckedCommand -Command $cmd -ErrorMessage "GitHub Release-Erstellung fehlgeschlagen."
}
else {
    Write-Host "5. GitHub Release existiert bereits. Asset/Notes werden aktualisiert ..." -ForegroundColor Yellow
    Invoke-CheckedCommand -Command ("gh release upload {0} '{1}' --clobber" -f $versionTag, $zipPath) -ErrorMessage "Release-Asset-Upload fehlgeschlagen."
    Invoke-CheckedCommand -Command ("gh release edit {0} --title '{0}' --notes-file '{1}'" -f $versionTag, $releaseNotesPath) -ErrorMessage "Release-Update fehlgeschlagen."
}

$releaseUrl = (gh release view $versionTag --json url -q .url).Trim()
Write-Host "`n✅ Fertig. Release veröffentlicht: $releaseUrl" -ForegroundColor Green
