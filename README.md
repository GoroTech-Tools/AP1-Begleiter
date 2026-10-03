# AP1-Begleiter

Version: `v1.0.3`

## Kurzüberblick

Portable Anwendung zum parallelen Öffnen und Anordnen zweier Browserfenster (Anleitung + Intranet).

## Dokumentation

- `docs/KURZDOKUMENTATION.txt`
- `docs/DOKUMENTATION_ANWENDER.md`
- `docs/DOKUMENTATION_TECHNIK.md`
- `docs/RELEASE_PROZESS.md`
- [Aktuelles GitHub-Release](https://github.com/GoroTech-Tools/AP1-Begleiter/releases/latest)

## Release-Publishing

- Für Build + GitHub-Release in einem Lauf: `src/publish_release.ps1`
- Technische Kernroutine: `src/publish_release_core.ps1`
- Pushes nach `main` erstellen automatisch ein Release mit erhöhter Patch-Version.
- `vX.Y.Z`-Tags veröffentlichen die zugehörigen Release Notes; Pull Requests prüfen den Build.
- Der Workflow `.github/workflows/release.yml` kann außerdem manuell gestartet werden.

## Markdown-Regel (verbindlich)

Um MD022/MD032 dauerhaft zu vermeiden, gilt in diesem Projekt:

- Vor **und** nach jeder Überschrift (`#`, `##`, ...) steht genau eine Leerzeile.
- Listen (`-`, `1.`) werden immer von Leerzeilen umgeben.

