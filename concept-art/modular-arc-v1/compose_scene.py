"""Assemble untouched transparent sprites as authored native scene layers.

This writes placement/import metadata only. It never edits raster pixels.
"""
from pathlib import Path
import hashlib, json, math, re
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
WORKSPACE = HERE.parents[1]
PROJECT = WORKSPACE / 'PLINKO'
manifest = json.loads((HERE/'sources.json').read_text())
assets = {}
shadows = {
    'bakery_house':[.13,.82,.74,.12], 'bakery_mill':[.22,.84,.66,.11],
    'greenhouse':[.16,.84,.71,.12], 'gelato_house':[.18,.84,.66,.11],
    'gelato_pavilion':[.18,.84,.67,.11], 'oak_tree':[.31,.86,.39,.09],
    'lilac_tree':[.35,.88,.33,.08], 'flower_planter':[.17,.78,.70,.10],
    'garden_bench':[.15,.85,.71,.10]
}
for entry in manifest['assets']:
    path = WORKSPACE / entry['destination']
    entry['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    assert entry['sha256'] == hashlib.sha256(Path(entry['source']).read_bytes()).hexdigest()
    with Image.open(path) as picture:
        assert picture.mode == 'RGBA'
        alpha = np.asarray(picture.getchannel('A'))
        assert (alpha == 0).sum() > 10000
        entry['size'] = list(picture.size)
        entry['mode'] = picture.mode
        entry['transparent_fraction'] = round(float((alpha == 0).mean()),4)
    resource = 'res://' + path.relative_to(PROJECT).as_posix()
    assets[entry['id']] = {'texture':resource, 'shadow_rect':shadows[entry['id']]}
    template = (PROJECT/'data/art/environment/upgrade_arc_v3.png.import').read_text()
    template = re.sub(r'^uid=.*\n','',template,flags=re.M)
    imported = path.name+'-'+hashlib.md5(resource.encode()).hexdigest()+'.ctex'
    template = re.sub(r'upgrade_arc_v3\.png-[a-f0-9]+\.ctex',imported,template)
    template = template.replace('res://data/art/environment/upgrade_arc_v3.png',resource)
    template = template.replace('process/size_limit=0','process/size_limit=1024')
    path.with_suffix('.png.import').write_text(template)

layout = json.loads((PROJECT/'data/upgrade_layout.json').read_text())
nodes = np.array([n['position'] for n in layout['nodes']])
distances = np.abs(nodes[:,None,:]-nodes[None,:,:]).max(axis=2)
np.fill_diagonal(distances,np.inf)
spacing = distances.min(axis=1)
# Conservative envelope over the complete semantic-zoom range, plus breathing room.
node_half = np.maximum(224,np.minimum(36/.075,spacing))*.5+60
edges = np.array([e['points'] for e in layout['edges']])
world = np.array([-2300.,-6000.,11600.,7600.])
placements = []

def intersects(a,b,pad=0):
    return bool(np.all(a[:2]-pad < b[:2]+b[2:]) and np.all(a[:2]+a[2:]+pad > b[:2]))

def cuts_edge(rect):
    lower,upper = rect[:2]-32,rect[:2]+rect[2:]+32
    for a,b in edges:
        delta=b-a
        low,high=0.,1.
        for axis in range(2):
            if abs(delta[axis])<1e-9:
                if a[axis]<lower[axis] or a[axis]>upper[axis]: break
            else:
                t0=(lower[axis]-a[axis])/delta[axis]
                t1=(upper[axis]-a[axis])/delta[axis]
                low,high=max(low,min(t0,t1)),min(high,max(t0,t1))
                if low>high: break
        else: return True
    return False

def clear(rect, area):
    if np.any(rect[:2]<world[:2]) or np.any(rect[:2]+rect[2:]>world[:2]+world[2:]): return False
    for point,half in zip(nodes,node_half):
        if intersects(rect,np.r_[point-half,[half*2,half*2]]): return False
    if cuts_edge(rect): return False
    for p in placements:
        if area in p['areas'] and intersects(rect,np.array(p['rect']),24): return False
    return True

def polar(angle,radius):
    a=math.radians(angle)
    return np.array([3400+math.cos(a)*radius,math.sin(a)*radius])

def place(asset_id, center, size, area, label):
    original=np.array(center,dtype=float)
    # Small local layout adjustments only, in distance order; never move upgrades.
    offsets=[(0.,0.)]
    for radius in [65,130,210,310,440,590]:
        for angle in range(0,360,30):
            a=math.radians(angle)
            offsets.append((math.cos(a)*radius,math.sin(a)*radius))
    width,height=next(e['size'] for e in manifest['assets'] if e['id']==asset_id)
    extent=np.array([size,size*height/width])
    for dx,dy in offsets:
        center=original+np.array([dx,dy])
        rect=np.r_[center-extent*.5,extent]
        if clear(rect,area):
            placements.append({'asset_id':asset_id,'rect':np.round(rect,2).tolist(),'areas':[area],'label':label})
            return
    print('Skipped occupied decoration pocket:',area,label)

for area in ['bakery','gelato']:
    house='bakery_house' if area=='bakery' else 'gelato_house'
    special='bakery_mill' if area=='bakery' else 'gelato_pavilion'
    tree='oak_tree' if area=='bakery' else 'lilac_tree'
    place(house,(-560,210),620,area,'entrance house')
    for angle,radius,size,asset in [(214,5150,620,special),(251,5200,610,'greenhouse'),(283,5210,640,house),(320,5150,590,special),(341,5100,570,'greenhouse')]:
        place(asset,polar(angle,radius),size,area,'outer landmark '+str(angle))
    place('greenhouse',polar(240,1300),510,area,'inner conservatory')
    for angle,radius,size in [(194,5050,410),(231,5170,480),(266,5230,440),(301,5180,460),(333,5130,380),(205,1510,430),(277,1450,470),(326,1510,400)]:
        place(tree,polar(angle,radius),size,area,'tree '+str(angle))
    for angle,radius in [(215,3800),(294,3880),(311,1250)]:
        place('garden_bench',polar(angle,radius),280,area,'seating '+str(angle))
    for angle,radius in [(198,3010),(226,3930),(254,2870),(282,3910),(310,2980),(337,3730),(263,1700),(323,1760)]:
        place('flower_planter',polar(angle,radius),180,area,'flowers '+str(angle))
    place('flower_planter',(310,260),190,area,'entrance flowers')

scene={
    'schema':2,
    'description':'Native collage of individually detailed transparent props over clean vector ground. No enlarged scene texture or repeated ground noise.',
    'world_rect':world.tolist(),
    'ground':{'center':[3400,0],'inner_radius':1940,'outer_radius':4860,'start_angle_degrees':176,'sweep_degrees':170,'direction':1},
    'areas':{
        'bakery':{'base_color':'aabd9b','band_color':'d2dfbf','border_color':'8fa684'},
        'gelato':{'base_color':'afc4b2','band_color':'d9d8e9','border_color':'aaa8c2'}
    },
    'assets':assets,
    'placements':placements
}
(PROJECT/'data/upgrade_arc_art.json').write_text(json.dumps(scene,indent=2)+'\n')
(HERE/'sources.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Native composition:',len(assets),'unique sprites;',len(placements),'placements;',len(placements)//2,'per area')
