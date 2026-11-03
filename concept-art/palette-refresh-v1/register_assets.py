"""Record untouched imagegen assets; update texture import and source bounds only."""
from pathlib import Path
import json, hashlib, re
from PIL import Image
import numpy as np

HERE = Path(__file__).resolve().parent
WORKSPACE = HERE.parents[1]
manifest = json.loads((HERE / 'sources.json').read_text())
for entry in manifest['assets']:
    path = WORKSPACE / entry['destination']
    source = Path(entry['source'])
    entry['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    assert entry['sha256'] == hashlib.sha256(source.read_bytes()).hexdigest(), path
    entry['reference_backup'] = f"references/{entry['id']}/input.png"
    with Image.open(path) as picture:
        entry['size'] = list(picture.size)
        entry['mode'] = picture.mode
        if entry['transparent_background']:
            assert picture.mode == 'RGBA'
            alpha = np.asarray(picture.getchannel('A'))
            assert (alpha == 0).sum() > 100
            ys, xs = np.where(alpha >= 128)
            width, height = picture.size
            x0, y0 = max(0, int(xs.min())-4), max(0, int(ys.min())-4)
            x1, y1 = min(width, int(xs.max())+5), min(height, int(ys.max())+5)
            frame = [x0/width, y0/height, (x1-x0)/width, (y1-y0)/height]
            entry['source_bounds'] = frame
            regions_file = path.parent / 'regions.json'
            regions = json.loads(regions_file.read_text())
            regions[path.stem] = frame
            regions_file.write_text(json.dumps(regions, indent=2)+'\n')
        if path.stem == 'upgrade_arc_v3':
            old_path = path.with_name('upgrade_arc_v2.png.import')
            settings = old_path.read_text()
            settings = re.sub(r'^uid=.*\n', '', settings, flags=re.M)
            resource = 'res://' + path.relative_to(WORKSPACE/'PLINKO').as_posix()
            digest = hashlib.md5(resource.encode()).hexdigest()
            settings = re.sub(r'upgrade_arc_v2.png-[a-f0-9]+', 'upgrade_arc_v3.png-'+digest, settings)
            settings = settings.replace('upgrade_arc_v2.png', 'upgrade_arc_v3.png')
            path.with_suffix('.png.import').write_text(settings)
    print(entry['id'], entry['size'], entry['mode'], 'pixels verified')

manifest['aliases'] = [
    {'source':'PLINKO/data/art/environment/play_counter.png','destination':'PLINKO/data/art/food/countertop.png'},
    {'source':'PLINKO/data/art/gelato/environment/play_counter.png','destination':'PLINKO/data/art/gelato/food/countertop.png'}
]
(HERE/'sources.json').write_text(json.dumps(manifest, indent=2)+'\n')
for folder in ['PLINKO/data/art/environment','PLINKO/data/art/gelato/environment','PLINKO/data/art/food','PLINKO/data/art/gelato/food']:
    subset = [e for e in manifest['assets'] if str(Path(e['destination']).parent).replace('\\','/') == folder]
    record = {'method':manifest['method'],'record':'concept-art/palette-refresh-v1/sources.json','assets':subset}
    (WORKSPACE/folder/'palette-refresh-sources.json').write_text(json.dumps(record,indent=2)+'\n')
