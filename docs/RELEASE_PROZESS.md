# Release-Prozess

## Versionierung

- Dateiführend: `src/version_info.txt` (z. B. `v1.0.1`)
- EXE-Metadaten: `src/build_version_info.txt` (z. B. `1.0.1`)
- Beide Angaben müssen inhaltlich zusammenpassen.

## Release-Checkliste

1. Dokumentation prüfen:
   - `README.md` im Projektwurzelverzeichnis
   - `docs/DOKUMENTATION_ANWENDER.md`
   - `docs/DOKUMENTATION_TECHNIK.md`
   - `docs/KURZDOKUMENTATION.txt`
2. Für ein versioniertes Release Release Notes bereitstellen:
   - `release/RELEASE_NOTES_vX.Y.Z.md`
   - Bei Tag-Releases ergänzt der Workflow den Download-Bereich.
3. Für lokale Builds `src/build.ps1` ausführen.
4. Artefakte kurz validieren:
   - `dist/AP1-Begleiter-Portable_vX.Y.Z.exe`
   - `release/AP1-Begleiter-Portable_vX.Y.Z/`
   - `release/AP1-Begleiter-Portable_vX.Y.Z.zip`
5. Für eine lokale Veröffentlichung `src/publish_release.ps1` verwenden.
6. GitHub prüfen:
   - Tag sichtbar (`vX.Y.Z`)
   - Release vorhanden
   - ZIP-Asset vorhanden

## Automatisierter Ablauf

1. Ein Push nach `main` startet den Windows-Build. Der Workflow erhöht die Patch-Version anhand der höchsten vorhandenen Versionsnummer, aktualisiert die Versionsreferenzen und Dokumentation, erstellt das Paket und veröffentlicht ein GitHub-Release als `latest`.
2. Ein Push eines Tags im Format `vX.Y.Z` startet denselben Build mit der Tag-Version. Dafür müssen passende Release Notes vorhanden sein; der Workflow ergänzt den Download-Bereich und veröffentlicht die Notizen samt ZIP als `latest`.
3. Pull Requests gegen `main` führen den Build zur Validierung aus, veröffentlichen aber kein Release.
4. Der Workflow kann außerdem über GitHub Actions manuell gestartet werden. Ein Lauf auf `main` veröffentlicht ein Release.
5. Der Build und das Release-Publishing laufen in getrennten Jobs. Das ZIP und bei Tag-Releases die Release Notes werden zwischen den Jobs als Actions-Artefakte übertragen.
6. Versionsangaben in `src/version_info.txt`, `src/build_version_info.txt`, `src/main.py`, `src/AP1-Begleiter-Portable-starten.ps1`, `README.md` und `docs/DOKUMENTATION_TECHNIK.md` werden aktualisiert und nach `main` übertragen.

Für lokale Veröffentlichungen kann weiterhin `src/publish_release.ps1` verwendet werden.

## Hinweise

- Wenn ein Tag bereits existiert (z. B. `v1.0.1`), aktualisiert die Publish-Routine das bestehende Release und lädt das ZIP-Asset erneut hoch.
- Die Build-Routine prüft die Doku-Namenskonvention verbindlich (README im Root, Doku-Dateien in Großschreibung).
