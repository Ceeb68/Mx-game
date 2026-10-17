"""Package the fingerprinted v3.3 landing/recovery stage, preserving older ZIPs."""
from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parents[1]
PREFIX='TerraMX-v3.3-landing'
def digest(data):return hashlib.sha256(data).hexdigest()
def main():
    manifest=json.loads((ROOT/'docs/landing/BUILD.json').read_text())
    for name,expected in manifest['source_sha256'].items():
        assert digest((ROOT/name).read_bytes())==expected,name
    exe=ROOT/'build/windows/TerraMX.exe'
    assert digest(exe.read_bytes())==manifest['executable_sha256']['windows']
    windows=ROOT/'build'/f'{PREFIX}-windows.zip'
    with zipfile.ZipFile(windows,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        archive.write(exe,'TerraMX.exe')
        archive.write(ROOT/'README.md','README.md')
        for p in sorted((ROOT/'docs').rglob('*')):
            if p.is_file():archive.write(p,p.relative_to(ROOT))
        archive.writestr('START_HERE.txt','''Terra MX 3.3 - LANDING / LOCAL RECOVERY TEST STAGE

Extract all files and run TerraMX.exe. F1 identity: v3.3-landing.
For Godot use TerraMX-v3.3-landing-source.zip, extract, import project.godot
in Godot 4.6.3 standard and press F5.

R resets near your current location or the most recent validated safe position.
F6 still switches to the next test lane's starting position.
Bindings and saved response settings are preserved. Ground steering gains and
tire friction are unchanged from v3.2. Keep the older ZIPs in separate folders.

This is the first staged v3.3 update: landing/crash recovery and local reset.
Braking bumps and whoops still expose failures. Improved whips are pending.
Read docs/landing/REPORT.md for exact changes, failed rough-terrain observations,
A/B measurements and manual testing instructions. Automated tests cannot
establish realistic riding feel. Windows execution/gamepad feel need your test.

W throttle, S front brake, Space rear brake, A/D steer, Q/E rider lean,
arrow keys fore/aft weight, Tab sit/stand, R reset, C camera, F6 lane,
Escape settings, F1 diagnostics.
''')
    source=ROOT/'build'/f'{PREFIX}-source.zip'
    with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for p in sorted(ROOT.rglob('*')):
            relative=p.relative_to(ROOT)
            if set(relative.parts)&{'.git','.godot','build','__pycache__'}:continue
            if p.is_file():archive.write(p,relative)
    outputs=[windows,source]
    (ROOT/'build/SHA256SUMS-v3.3-landing.txt').write_text(''.join(f'{digest(p.read_bytes())}  {p.name}\n' for p in outputs))
    for p in outputs:
        with zipfile.ZipFile(p) as archive:assert archive.testzip() is None
        print(p.name,p.stat().st_size,digest(p.read_bytes()))
if __name__=='__main__':main()
