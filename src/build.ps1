# src\build.ps1 - Baut AP1-Begleiter-Portable.exe via PyInstaller
#
# Voraussetzung: .\src\setup.ps1 muss vorher einmal ausgefuehrt worden sein.
#
# Aufruf (aus Projektwurzel):
#   .\src\build.ps1              - normaler Build
#   .\src\build.ps1 -SkipZip     - ohne ZIP-Erstellung
#   .\src\build.ps1 -Help        - Hilfe anzeigen
param(
    [switch]$SkipZip,
    [switch]$Help
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $OutputEncoding = [System.Text.Encoding]::UTF8
}

if ($Help) {
    Write-Host "AP1-Begleiter-Portable Build-Skript" -ForegroundColor DarkCyan
    Write-Host "  -SkipZip : ZIP-Erstellung im release-Ordner überspringen" -ForegroundColor DarkGray
    Write-Host "  -Help    : Diese Hilfe anzeigen" -ForegroundColor DarkGray
    exit 0
}

$ErrorActionPreference = "Stop"

$ScriptDir    = $PSScriptRoot
$ProjectRoot  = Split-Path -Path $ScriptDir -Parent
Set-Location $ProjectRoot

$SpecFile    = Join-Path $ScriptDir "AP1-Begleiter-Portable.spec"
$SetupScript = Join-Path $ScriptDir "setup.ps1"
$VersionFile = Join-Path $ScriptDir "version_info.txt"
$VenvPython  = ".venv\Scripts\python.exe"
$BuiltExePath = "dist\AP1-Begleiter-Portable.exe"
$ReleaseDir  = "release"
$DocPath     = "docs\KURZDOKUMENTATION.txt"

$defaultVersion = "v0.0.0"
if (Test-Path -Path $VersionFile -PathType Leaf) {
    $rawVersion = (Get-Content -Path $VersionFile -Raw -Encoding UTF8).Trim()
    if ([string]::IsNullOrWhiteSpace($rawVersion)) {
        $rawVersion = $defaultVersion
    }
}
else {
    $rawVersion = $defaultVersion
}

$normalizedVersion = if ($rawVersion -match '^[vV]') {
    "v{0}" -f $rawVersion.TrimStart('v', 'V')
} else {
    "v{0}" -f $rawVersion
}

$versionTag = $normalizedVersion -replace '[^0-9A-Za-z._-]', '_'
$artifactBaseName = "AP1-Begleiter-Portable_{0}" -f $versionTag
$VersionedDistExePath = Join-Path "dist" ("{0}.exe" -f $artifactBaseName)
$ReleaseNotesPath = Join-Path $ReleaseDir ("RELEASE_NOTES_{0}.md" -f $versionTag)
$RootReadmePath = "README.md"
$RequiredUppercaseDocs = @(
    "DOKUMENTATION_ANWENDER.md",
    "DOKUMENTATION_TECHNIK.md"
)

function New-ReleaseNotesFile {
    param(
        [string]$Version,
        [string]$BuildDirName,
        [string]$DistExeName,
        [string]$ReleaseDir,
        [string]$ZipFileName
    )

    $notesPath = Join-Path $ReleaseDir ("RELEASE_NOTES_{0}.md" -f $Version)
    $buildDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $displayDate = (Get-Date).ToString("yyyy-MM-dd")
    $releaseUrl = "https://github.com/GoroTech-Tools/AP1-Begleiter/releases/tag/$Version"
    $zipDownloadUrl = if ($ZipFileName) {
        "https://github.com/GoroTech-Tools/AP1-Begleiter/releases/download/$Version/$ZipFileName"
    }
    else {
        $null
    }
    $zipArtifactLine = if ($ZipFileName) {
        "- Release-ZIP: release/$ZipFileName"
    }
    else {
        "- Release-ZIP: *(in diesem Lauf nicht erstellt)*"
    }
    $qualityZipLine = if ($ZipFileName) {
        "- ZIP-Artefakt im Release-Ordner erstellt."
    }
    else {
        "- ZIP-Artefakt in diesem Lauf nicht erstellt (`-SkipZip`)."
    }

    $recentCommits = @()
    try {
        foreach ($entry in (git log --oneline --no-decorate -5 2>$null)) {
            if ([string]::IsNullOrWhiteSpace($entry)) {
                continue
            }

            $parts = $entry -split " ", 2
            if ($parts.Count -eq 2) {
                $recentCommits += "- ``$($parts[0])`` $($parts[1])"
            }
            else {
                $recentCommits += "- $entry"
            }
        }
    }
    catch {
    }

    if (-not $recentCommits -or $recentCommits.Count -eq 0) {
        $recentCommits = @("- *(Commitliste konnte automatisch nicht ermittelt werden.)*")
    }

    $contentLines = @(
        "# Release Notes $Version",
        "",
        "Datum: $displayDate",
        "",
        "## Download",
        "",
        "- [Release-Seite $Version]($releaseUrl)",
        $(if ($zipDownloadUrl) { "- [ZIP direkt herunterladen]($zipDownloadUrl)" } else { "- ZIP-Direktdownload wird nach der ZIP-Erstellung ergänzt." }),
        "",
        "## Änderungen",
        "",
        "- Build, Paketierung und Dokumentation für $Version erstellt.",
        "- Bitte projektspezifische Änderungen bei Bedarf ergänzen.",
        "",
        "## Qualitätsstatus",
        "",
        "- Release-Build erfolgreich erzeugt.",
        "$qualityZipLine",
        "- Automatische Basisprüfung (Build/Packaging) im Skript durchlaufen.",
        "",
        "## Artefakte",
        "",
        "- Release-Verzeichnis: release/$BuildDirName/",
        "- EXE: dist/$DistExeName",
        "$zipArtifactLine",
        "",
        "## Enthaltene Commits (aktuelle Historie)",
        ""
    )

    $contentLines += $recentCommits
    $contentLines += @(
        "",
        "## Technische Build-Informationen",
        "",
        "- Build-Datum: $buildDate",
        "- Build-Modus: --onefile --windowed",
        "- EXE-Name: AP1-Begleiter-Portable.exe"
    )

    Set-Content -Path $notesPath -Value ($contentLines -join "`r`n") -Encoding utf8NoBOM
    Write-Host "Release Notes erstellt/aktualisiert: $notesPath" -ForegroundColor Green
    return $notesPath
}

Write-Host "`nAP1-Begleiter-Portable - Build" -ForegroundColor Green
Write-Host "======================`n" -ForegroundColor Green
Write-Host "Version: $versionTag" -ForegroundColor DarkGray

# --- Schritt 0: Dateinamenskonventionen pruefen ---
if (-not (Test-Path -Path $RootReadmePath -PathType Leaf)) {
    throw "README.md muss im Projektwurzelverzeichnis liegen: $RootReadmePath"
}

$DocsDir = "docs"
if (-not (Test-Path -Path $DocsDir -PathType Container)) {
    throw "docs-Verzeichnis nicht gefunden: $DocsDir"
}

$docFileNames = @(Get-ChildItem -Path $DocsDir -File | Select-Object -ExpandProperty Name)

foreach ($requiredName in $RequiredUppercaseDocs) {
    $hasExactName = $false
    foreach ($fileName in $docFileNames) {
        if ($fileName -ceq $requiredName) {
            $hasExactName = $true
            break
        }
    }

    if (-not $hasExactName) {
        throw "Pflichtdokumentation fehlt oder Schreibweise ist falsch: docs\\$requiredName"
    }
}

foreach ($requiredName in $RequiredUppercaseDocs) {
    $requiredLower = $requiredName.ToLowerInvariant()
    foreach ($fileName in $docFileNames) {
        if ($fileName.ToLowerInvariant() -eq $requiredLower -and $fileName -cne $requiredName) {
            throw "Unerlaubte Dateischreibweise gefunden. Bitte nur Großbuchstaben verwenden: docs\\$fileName"
        }
    }
}

Write-Host "0. ✅ Doku-Namenskonvention geprüft (README + GROSSSCHREIBUNG)" -ForegroundColor Green

# --- Schritt 1: venv pruefen ---
if (-not (Test-Path $VenvPython)) {
    Write-Host "venv nicht gefunden. Starte src\\setup.ps1 ..." -ForegroundColor Yellow
    & $SetupScript
}

# --- Schritt 2: PyInstaller-Build ---
Write-Host "1. PyInstaller-Build ..." -ForegroundColor Cyan

& $VenvPython -m PyInstaller $SpecFile --noconfirm

if ($LASTEXITCODE -ne 0) {
    Write-Host "PyInstaller fehlgeschlagen!" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $BuiltExePath)) {
    Write-Host "EXE nicht gefunden nach Build: $BuiltExePath" -ForegroundColor Red
    exit 1
}

Copy-Item $BuiltExePath $VersionedDistExePath -Force
Write-Host "   EXE erstellt: $BuiltExePath" -ForegroundColor Green
Write-Host "   Versionierte EXE erstellt: $VersionedDistExePath" -ForegroundColor Green

# --- Schritt 3: Release-Ordner ---
if (-not (Test-Path $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir | Out-Null
}

# Altes Legacy-Artefakt aus früherem Build-Schema entfernen
$legacyReleaseExe = Join-Path $ReleaseDir "AP1-Begleiter-Portable.exe"
if (Test-Path $legacyReleaseExe) {
    Remove-Item $legacyReleaseExe -Force -ErrorAction SilentlyContinue
}

$legacyReleasePackageDir = Join-Path $ReleaseDir "AP1-Begleiter-Portable"
if (Test-Path $legacyReleasePackageDir) {
    Remove-Item $legacyReleasePackageDir -Recurse -Force -ErrorAction SilentlyContinue
}

$legacyReleaseZip = Join-Path $ReleaseDir "AP1-Begleiter-Portable.zip"
if (Test-Path $legacyReleaseZip) {
    Remove-Item $legacyReleaseZip -Force -ErrorAction SilentlyContinue
}

$releasePackageDir = Join-Path $ReleaseDir $artifactBaseName
if (Test-Path $releasePackageDir) {
    Remove-Item $releasePackageDir -Recurse -Force
}
New-Item -ItemType Directory -Path $releasePackageDir | Out-Null

$releaseExe = Join-Path $releasePackageDir ("{0}.exe" -f $artifactBaseName)
try {
    Copy-Item $VersionedDistExePath $releaseExe -Force
    Write-Host "2. EXE in Release-Ordner kopiert: $releaseExe" -ForegroundColor Green
}
catch {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $fallbackReleasePackageDir = Join-Path $ReleaseDir ("{0}-{1}" -f $artifactBaseName, $timestamp)
    if (Test-Path $fallbackReleasePackageDir) {
        Remove-Item $fallbackReleasePackageDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $fallbackReleasePackageDir | Out-Null
    $fallbackReleaseExe = Join-Path $fallbackReleasePackageDir ("{0}.exe" -f $artifactBaseName)
    Copy-Item $VersionedDistExePath $fallbackReleaseExe -Force
    $releasePackageDir = $fallbackReleasePackageDir
    $releaseExe = $fallbackReleaseExe
    Write-Host "2. Standard-Releaseordner war gesperrt. EXE alternativ kopiert: $releaseExe" -ForegroundColor Yellow
}

if (-not (Test-Path $DocPath -PathType Leaf)) {
    throw "Dokumentation nicht gefunden: $DocPath"
}

$releaseDoc = Join-Path $releasePackageDir "KURZDOKUMENTATION.txt"
Copy-Item $DocPath $releaseDoc -Force
Write-Host "2b. Kurzdokumentation kopiert: $releaseDoc" -ForegroundColor Green

$zipName = "{0}.zip" -f (Split-Path $releasePackageDir -Leaf)
$releaseNotesPath = New-ReleaseNotesFile `
    -Version $versionTag `
    -BuildDirName (Split-Path $releasePackageDir -Leaf) `
    -DistExeName (Split-Path $VersionedDistExePath -Leaf) `
    -ReleaseDir $ReleaseDir `
    -ZipFileName $(if ($SkipZip) { $null } else { $zipName })
$releaseNotesTarget = Join-Path $releasePackageDir (Split-Path $releaseNotesPath -Leaf)
Copy-Item $releaseNotesPath $releaseNotesTarget -Force
Write-Host "2c. Release Notes kopiert: $releaseNotesTarget" -ForegroundColor Green

# --- Schritt 4: ZIP (optional) ---
if (-not $SkipZip) {
    $zipPath = Join-Path $ReleaseDir $zipName
    Compress-Archive -Path $releasePackageDir -DestinationPath $zipPath -Force
    Write-Host "3. ZIP des Release-Ordners erstellt: $zipPath" -ForegroundColor Green
}

Write-Host "`nBuild erfolgreich abgeschlossen!" -ForegroundColor Green
