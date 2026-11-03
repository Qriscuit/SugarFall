"""Original composition geometry for the single illustrated upgrade background."""
from pathlib import Path
import json, math
from PIL import Image, ImageDraw

HERE=Path(__file__).resolve().parent
WORKSPACE=HERE.parents[1]
WORLD=[-2450.,-4650.,10800.,10800.*4/7]
SIZE=(2100,1200)
data=json.loads((WORKSPACE/'PLINKO/data/upgrade_layout.json').read_text())
center=data['shape']['center']
def screen(point): return ((point[0]-WORLD[0])*SIZE[0]/WORLD[2],(point[1]-WORLD[1])*SIZE[1]/WORLD[3])
def arc(radius,start=206,end=334):
    return [screen((center[0]+math.cos(math.radians(start+(end-start)*i/256))*radius,center[1]+math.sin(math.radians(start+(end-start)*i/256))*radius)) for i in range(257)]
image=Image.new('RGB',SIZE,'#9fb79e')
draw=ImageDraw.Draw(image)
# The broad quiet court is a keep-clear region for the live upgrade overlay.
draw.polygon(arc(5050)+list(reversed(arc(1750))),fill='#dbe4d0')
draw.line(arc(5050),fill='#edece1',width=10)
draw.line(arc(1750),fill='#edece1',width=5)
image.save(HERE/'composition-guide.png')
(HERE/'guide.json').write_text(json.dumps({'world_rect':WORLD,'size':SIZE,'shape_center':center,'upgrade_sweep_degrees':120,'illustrated_court_sweep_degrees':128,'inner_radius':1750,'outer_radius':5050},indent=2)+'\n')
