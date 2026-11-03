"""Exact map-space composition diagram for the image-generation reference.
Creates a new geometric guide only; never edits generated artwork pixels.
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
RECT = [-1900, -5300, 10850, 6200]
SIZE = (1680, 960)
image = Image.new('RGB', SIZE, '#f3e6cd')
draw = ImageDraw.Draw(image)

def p(radius, degrees):
    angle=math.radians(degrees)
    x,y=3400+radius*math.cos(angle), radius*math.sin(angle)
    return ((x-RECT[0])/RECT[2]*SIZE[0], (y-RECT[1])/RECT[3]*SIZE[1])

def band(inner, outer, color):
    angles=[176+i*170/200 for i in range(201)]
    points=[p(outer,a) for a in angles]+[p(inner,a) for a in reversed(angles)]
    draw.polygon(points, fill=color)

band(2000,4780,'#bcc9a4')
band(2250,4520,'#f9f0d9')
image.save(HERE/'arc-composition-guide.png')
print(HERE/'arc-composition-guide.png')
