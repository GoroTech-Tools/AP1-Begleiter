"""
AP1-Begleiter-Portable – Python-Launcher
Startet das eingebettete PowerShell-GUI-Skript als separaten Prozess.
"""

import ctypes
import os
import subprocess
import sys


DEFAULT_APP_VERSION = "v1.0.5"


def get_base_dir() -> str:
    """Liefert das Basisverzeichnis, in PyInstaller-EXEs den _MEIPASS-Pfad."""
    if getattr(sys, "frozen", False):
        return getattr(sys, "_MEIPASS", os.path.dirname(sys.executable))
    return os.path.dirname(os.path.abspath(__file__))


def show_error(message: str) -> None:
    ctypes.windll.user32.MessageBoxW(
        0,
        message,
        "AP1-Begleiter-Portable – Fehler",
        0x10,  # MB_ICONERROR
    )


def load_app_version(base_dir: str) -> str:
    """Lädt die App-Version aus version_info.txt (Fallback: DEFAULT_APP_VERSION)."""
    version_file = os.path.join(base_dir, "version_info.txt")
    try:
        with open(version_file, "r", encoding="utf-8") as f:
            raw = f.read().strip()
        return raw if raw else DEFAULT_APP_VERSION
    except OSError:
        return DEFAULT_APP_VERSION


def main() -> None:
    base_dir = get_base_dir()
    app_version = load_app_version(base_dir)
    ps1_path = os.path.join(base_dir, "AP1-Begleiter-Portable-starten.ps1")
    doc_path = os.path.join(base_dir, "KURZDOKUMENTATION.txt")
    icon_path = os.path.join(base_dir, "app_icon.ico")

    if not os.path.isfile(ps1_path):
        show_error(f"Skriptdatei nicht gefunden:\n{ps1_path}")
        sys.exit(1)

    ps_command = (
        "& { "
        "param([string]$p, [string]$d, [string]$i, [string]$v) "
        "$script:BundledDocPath = $d; "
        "$script:BundledIconPath = $i; "
        "$script:AppVersion = $v; "
        "$scriptText = Get-Content -Raw -Encoding UTF8 -LiteralPath $p; "
        "& ([ScriptBlock]::Create($scriptText)) "
        "}"
    )

    result = subprocess.run(
        [
            "powershell.exe",
            "-ExecutionPolicy", "Bypass",
            "-NonInteractive",
            "-WindowStyle", "Hidden",
            "-Command", ps_command,
            ps1_path,
            doc_path,
            icon_path,
            app_version,
        ],
        creationflags=subprocess.CREATE_NO_WINDOW,
    )

    sys.exit(result.returncode)


if __name__ == "__main__":
    main()



