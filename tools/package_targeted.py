"""Package the tested 0.3.1 Windows export and source without replacing v3 ZIPs."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PREFIX = "TerraMX-targeted-v3.1"

def digest(data):
    return hashlib.sha256(data).hexdigest()

def main():
    manifest = json.loads((ROOT / "docs/targeted/BUILD.json").read_text())
    for name, expected in manifest["source_sha256"].items():
        assert digest((ROOT / name).read_bytes()) == expected, name
    exe = ROOT / "build/windows/TerraMX.exe"
    assert digest(exe.read_bytes()) == manifest["executable_sha256"]["windows"]
    target = ROOT / "build" / f"{PREFIX}-windows.zip"
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        archive.write(exe, "TerraMX.exe")
        archive.write(ROOT / "README.md", "README.md")
        for path in sorted((ROOT / "docs").rglob("*")):
            if path.is_file(): archive.write(path, path.relative_to(ROOT))
        archive.writestr("START_HERE.txt", "Terra MX 0.3.1 - TARGETED STEERING REPAIR\n\nExtract all files and run TerraMX.exe.\nF1 toggles diagnostics: ReducedCoordinateMotorcycle/v3.1-targeted.\nCompare against the preserved v3 ZIP in a separate folder, using identical\nsaved assist/response settings. Steering assistance should be on for the\nvirtual-rider comparison. Existing bindings and profiles are preserved.\nW throttle, S front brake, Space rear brake, A/D steering, R reset,\nTab sit/stand, C camera, F6 lane, Escape settings.\nRead docs/targeted/REPORT.md for numerical comparisons and limitations.\nThis is a focused test build. Human riding feel and Windows execution\nhave not been validated on the Linux build machine.\n")
    source = ROOT / "build" / f"{PREFIX}-source.zip"
    with zipfile.ZipFile(source, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(ROOT.rglob("*")):
            relative = path.relative_to(ROOT)
            if set(relative.parts) & {".git", ".godot", "build", "__pycache__"}: continue
            if path.is_file(): archive.write(path, relative)
    outputs = [target, source]
    (ROOT / "build/SHA256SUMS-targeted-v3.1.txt").write_text("".join(f"{digest(p.read_bytes())}  {p.name}\n" for p in outputs))
    for path in outputs:
        with zipfile.ZipFile(path) as archive: assert archive.testzip() is None
        print(path.name, path.stat().st_size, digest(path.read_bytes()))

if __name__ == "__main__": main()
