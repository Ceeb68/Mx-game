"""Package the fingerprinted v3.2 steering test; preserve every previous build."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PREFIX = 'TerraMX-v3.2-steering'

def digest(data):
    return hashlib.sha256(data).hexdigest()

def main():
    manifest = json.loads((ROOT / 'docs/refinement/BUILD.json').read_text())
    for name, expected in manifest['source_sha256'].items():
        assert digest((ROOT / name).read_bytes()) == expected, name
    exe = ROOT / 'build/windows/TerraMX.exe'
    assert digest(exe.read_bytes()) == manifest['executable_sha256']['windows']
    windows = ROOT / 'build' / f'{PREFIX}-windows.zip'
    with zipfile.ZipFile(windows, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        archive.write(exe, 'TerraMX.exe')
        archive.write(ROOT / 'README.md', 'README.md')
        for p in sorted((ROOT / 'docs').rglob('*')):
            if p.is_file(): archive.write(p, p.relative_to(ROOT))
        archive.writestr('START_HERE.txt', '''Terra MX 3.2 - STEERING TEST UPDATE

Extract all files and run TerraMX.exe. This standalone ZIP is not a Godot project.
For Godot use TerraMX-v3.2-steering-source.zip, extract, import project.godot
in Godot 4.6.3 standard and press F5.

F1 identity: ReducedCoordinateMotorcycle/v3.2-steering.
Read docs/refinement/REPORT.md for changes, tradeoffs and manual tests.
Existing bindings/profile settings are preserved. To try the new input default,
set steering smoothing to 0.06 seconds in Settings (curve remains 1.35).
For a matched-settings comparison with v3.1, use 0.10 smoothing in both.
Steering assist should be enabled for the virtual-rider comparison.

W throttle, S front brake, Space rear brake, A/D steer, Q/E rider lean,
arrow keys fore/aft weight, Tab sit/stand, R reset, C camera, F6 lane,
Escape settings. Preserve the old v3.1 ZIP in a separate folder.

This is the first staged v3.2 update. Suspension bounce and airborne whip
changes are pending. Automated tests do not establish realistic riding feel.
Windows execution and physical gamepad feel require testing on your machine.
''')
    source = ROOT / 'build' / f'{PREFIX}-source.zip'
    with zipfile.ZipFile(source, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for p in sorted(ROOT.rglob('*')):
            relative = p.relative_to(ROOT)
            if set(relative.parts) & {'.git', '.godot', 'build', '__pycache__'}: continue
            if p.is_file(): archive.write(p, relative)
    outputs = [windows, source]
    (ROOT / 'build/SHA256SUMS-v3.2-steering.txt').write_text(''.join(
        f'{digest(p.read_bytes())}  {p.name}\n' for p in outputs))
    for p in outputs:
        with zipfile.ZipFile(p) as archive: assert archive.testzip() is None
        print(p.name, p.stat().st_size, digest(p.read_bytes()))

if __name__ == '__main__': main()
