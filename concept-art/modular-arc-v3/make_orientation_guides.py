"""Draw original geometric reference guides; this does not edit generated art."""
from pathlib import Path
import math
from PIL import Image, ImageDraw

DEST = Path(__file__).resolve().parent / 'guides'
DEST.mkdir(parents=True, exist_ok=True)
for angle in [225, 255, 285, 315]:
    def point(degrees, radius):
        a = math.radians(degrees)
        return (math.cos(a)*radius, math.sin(a)*radius)
    outline = [point(angle - 4 + 8*i/80, 5450) for i in range(81)]
    outline += [point(angle + 4 - 8*i/80, 5270) for i in range(81)]
    xs, ys = zip(*outline)
    lo, hi = (min(xs), min(ys)), (max(xs), max(ys))
    width = 1400
    height = max(600, round(width*(hi[1]-lo[1]+220)/(hi[0]-lo[0]+220)))
    scale = min((width-160)/(hi[0]-lo[0]), (height-160)/(hi[1]-lo[1]))
    cx, cy = (lo[0]+hi[0])/2, (lo[1]+hi[1])/2
    def pixel(p): return ((p[0]-cx)*scale+width/2,(p[1]-cy)*scale+height/2)
    image = Image.new('RGBA',(width,height),(255,255,255,255))
    draw=ImageDraw.Draw(image)
    draw.polygon([pixel(p) for p in outline], fill='#8eae88')
    draw.line([pixel(point(angle-4+8*i/80,5270)) for i in range(81)],fill='#365c48',width=8)
    image.save(DEST / f'planting-{angle}.png')
