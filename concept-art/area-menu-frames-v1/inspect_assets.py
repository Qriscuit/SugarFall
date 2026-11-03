"""Read native pixels and configure engine imports; never edit an image."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
manifest = json.loads((HERE / 'sources.json').read_text(encoding='utf-8'))
jam = json.loads((HERE / 'jam-donut-source.json').read_text(encoding='utf-8'))
entries = manifest['assets'] + [dict(jam, area='jam', runtime='PLINKO/data/art/bakery_ability/jam_donut.png')]
results = []
for entry in entries:
    path = ROOT / entry['runtime']
    raw = path.read_bytes()
    source = Path(entry['source'])
    assert raw == source.read_bytes(), 'Native image pixels changed'
    im = Image.open(path)
    assert im.mode == 'RGBA'
    alpha = im.getchannel('A')
    assert alpha.getextrema() == (0,255)
    solid = alpha.point(lambda v: 255 if v >= 128 else 0).getbbox()
    counts = alpha.histogram()
    assert counts[0] > 0 and counts[255] > 0
    item = {'area':entry['area'],'path':entry['runtime'],'sha256':hashlib.sha256(raw).hexdigest(),
        'bytes':len(raw),'size':im.size,'mode':im.mode,'alpha_range':alpha.getextrema(),
        'transparent_pixels':counts[0],'opaque_pixels':counts[255],
        'content_bounds_alpha128':solid,'native_unchanged':True}
    results.append(item)
    # Godot performs mipmapping and size limiting; the native PNG stays intact.
    limit = 256 if entry['area']=='jam' else 1024
    config = '[params]\ncompress/mode=0\nmipmaps/generate=true\nprocess/fix_alpha_border=true\nprocess/size_limit='+str(limit)+'\n'
    import_path = path.with_suffix('.png.import')
    if not import_path.exists(): import_path.write_text(config,encoding='utf-8')
(HERE/'native-validation.json').write_text(json.dumps({'passed':len(results)*4,'failed':0,'checks':'Each of four assets: unchanged native bytes, RGBA, true transparent and opaque pixels, readable authored content bounds. No pixel editing performed.','assets':results},indent=2)+'\n',encoding='utf-8')
print(json.dumps(results,indent=2))
