"""Package already-exported v3 binaries, documentation, source and checksums."""
from pathlib import Path
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
VERSION = "TerraMX-rebuild-v3"

def sha(path):
    return hashlib.file_digest(path.open("rb"), "sha256").hexdigest()

def main():
    outputs = []
    for platform, filename in [("windows", "TerraMX.exe"), ("linux", "TerraMX.x86_64")]:
        binary = BUILD / platform / filename
        if not binary.is_file():
            raise SystemExit(f"Export is missing: {binary}")
        target = BUILD / f"{VERSION}-{platform}.zip"
        with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            archive.write(binary, filename)
            archive.write(ROOT / "README.md", "README.md")
            for path in sorted((ROOT / "docs").rglob("*")):
                if path.is_file(): archive.write(path, path.relative_to(ROOT))
            archive.writestr("START_HERE.txt", f"Terra MX 0.3.0 - PHYSICS REPLACEMENT PROTOTYPE\n\nExtract all files, then run {filename}.\nThe debug display must say Godot Physics / ReducedCoordinateMotorcycle/v3.\nUse the comparison launcher for preserved MotorcycleSimulation/v2.\nKeyboard: W throttle, S front brake, Space rear brake, A/D steering,\nQ/E body lean, arrows body position, Tab sit/stand, R reset, C camera,\nF6 test lane, F1 telemetry, Escape settings and custom bindings.\nExisting saved controller mappings/response settings are retained.\nRead docs/PHYSICS_REBUILD.md and docs/VALIDATION.md for evidence and limits.\nThis is a reduced-coordinate prototype with estimated tire parameters.\nHuman riding feel and Windows execution have not been verified here.\n")
            if platform == "windows":
                archive.writestr("Compare-legacy.bat", '@echo off\r\ncd /d "%~dp0"\r\nstart "Terra MX - preserved v2" "%~dp0TerraMX.exe" -- --legacy\r\n')
            else:
                info = zipfile.ZipInfo("Compare-legacy.sh")
                info.external_attr = 0o100755 << 16
                archive.writestr(info, '#!/usr/bin/env sh\ncd -- "$(dirname -- "$0")"\nexec ./TerraMX.x86_64 -- --legacy\n')
        outputs.append(target)
    target = BUILD / f"{VERSION}-source.zip"
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(ROOT.rglob("*")):
            relative = path.relative_to(ROOT)
            if set(relative.parts) & {".git", ".godot", "build", "__pycache__"}: continue
            if path.is_file() and path.suffix != ".log": archive.write(path, relative)
            elif relative == Path("docs/validation.log"): archive.write(path, relative)
    outputs.append(target)
    checksum_file = BUILD / "SHA256SUMS-rebuild-v3.txt"
    checksum_file.write_text("".join(f"{sha(path)}  {path.name}\n" for path in outputs))
    for path in outputs:
        with zipfile.ZipFile(path) as archive:
            assert archive.testzip() is None, path
        print(f"PACKAGE {path.name} bytes={path.stat().st_size} sha256={sha(path)}")

if __name__ == "__main__": main()
