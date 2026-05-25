# -*- mode: python ; coding: utf-8 -*-

import os

try:
    SPEC_DIR = os.path.abspath(os.path.dirname(__file__))
except NameError:
    # In manchen PyInstaller-Kontexten ist __file__ in Spec-Dateien nicht gesetzt.
    SPEC_DIR = os.path.abspath(os.path.join(os.getcwd(), 'src'))

PROJECT_ROOT = os.path.abspath(os.path.join(SPEC_DIR, ".."))

a = Analysis(
    [os.path.join(SPEC_DIR, 'main.py')],
    pathex=[SPEC_DIR],
    binaries=[],
    datas=[
        (os.path.join(SPEC_DIR, 'AP1-Begleiter-Portable-starten.ps1'), '.'),
        (os.path.join(PROJECT_ROOT, 'docs', 'KURZDOKUMENTATION.txt'), '.'),
        (os.path.join(SPEC_DIR, 'version_info.txt'), '.'),
        (os.path.join(SPEC_DIR, 'app_icon.ico'), '.'),
    ],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='AP1-Begleiter-Portable',
    icon=os.path.join(SPEC_DIR, 'app_icon.ico'),
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    version=os.path.join(SPEC_DIR, 'build_version_info.txt'),
)
