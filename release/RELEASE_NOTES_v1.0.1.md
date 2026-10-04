# Release Notes v1.0.1

Datum: 2026-05-25

## Download

- [Release-Seite v1.0.1](https://github.com/GoroTech-Tools/AP1-Begleiter/releases/tag/v1.0.1)
- [ZIP direkt herunterladen](https://github.com/GoroTech-Tools/AP1-Begleiter/releases/download/v1.0.1/AP1-Begleiter-Portable_v1.0.1.zip)

## Änderungen

- Build-/Setup-/Spec-/Startskript wurden in `src/` zentralisiert.
- Verbliebene TXT-Dateien wurden nach `src/` verschoben:

  - `src/requirements.txt`
  - `src/version_info.txt`
  - `src/build_version_info.txt`

- Pfadlogik in `src/setup.ps1` und `src/AP1-Begleiter-Portable.spec` auf neue Struktur angepasst.
- Versionsstand auf `v1.0.1` angehoben (inkl. EXE-Metadaten `1.0.1`).

## Qualitätsstatus

- Release-Build über `src/build.ps1` erfolgreich.
- Release-Verzeichnis und ZIP-Artefakt erstellt.

## Artefakte

- Release-Verzeichnis: `release/AP1-Begleiter-Portable/`
- EXE: `dist/AP1-Begleiter-Portable.exe`
- Release-ZIP: `release/AP1-Begleiter-Portable.zip`

## Enthaltene Commits (aktuelle Historie)

- `93024f8` Release v1.0.1: src-layout, versioned artifacts, docs rules

## Technische Build-Informationen

- Build-Datum: nicht überliefert
- Build-Modus: nicht überliefert
- EXE-Name: `AP1-Begleiter-Portable.exe`
