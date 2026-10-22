"""Author original pixel tiles from editable vector shapes; no source raster is modified.
Run with Python + Pillow. Writes matching SVG sources, 128px PNGs and a padded atlas.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import random
import sys
import xml.etree.ElementTree as ET

OUT = Path(__file__).resolve().parents[1] / 'assets/environment/painted'
OUT.mkdir(parents=True, exist_ok=True)
NAMES = ['brick', 'plaster', 'roof', 'glass', 'trim', 'metal', 'interior', 'wood',
         'leaf', 'bark', 'stone', 'asphalt', 'grass', 'paving', 'industrial', 'damage']
tiles = []
for index, name in enumerate(NAMES):
    if '--from-svg' in sys.argv:
        # Repack edited vector sources without regenerating or overwriting their artwork.
        source = ET.fromstring((OUT / (name + '.svg')).read_text(encoding='utf-8'))
        im = Image.new('RGB', (128, 128)); draw = ImageDraw.Draw(im)
        for shape in source:
            kind = shape.tag.rsplit('}', 1)[-1]
            if kind == 'rect':
                x, y = int(shape.get('x', 0)), int(shape.get('y', 0))
                w, h = int(shape.get('width')), int(shape.get('height'))
                draw.rectangle((x, y, x+w-1, y+h-1), fill=shape.get('fill'))
            elif kind == 'polygon':
                points = [tuple(map(int, p.split(','))) for p in shape.get('points').split()]
                draw.polygon(points, fill=shape.get('fill'))
            else:
                raise ValueError('Pixel sources support integer rectangles and polygons: ' + kind)
        im.save(OUT / (name + '.png')); tiles.append(im)
        continue
    rng = random.Random(1700 + index)
    base = ['#895c47','#b2a58b','#535e62','#35464b','#aaa18d','#657062','#897362','#887247',
            '#657743','#65503c','#898a78','#41494a','#657447','#a49f89','#6f7966','#b9b3a5'][index]
    im = Image.new('RGB', (128,128), base); draw = ImageDraw.Draw(im)
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128" shape-rendering="crispEdges"><rect width="128" height="128" fill="{base}"/>']
    def rect(x,y,w,h,c):
        draw.rectangle((x,y,x+w-1,y+h-1), fill=c)
        svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{c}"/>')
    def poly(points,c):
        draw.polygon(points,fill=c)
        svg.append(f'<polygon points="{" ".join(f"{x},{y}" for x,y in points)}" fill="{c}"/>')
    def clusters(colors, count, scale=1):
        # Connected stepped patches; sparse broad marks instead of per-pixel noise.
        for _ in range(count):
            x=rng.randrange(0,32)*4; y=rng.randrange(0,32)*4
            w=rng.choice([8,12,16,20])*scale; h=rng.choice([4,8,12])*scale
            c=rng.choice(colors)
            for dx in [-128,0,128]:
                for dy in [-128,0,128]:
                    poly([(x+dx,y+dy),(x+w+dx,y+dy),(x+w+dx,y+h+dy),(x+w-4+dx,y+h+dy),(x+w-4+dx,y+h+4+dy),(x+4+dx,y+h+4+dy),(x+4+dx,y+h+dy),(x+dx,y+h+dy)],c)
    if name in ['brick','interior']:
        palette=['#8c5e48','#95684d','#80553f','#a17153','#906046'] if name=='brick' else ['#897362','#97806b','#7d6859','#a18a71']
        for row in range(8):
            for x in range(-32,129,32):
                px=x+(16 if row%2 else 0); y=row*16
                rect(px,y,31,15,rng.choice(palette)); rect(px+2,y+2,22,2,'#ac805d' if name=='brick' else '#ad9780')
                rect(px+4,y+11,21,3,'#79523f' if name=='brick' else '#7c685a')
        if name=='interior': clusters(['#61574d','#6c6051'],9)
    elif name=='roof':
        for y in range(0,128,16):
            for x in range(-32,128,32):
                px=x+(16 if y%32 else 0)
                rect(px,y,31,15,rng.choice(['#4f595d','#596368','#616c6d','#505f63']))
                rect(px+2,y+1,27,2,'#75807e'); rect(px+1,y+13,29,2,'#424f53')
                if rng.random()<.32: rect(px+6,y+4,10,4,'#6b7675')
    elif name in ['metal','industrial']:
        clusters(['#76816c','#5f6b5d','#7e8673'],12)
        step=32 if name=='metal' else 16
        for x in range(0,128,step):
            rect(x,0,2,128,'#4b574e');rect(x+2,0,2,128,'#909680')
            rect(x+5,4,5,3,'#a9ab92');rect(x+3,102,6,7,'#9c9d83')
        rect(0,62,128,2,'#566052')
    elif name=='glass':
        poly([(0,15),(25,0),(65,0),(0,65)],'#495e61')
        poly([(48,128),(128,48),(128,68),(68,128)],'#52676a')
        poly([(0,80),(80,0),(94,0),(0,94)],'#3e5357')
    elif name=='wood':
        for x in range(0,128,32):
            rect(x,0,2,128,'#514936');rect(x+2,0,2,128,'#b09a62')
            rect(x+9,14,4,36,'#766442');rect(x+19,57,5,42,'#a18b58')
        rect(0,18,128,10,'#62583d');rect(0,100,128,10,'#62583d')
    elif name=='bark':
        for x in range(0,128,16):
            rect(x,0,4,128,'#4f4231');rect(x+5,0,3,128,'#82664a')
            rect(x+8,24+(x%3)*12,5,32,'#71563d')
        clusters(['#4f4130','#8c6f4d'],7)
    elif name in ['leaf','grass']:
        clusters(['#5e713e','#71804a','#7b8952','#586b3c'] if name=='leaf' else ['#627143','#6c794b','#718050','#5d6d42'],35 if name=='leaf' else 19)
        if name=='leaf': clusters(['#8a955c','#526738'],12)
    elif name=='asphalt':
        clusters(['#454d4d','#3e4647','#4a5150'],17)
        # A few joined repair seams, intentionally quiet at flight distance.
        poly([(18,0),(20,0),(20,25),(28,25),(28,54),(26,54),(26,28),(18,28)],'#363f40')
        rect(72,80,28,20,'#454d4c');rect(76,84,20,12,'#474f4d')
    elif name=='paving':
        for y in range(0,128,32):
            for x in range(0,128,32):
                rect(x,y,31,31,rng.choice(['#a49f89','#a9a38d','#9f9b86']))
                rect(x+2,y+2,27,2,'#b7b099')
        clusters(['#96947f','#b0a991'],10)
    elif name=='damage':
        clusters(['#7c776d','#615d55','#484941'],24,2)
        for x,y in [(8,8),(67,42),(36,94)]:
            poly([(x,y),(x+5,y),(x+5,y+12),(x+14,y+12),(x+14,y+17),(x+8,y+17),(x+8,y+34),(x+4,y+34),(x+4,y+18),(x,y+18)],'#242b29')
    elif name=='stone':
        clusters(['#7c8070','#969580','#a2a08a','#747c70'],25)
    else:
        clusters(['#a69a80','#bcaf95','#a0937b'] if name=='plaster' else ['#989581','#bab09a','#a9a28e'],22)
        if name=='plaster': rect(0,116,128,12,'#9d927b');clusters(['#b3a387'],5)
    svg.append('</svg>')
    (OUT/(name+'.svg')).write_text('\n'.join(svg),encoding='utf-8')
    im.save(OUT/(name+'.png'));tiles.append(im)

# 16px wrapped gutters on each side. Cell 160, core 128, atlas 640.
# Shader uses explicit gradients capped at 4 mip levels, preventing adjacent tile bleed.
atlas=Image.new('RGB',(640,640))
for i,tile in enumerate(tiles):
    for y in range(160):
        for x in range(160): atlas.putpixel(((i%4)*160+x,(i//4)*160+y),tile.getpixel(((x-16)%128,(y-16)%128)))
atlas.save(OUT/'town_atlas.png')
print('Authored 16 pixel tiles, 16 editable SVG sources, and padded 640px atlas.')
