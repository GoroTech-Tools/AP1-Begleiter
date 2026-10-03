# Release-Prozess

## Versionierung

- Dateiführend: `src/version_info.txt` (z. B. `v1.0.1`)
- EXE-Metadaten: `src/build_version_info.txt` (z. B. `1.0.1`)
- Beide Angaben müssen inhaltlich zusammenpassen.

## Release-Checkliste

1. Versionsstand prüfen:
   - `src/version_info.txt`
   - `src/build_version_info.txt`
2. Dokumentation prüfen:
   - `README.md` im Projektwurzelverzeichnis
   - `docs/DOKUMENTATION_ANWENDER.md`
   - `docs/DOKUMENTATION_TECHNIK.md`
   - `docs/KURZDOKUMENTATION.txt`
3. Build ausführen (`src/build.ps1`).
4. Artefakte kurz validieren:
   - `dist/AP1-Begleiter-Portable_vX.Y.Z.exe`
   - `release/AP1-Begleiter-Portable_vX.Y.Z/`
   - `release/AP1-Begleiter-Portable_vX.Y.Z.zip`
5. Release Notes bereitstellen:
   - `release/RELEASE_NOTES_vX.Y.Z.md`
6. Veröffentlichung ausführen:
   - `src/publish_release.ps1`
7. GitHub prüfen:
   - Tag sichtbar (`vX.Y.Z`)
   - Release vorhanden
   - ZIP-Asset vorhanden

## Standardablauf (empfohlen)

1. Versionsstand, Dokumentation und Release Notes vorbereiten.
2. Einen Tag im Format `vX.Y.Z` pushen.
3. Der Workflow `.github/workflows/release.yml` aktualisiert die Versionsangaben, baut das Paket und veröffentlicht das GitHub-Release als `latest`.
4. Ergebnis und ZIP-Artefakt in GitHub Releases prüfen.

Für lokale Veröffentlichungen kann weiterhin `src/publish_release.ps1` verwendet werden.

## Hinweise

- Wenn ein Tag bereits existiert (z. B. `v1.0.1`), aktualisiert die Publish-Routine das bestehende Release und lädt das ZIP-Asset erneut hoch.
- Die Build-Routine prüft die Doku-Namenskonvention verbindlich (README im Root, Doku-Dateien in Großschreibung).
