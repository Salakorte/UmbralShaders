"""Build a reproducible installable ZIP; no game files or tool dependencies."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    inputs = [ROOT / name for name in ('README.md', 'LICENSE', 'CHANGELOG.md')]
    inputs += sorted((ROOT / 'shaders').rglob('*'))
    inputs += sorted((ROOT / 'docs').glob('*.md'))
    report = ROOT / 'build' / 'validation.json'
    if not report.exists():
        raise RuntimeError('Run tools/validate.py first (or --static-only).')
    validation = json.loads(report.read_text(encoding='utf-8'))
    if validation.get('glsl_driver_validation') == 'failed or unavailable':
        raise RuntimeError('Validation failed. Resolve the error before packaging.')
    payload = {p.relative_to(ROOT).as_posix(): p.read_bytes()
               for p in inputs if p.is_file()}
    payload['validation.json'] = report.read_bytes()
    assert 'shaders/shaders.properties' in payload
    assert 'shaders/gbuffers_terrain.fsh' in payload
    assert 'shaders/shadow.vsh' in payload
    assert 'shaders/no_sun/final.fsh' in payload
    assert not any('..' in Path(n).parts or n.startswith('/') for n in payload)
    assert not any(n.endswith(('.jar', '.exe', '.dll')) for n in payload)
    output = ROOT / 'dist' / 'UmbralShaders-v0.12.1.zip'
    output.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(payload.items()):
            info = zipfile.ZipInfo(name, date_time=(2026, 11, 21, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data)
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None
        assert set(archive.namelist()) == set(payload)
        for name, data in payload.items():
            assert archive.read(name) == data, name
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix('.zip.sha256').write_text(f'{digest}  {output.name}\n', encoding='ascii')
    print(json.dumps({'zip': str(output), 'files': len(payload),
                      'bytes': output.stat().st_size, 'sha256': digest}, indent=2))


if __name__ == '__main__':
    main()
