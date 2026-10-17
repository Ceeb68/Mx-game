"""Package the explicitly incomplete grounded-handling experiment."""
from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parents[1]
PREFIX='TerraMX-v3.4-ground-EXPERIMENTAL'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    manifest=json.loads((ROOT/'docs/ground/BUILD.json').read_text())
    for name,expected in manifest['source_sha256'].items():assert sha(ROOT/name)==expected,name
    exe=ROOT/'build/windows/TerraMX.exe'
    assert sha(exe)==manifest['executable_sha256']['windows']
    windows=ROOT/'build'/f'{PREFIX}-windows.zip'
    with zipfile.ZipFile(windows,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        archive.write(exe,'TerraMX.exe')
        archive.write(ROOT/'README.md','README.md')
        for p in sorted((ROOT/'docs/ground').rglob('*')):
            if p.is_file():archive.write(p,p.relative_to(ROOT))
        archive.writestr('START_HERE.txt','''Terra MX 3.4 GROUND EXPERIMENT - INCOMPLETE REPAIR

Extract all files, then run TerraMX.exe on Windows.
For Godot, download TerraMX-v3.4-ground-EXPERIMENTAL-GODOT-SOURCE.zip.
Extract that SOURCE ZIP, import its project.godot in Godot 4.6.3 standard,
wait for import, then press F5. Do not import the Windows game ZIP.
F1 runtime identity: v3.4-ground-experimental.

Slow bank stalls, bump corrections and complete whoops still fail automated
replays. This is NOT the completed stable v3.4 requested update. The retained
change fixes the signed-velocity tire-force inverse; suspension, friction,
track, rider, inputs and local recovery remain as in v3.3.
Read docs/ground/REPORT.md for numbers, failures and rejected experiments.
Windows execution and riding/gamepad feel need actual human testing.

W throttle, S front brake, Space rear brake, A/D steer, Q/E rider lean,
arrow keys fore/aft weight, Tab sit/stand, R local reset, C camera,
F6 next lane, Escape settings, F1 diagnostics. Existing bindings persist.
''')
    source=ROOT/'build'/f'{PREFIX}-GODOT-SOURCE.zip'
    with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for p in sorted(ROOT.rglob('*')):
            relative=p.relative_to(ROOT)
            if set(relative.parts)&{'.git','.godot','build','__pycache__'}:continue
            if p.is_file():archive.write(p,relative)
    outputs=[source,windows]
    (ROOT/'build/SHA256SUMS-v3.4-ground-EXPERIMENTAL.txt').write_text(''.join(f'{sha(p)}  {p.name}\n' for p in outputs))
    for p in outputs:
        with zipfile.ZipFile(p) as archive:assert archive.testzip() is None
        print(p.name,p.stat().st_size,sha(p))
if __name__=='__main__':main()
