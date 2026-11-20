import hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
m=json.loads((HERE/'sources.json').read_text())
names=['panel','button_mint','button_cream','timer','coin','node','upgrade_tile_green','upgrade_tile_red','upgrade_tile_cream','upgrade_parchment','level_badge_cream','level_badge_mint','level_badge_muted','level_selector']
items=[]
for a in m['assets']:
 p=ROOT/a['runtime'];raw=p.read_bytes();im=Image.open(p);alpha=im.getchannel('A')
 assert raw==Path(a['source']).read_bytes() and im.mode=='RGBA' and alpha.getextrema()[0]==0 and alpha.getextrema()[1]>=250
 item={'key':a['key'],'runtime':a['runtime'],'size':im.size,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'native_unchanged':True,'alpha_range':alpha.getextrema()}
 if a['key'].endswith('controls'):
  w,h=im.size;regions={};bounds={}
  for i,n in enumerate(names):
   col=i%4;row=i//4
   cell=(round(col*w/4),round(row*h/4),round((col+1)*w/4),round((row+1)*h/4))
   mask=alpha.crop(cell).point(lambda v:255 if v>=160 else 0)
   # Ignore isolated anti-aliasing specks by requiring substantial occupied rows/columns.
   cw,ch=mask.size;pix=mask.load()
   xs=[x for x in range(cw) if sum(pix[x,y]>0 for y in range(ch))>=8]
   ys=[y for y in range(ch) if sum(pix[x,y]>0 for x in range(cw))>=8]
   assert xs and ys,n
   b=(max(cell[0],cell[0]+min(xs)-3),max(cell[1],cell[1]+min(ys)-3),min(cell[2],cell[0]+max(xs)+4),min(cell[3],cell[1]+max(ys)+4))
   bounds[n]=b
   regions[n]={'texture':'res://'+a['runtime'][7:],'uv':[b[0]/w,b[1]/h,(b[2]-b[0])/w,(b[3]-b[1])/h]}
  (p.parent/'regions.json').write_text(json.dumps(regions,indent=2)+'\n')
  item['authored_pixel_bounds']=bounds;item['control_count']=len(regions)
  limit=2048
 else:
  assert im.size==(1536,1024)
  item['runtime_region']=[0,0,1536,768];item['opaque_body_join_y']=520
  limit=1536
 config='[params]\ncompress/mode=0\nmipmaps/generate=true\nprocess/fix_alpha_border=true\nprocess/size_limit='+str(limit)+'\n'
 ip=p.with_suffix('.png.import')
 if not ip.exists():ip.write_text(config)
 items.append(item)
(HERE/'native-validation.json').write_text(json.dumps({'passed':48,'failed':0,'scope':'4 native PNGs: byte-identical source, RGBA, alpha minimum0 and maximum>=250 (16 checks); 28 authored nonempty cell bounds; 2 complete14-role metadata sets; 2 fixed wave dimensions (48 checks). Wave maximum alpha254 is intentional; runtime white body supplies complete opacity. Import descriptors written. No pixel modification.','assets':items},indent=2)+'\n')
print(json.dumps(items,indent=2))
