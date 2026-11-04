"""Check delivery formats and transparent margins; does not alter artwork."""
from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET
from PIL import Image

base = Path(__file__).resolve().parent
records=[]
for path in sorted(base.glob('*.svg')):
    text=path.read_text(encoding='utf-8')
    element=ET.fromstring(text)
    tags=[node.tag.rsplit('}',1)[-1] for node in element.iter()]
    assert not any(tag in tags for tag in ['image','script','foreignObject']),path.name
    assert 'data:image' not in text
    for node in element.iter():
        for attr,value in node.attrib.items():
            if attr.rsplit('}',1)[-1]=='href':
                assert value.startswith('#'),(path.name,value)
    ids=[node.attrib['id'] for node in element.iter() if 'id' in node.attrib]
    assert len(ids)==len(set(ids)),path.name
    png=path.with_suffix('.png')
    expected=(140,110) if path.name=='doughnut-prop.svg' else (600,1000)
    with Image.open(png) as image:
        assert image.mode=='RGBA' and image.size==expected,(png.name,image.mode,image.size)
        alpha=image.getchannel('A')
        assert alpha.getextrema()==(0,255)
        box=alpha.getbbox()
        assert box and box[0]>0 and box[1]>0 and box[2]<expected[0] and box[3]<expected[1],(png.name,box)
        for point in [(0,0),(expected[0]-1,0),(0,expected[1]-1),(expected[0]-1,expected[1]-1)]:
            assert alpha.getpixel(point)==0
    digest=lambda file:hashlib.sha256(file.read_bytes()).hexdigest()
    records.append(dict(svg=path.name,png=png.name,width=expected[0],height=expected[1],
                        alpha_bounds=list(box),vector_elements=len(tags),
                        svg_sha256=digest(path),png_sha256=digest(png)))
assert len(records)==8
result=dict(passed=True,date='2026-11-04',vector_svg_files=len(records),
            embedded_rasters=0,external_svg_resources=0,transparent_pngs=len(records),
            all_art_within_canvas=True,artwork='Original authored vector paths/shapes/gradients',
            assets=records)
(base/'asset-manifest.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(passed=True,svg_files=len(records),transparent_pngs=len(records),bounds=[r['alpha_bounds'] for r in records]),indent=2))
