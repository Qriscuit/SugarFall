"""Bundle and verify the eight exact local-delivery images. No image editing."""
import hashlib
import json
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'outputs/storefront-20261105'
manifest = json.loads((OUT / 'manifest.json').read_text())
shots = json.loads((OUT / 'screenshots/screenshots-validation.json').read_text())
assert shots['structural_passed'] and shots['visual_passed'] and shots['passed']
for asset in [manifest['banner'], *manifest['screenshots']]:
    assert hashlib.sha256((OUT / asset['file']).read_bytes()).hexdigest() == asset['sha256']
for name in ['independent-screenshots-review.json', 'independent-banner-review.json']:
    assert json.loads((OUT / 'qa' / name).read_text())['status'] == 'passed'
files = [manifest['banner']['file'], *[s['file'] for s in manifest['screenshots']],
         'README.txt', 'review.html', 'manifest.json', *manifest['evidence']]
target = OUT / 'Sugarfall-Store-Assets-20261105.zip'
with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for name in files:
        archive.write(OUT / name, name)
with zipfile.ZipFile(target) as archive:
    assert archive.testzip() is None
    assert set(archive.namelist()) == set(files)
    assert len([p for p in archive.namelist() if p.endswith('.png')]) == 8
    for name in files:
        assert archive.read(name) == (OUT / name).read_bytes()
report = dict(passed=True, date='2026-11-05', file=target.name, bytes=target.stat().st_size,
              sha256=hashlib.sha256(target.read_bytes()).hexdigest(), image_count=8,
              entry_count=len(files), entries_byte_identical=True, crc_passed=True)
(OUT / 'qa/bundle-validation.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
