# Dokumentation Technik

## Projektaufbau

- `src/main.py`: Python-Launcher, startet das PowerShell-GUI-Skript.
- `src/AP1-Begleiter-Portable-starten.ps1`: GUI-Logik und Browser-/Fenstersteuerung.
- `src/AP1-Begleiter-Portable.spec`: PyInstaller-Konfiguration.
- `src/build.ps1`: Build- und Release-Automatisierung.
- `src/publish_release_core.ps1`: Build + Commit + Push + Tag + GitHub-Release in einem Lauf.
- `.github/workflows/release.yml`: prüft Pull Requests, baut und archiviert Artefakte, aktualisiert Versionsangaben und veröffentlicht Releases bei `main`-Pushes oder Versionstags.
- `src/setup.ps1`: venv-Setup und Abhängigkeitsinstallation.
- `src/version_info.txt`: sichtbare App-Version (z. B. `v1.0.0`).
- `src/build_version_info.txt`: Windows-Dateiversionsinformationen für die EXE.
- `src/requirements.txt`: Python-Abhängigkeiten für Setup/Build.

## Build

Der Build erfolgt über `src/build.ps1` und erzeugt:

- `dist/AP1-Begleiter-Portable_vX.Y.Z.exe`
- `release/AP1-Begleiter-Portable_vX.Y.Z/`
- `release/AP1-Begleiter-Portable_vX.Y.Z.zip`
- `release/RELEASE_NOTES_vX.Y.Z.md` wird (falls vorhanden) ins Release-Paket kopiert.

Veröffentlichung auf GitHub erfolgt über `src/publish_release_core.ps1`.

- Standard: Build, Commit (falls Änderungen), Push, Tag, GitHub-Release.
- Optional: `-SkipBuild`, `-Version vX.Y.Z`, `-Draft`, `-PreRelease`.
- Detaillierte Checkliste: `docs/RELEASE_PROZESS.md`.

Vor dem eigentlichen Build prüft das Skript verbindlich:

- `README.md` muss im Projektwurzelverzeichnis liegen.
- `docs/DOKUMENTATION_ANWENDER.md` und `docs/DOKUMENTATION_TECHNIK.md` müssen exakt in dieser Großschreibung vorhanden sein.
- Gemischte/kleine Varianten (z. B. `docs/Dokumentation_Anwender.md`) führen zum Abbruch.

## Versionierung

- Laufzeitversion kommt aus `src/version_info.txt`.
- EXE-Metadaten kommen aus `src/build_version_info.txt`.
- Aktueller Stand: `v1.0.4`.


