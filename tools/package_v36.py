"""Package the reviewed Stage A candidate. Bulk replay traces stay in Git."""
from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parents[1]
PREFIX='TerraMX-v3.6-traction-stage-A'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def include(p):
    rel=p.relative_to(ROOT)
    return p.is_file() and not (set(rel.parts)&{'.git','.godot','build','__pycache__'}) and not p.name.endswith(('.json.gz','.log'))
def main():
    manifest=json.loads((ROOT/'docs/refinement-v36/BUILD.json').read_text())
    for name,expected in manifest['source_sha256'].items():assert sha(ROOT/name)==expected,name
    assert sha(ROOT/'build/windows/TerraMX.exe')==manifest['executable_sha256']['windows']
    start='''Terra MX 3.6 - STAGE A TRACTION TEST

Windows: extract the WINDOWS ZIP completely, run TerraMX.exe.
Godot: extract the GODOT-SOURCE ZIP, import the root project.godot in
Godot 4.6.3 standard, wait for import and press F5. The Windows ZIP
is a standalone game and cannot be imported as a Godot project.
F1: ReducedCoordinateMotorcycle/v3.6-traction-stage-A.

Finite-brake/locked-tread traction correction; v3.5 suspension retained.
Excessive bounce and four known ground failures remain unresolved.
The suspension experiments were rejected after rough-ground regressions.
See docs/refinement-v36/REPORT.md. Human riding and Windows execution
still require your test. Automated tests do not prove realistic handling.

W throttle, S front brake, Space rear brake, A/D steer, Q/E rider lean,
arrow keys fore/aft weight, Tab sit/stand, R local reset, C camera,
F6 next lane, Escape settings, F1 diagnostics. Saved bindings persist.
Keep v3.5 separately and compare identical controls/assists/settings.

All runtime source/assets/config/tests are in the GODOT-SOURCE ZIP.
Optional historical bulk .json.gz telemetry is omitted from both ZIPs;
full traces are retained in the repository on refinement/v3.6-traction-suspension.
'''
    outputs=[]
    for kind in ['windows','GODOT-SOURCE']:
        target=ROOT/'build'/f'{PREFIX}-{kind}.zip'
        with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
            if kind=='windows':
                z.write(ROOT/'build/windows/TerraMX.exe','TerraMX.exe')
                paths=[ROOT/'README.md']+list((ROOT/'docs/refinement-v36').rglob('*'))
            else:paths=list(ROOT.rglob('*'))
            for p in sorted(paths):
                if include(p):z.write(p,p.relative_to(ROOT))
            z.writestr('START_HERE.txt',start)
        with zipfile.ZipFile(target) as z:
            assert z.testzip() is None
            assert ('project.godot' in z.namelist())==(kind=='GODOT-SOURCE')
        assert target.stat().st_size<100*1024*1024
        outputs.append(target);print(target.name,target.stat().st_size,sha(target))
    (ROOT/'build/SHA256SUMS-v3.6-traction-stage-A.txt').write_text(''.join(f'{sha(p)}  {p.name}\n' for p in outputs))
if __name__=='__main__':main()
