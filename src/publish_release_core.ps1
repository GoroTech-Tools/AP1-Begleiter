# src\publish_release_core.ps1 - Build + GitHub Release in einem Lauf
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
    Write-Host "  -SkipBuild  : Build-Schritt ueberspringen" -ForegroundColor DarkGray
    Write-Host "  -Draft      : Release als Entwurf anlegen" -ForegroundColor DarkGray
    Write-Host "  -PreRelease : Release als Pre-Release markieren" -ForegroundColor DarkGray
    Write-Host "  -Help       : Diese Hilfe anzeigen" -ForegroundColor DarkGray
    exit 0
}

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$ProjectRoot = Split-Path -Path $ScriptDir -Parent
Set-Location $ProjectRoot

function Assert-LastExitCode {
    param([string]$ErrorMessage)
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
git rev-parse --is-inside-work-tree *> $null
Assert-LastExitCode -ErrorMessage "Aktueller Ordner ist kein Git-Repository."

gh auth status *> $null
Assert-LastExitCode -ErrorMessage "GitHub CLI ist nicht authentifiziert. Bitte zuerst 'gh auth login' ausfuehren."

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

$effectiveVersion = if ([string]::IsNullOrWhiteSpace($Version)) { $rawVersionFromFile } else { $Version }
$versionTag = Get-NormalizedVersionTag -RawVersion $effectiveVersion
$artifactBaseName = "AP1-Begleiter-Portable_{0}" -f $versionTag
$releaseMessage = "Release_{0}" -f $versionTag
$zipPath = Join-Path "release" ("{0}.zip" -f $artifactBaseName)
$releaseNotesPath = Join-Path "release" ("RELEASE_NOTES_{0}.md" -f $versionTag)

Write-Host "Version: $versionTag" -ForegroundColor DarkGray

# --- Optionaler Build ---
if (-not $SkipBuild) {
    Write-Host "1. Build laeuft ..." -ForegroundColor Cyan
    & (Join-Path $ScriptDir "build.ps1")
    Assert-LastExitCode -ErrorMessage "Build fehlgeschlagen."
}
else {
    Write-Host "1. Build uebersprungen (-SkipBuild)." -ForegroundColor Yellow
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
    Write-Host "2. Aenderungen committen ..." -ForegroundColor Cyan
    git add -A
    Assert-LastExitCode -ErrorMessage "git add fehlgeschlagen."

    git commit -m $releaseMessage
    Assert-LastExitCode -ErrorMessage "git commit fehlgeschlagen."
}
else {
    Write-Host "2. Keine uncommitteten Aenderungen." -ForegroundColor DarkGray
}

Write-Host "3. Push nach origin/main ..." -ForegroundColor Cyan
git push origin main
Assert-LastExitCode -ErrorMessage "Push nach origin/main fehlgeschlagen."

# --- Tag erstellen/pushen ---
git rev-parse -q --verify ("refs/tags/{0}" -f $versionTag) *> $null
$tagExistsLocal = ($LASTEXITCODE -eq 0)

if (-not $tagExistsLocal) {
    Write-Host "4. Tag anlegen: $versionTag" -ForegroundColor Cyan
    git tag -a $versionTag -m $releaseMessage
    Assert-LastExitCode -ErrorMessage "Tag-Anlage fehlgeschlagen."
}
else {
    Write-Host "4. Tag existiert bereits lokal: $versionTag" -ForegroundColor DarkGray
}

Write-Host "4b. Tag pushen ..." -ForegroundColor Cyan
git push origin $versionTag
Assert-LastExitCode -ErrorMessage "Tag-Push fehlgeschlagen."

# --- GitHub Release erstellen/aktualisieren ---
gh release view $versionTag --json tagName *> $null
$releaseExists = ($LASTEXITCODE -eq 0)

if (-not $releaseExists) {
    Write-Host "5. GitHub Release erstellen ..." -ForegroundColor Cyan

    $createArgs = @(
        "release", "create", $versionTag,
        ("{0}#AP1-Begleiter-Portable_{1}.zip" -f $zipPath, $versionTag),
        "--title", $versionTag,
        "--notes-file", $releaseNotesPath
    )
    if ($Draft) { $createArgs += "--draft" }
    if ($PreRelease) { $createArgs += "--prerelease" }

    gh @createArgs
    Assert-LastExitCode -ErrorMessage "GitHub Release-Erstellung fehlgeschlagen."
}
else {
    Write-Host "5. GitHub Release existiert bereits. Asset/Notes werden aktualisiert ..." -ForegroundColor Yellow

    gh release upload $versionTag $zipPath --clobber
    Assert-LastExitCode -ErrorMessage "Release-Asset-Upload fehlgeschlagen."

    gh release edit $versionTag --title $versionTag --notes-file $releaseNotesPath
    Assert-LastExitCode -ErrorMessage "Release-Update fehlgeschlagen."
}

$releaseUrl = (gh release view $versionTag --json url -q .url).Trim()
Write-Host "`nOK. Release veroeffentlicht: $releaseUrl" -ForegroundColor Green
