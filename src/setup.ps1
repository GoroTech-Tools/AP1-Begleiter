# src\setup.ps1 — Erstellt .venv und installiert Abhängigkeiten aus requirements.txt
# Aufruf (aus Projektwurzel): .\src\setup.ps1
# Optional: .\src\setup.ps1 -Force   (löscht bestehende .venv und erstellt neu)
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
$repo = Split-Path $ProjectRoot -Leaf
$VenvName = ".venv"
$RequirementsPath = Join-Path $PSScriptRoot "requirements.txt"

Set-Location $ProjectRoot

if ($Force -and (Test-Path ".\$VenvName")) {
    Write-Host "[$repo] Entferne bestehende $VenvName ..." -ForegroundColor Yellow
    Remove-Item ".\$VenvName" -Recurse -Force
}

if (-not (Test-Path ".\$VenvName")) {
    Write-Host "[$repo] Erstelle $VenvName ..." -ForegroundColor Cyan
    py -m venv $VenvName
} else {
    Write-Host "[$repo] $VenvName bereits vorhanden." -ForegroundColor DarkGray
}

Write-Host "[$repo] Aktualisiere pip ..." -ForegroundColor Cyan
& ".\$VenvName\Scripts\python.exe" -m pip install --upgrade pip -q

if (Test-Path $RequirementsPath) {
    Write-Host "[$repo] Installiere Pakete aus src\requirements.txt ..." -ForegroundColor Cyan
    & ".\$VenvName\Scripts\python.exe" -m pip install -r $RequirementsPath -q
    Write-Host "[$repo] Fertig. Aktivieren mit: .\$VenvName\Scripts\Activate.ps1" -ForegroundColor Green
} else {
    Write-Host "[$repo] Keine src\requirements.txt gefunden - $VenvName angelegt, aber leer." -ForegroundColor Yellow
}
