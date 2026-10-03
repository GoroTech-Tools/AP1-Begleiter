# Release Notes v1.0.1

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

## Ergebnis

- Build über `src/build.ps1` erfolgreich.
- Release-Artefakte erstellt:
  - `dist/AP1-Begleiter-Portable.exe`
  - `release/AP1-Begleiter-Portable/`
  - `release/AP1-Begleiter-Portable.zip`
