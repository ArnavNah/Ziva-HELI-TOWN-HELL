"""Run in Blender background mode; read source object/component bounds in glTF axes."""
import bpy, json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
report = {}
def xyz(v): return [round(v.x,6), round(v.z,6), round(-v.y,6)]
for path in sorted((ROOT / 'assets/Enemy/air').rglob('*.blend')):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    rows = []
    for o in bpy.data.objects:
        if o.type != 'MESH': continue
        verts = [o.matrix_world @ v.co for v in o.data.vertices]
        adjacency = [[] for _ in verts]
        for e in o.data.edges:
            a,b = e.vertices
            adjacency[a].append(b); adjacency[b].append(a)
        seen = set(); components = []
        for i in range(len(verts)):
            if i in seen: continue
            stack = [i]; seen.add(i); ids = []
            while stack:
                j = stack.pop(); ids.append(j)
                for k in adjacency[j]:
                    if k not in seen: seen.add(k); stack.append(k)
            ps = [xyz(verts[j]) for j in ids]
            lo = [min(p[k] for p in ps) for k in range(3)]
            hi = [max(p[k] for p in ps) for k in range(3)]
            components.append({'n':len(ids),'min':lo,'max':hi})
        rows.append({'object':o.name,'vertices':len(verts),'origin':xyz(o.matrix_world.translation),
                     'components':sorted(components,key=lambda c:-c['n'])})
    report[path.parent.name] = rows
out = ROOT/'artifacts/air-model-review/source-components.json'
out.write_text(json.dumps(report,indent=2))
print('AIR_SOURCE_REPORT',out)
