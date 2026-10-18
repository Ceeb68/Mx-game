"""Package the fingerprinted tire/crash-contact test, preserving older builds."""
from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parents[1]
PREFIX='TerraMX-v3.5-contact-test'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    manifest=json.loads((ROOT/'docs/contact/BUILD.json').read_text())
    for name,expected in manifest['source_sha256'].items():assert sha(ROOT/name)==expected,name
    exe=ROOT/'build/windows/TerraMX.exe'
    assert sha(exe)==manifest['executable_sha256']['windows']
    windows=ROOT/'build'/f'{PREFIX}-windows.zip'
    with zipfile.ZipFile(windows,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        z.write(exe,'TerraMX.exe');z.write(ROOT/'README.md','README.md')
        for p in sorted((ROOT/'docs/contact').rglob('*')):
            if p.is_file():z.write(p,p.relative_to(ROOT))
        z.writestr('START_HERE.txt','''Terra MX 3.5 TIRE / CRASH CONTACT TEST

Windows: extract everything and run TerraMX.exe.
Godot: use TerraMX-v3.5-contact-test-GODOT-SOURCE.zip instead. Extract,
import its root project.godot in Godot 4.6.3 standard, wait for import,
then press F5. The Windows game ZIP cannot be imported in Godot.
F1 identity: ReducedCoordinateMotorcycle/v3.5-contact.

This is a targeted fallen-contact repair, not completion of all handling work.
Native handlebar/footpeg contacts and passive post-crash steering replace the
old central-box-only support and active balancing after a fall. Tire friction,
normal steering gains, rider, track and bindings remain unchanged.
Read docs/contact/REPORT.md for measurements and inherited failures.
Slow banked stalls, bump corrections and whoops remain unresolved. Actual
Windows execution and human/gamepad riding need your test.

W throttle, S front brake, Space rear brake, A/D steer, Q/E rider lean,
arrow keys fore/aft weight, Tab sit/stand, R local reset, C camera,
F6 next lane, Escape settings, F1 diagnostics. Saved bindings persist.
''')
    source=ROOT/'build'/f'{PREFIX}-GODOT-SOURCE.zip'
    with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in sorted(ROOT.rglob('*')):
            relative=p.relative_to(ROOT)
            if set(relative.parts)&{'.git','.godot','build','__pycache__'}:continue
            if p.is_file():z.write(p,relative)
    outputs=[source,windows]
    (ROOT/'build/SHA256SUMS-v3.5-contact-test.txt').write_text(''.join(f'{sha(p)}  {p.name}\n' for p in outputs))
    for p in outputs:
        assert p.stat().st_size<100*1024*1024,p
        with zipfile.ZipFile(p) as z:assert z.testzip() is None
        print(p.name,p.stat().st_size,sha(p))
if __name__=='__main__':main()
