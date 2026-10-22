"""Read source GLB structure without importing or modifying the user's assets."""
import hashlib
import itertools
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/Enemy/new ground'
IDENTITY = [[float(r == c) for c in range(4)] for r in range(4)]

def product(a, b):
    return [[sum(a[r][k] * b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]

def matrix(node):
    if 'matrix' in node:
        return [[node['matrix'][c * 4 + r] for c in range(4)] for r in range(4)]
    x, y, z, w = node.get('rotation', [0, 0, 0, 1])
    scale = node.get('scale', [1, 1, 1])
    move = node.get('translation', [0, 0, 0])
    result = [
        [1-2*y*y-2*z*z, 2*x*y-2*z*w, 2*x*z+2*y*w, move[0]],
        [2*x*y+2*z*w, 1-2*x*x-2*z*z, 2*y*z-2*x*w, move[1]],
        [2*x*z-2*y*w, 2*y*z+2*x*w, 1-2*x*x-2*y*y, move[2]],
        [0, 0, 0, 1],
    ]
    for r in range(3):
        for c in range(3):
            result[r][c] *= scale[c]
    return result

def inspect(path):
    raw = path.read_bytes()
    assert raw[:4] == b'glTF'
    offset, document, binary = 12, None, b''
    while offset < len(raw):
        length, kind = struct.unpack_from('<II', raw, offset)
        chunk = raw[offset + 8:offset + 8 + length]
        if kind == 0x4E4F534A:
            document = json.loads(chunk)
        elif kind == 0x004E4942:
            binary = chunk
        offset += 8 + length
    accessors = document.get('accessors', [])
    meshes, node_records, corners = [], [], []
    for mesh in document.get('meshes', []):
        primitives = []
        for p in mesh.get('primitives', []):
            a = accessors[p['attributes']['POSITION']]
            primitives.append({
                'vertices': a['count'], 'minimum': a.get('min'), 'maximum': a.get('max'),
                'triangles': accessors[p['indices']]['count'] // 3 if 'indices' in p else a['count'] // 3,
                'material': p.get('material'), 'attributes': list(p['attributes']),
            })
        meshes.append({'name': mesh.get('name'), 'primitives': primitives})
    def visit(index, parent):
        n = document['nodes'][index]
        world = product(parent, matrix(n))
        entry = {'index': index, 'name': n.get('name'), 'mesh': n.get('mesh'),
                 'translation': n.get('translation', [0, 0, 0]),
                 'rotation': n.get('rotation', [0, 0, 0, 1]), 'scale': n.get('scale', [1, 1, 1]),
                 'children': n.get('children', [])}
        if 'mesh' in n:
            for primitive in meshes[n['mesh']]['primitives']:
                if primitive['minimum'] is not None:
                    for corner in itertools.product(*zip(primitive['minimum'], primitive['maximum'])):
                        point = list(corner) + [1]
                        corners.append([sum(world[r][c] * point[c] for c in range(4)) for r in range(3)])
        node_records.append(entry)
        for child in n.get('children', []):
            visit(child, world)
    for root in document.get('scenes', [{}])[document.get('scene', 0)].get('nodes', []):
        visit(root, IDENTITY)
    images = []
    for image in document.get('images', []):
        entry = {k: image[k] for k in ('name', 'uri', 'mimeType') if k in image}
        if 'bufferView' in image:
            view = document['bufferViews'][image['bufferView']]
            start = view.get('byteOffset', 0)
            data = binary[start:start + view['byteLength']]
            entry.update(bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
            if data.startswith(b'\x89PNG'):
                entry['dimensions'] = list(struct.unpack_from('>II', data, 16))
        images.append(entry)
    lower = [min(p[axis] for p in corners) for axis in range(3)] if corners else None
    upper = [max(p[axis] for p in corners) for axis in range(3)] if corners else None
    return {
        'path': path.relative_to(ROOT).as_posix(), 'bytes': len(raw),
        'sha256': hashlib.sha256(raw).hexdigest(), 'animations': len(document.get('animations', [])),
        'skins': len(document.get('skins', [])), 'nodes': node_records, 'meshes': meshes,
        'triangles': sum(p['triangles'] for m in meshes for p in m['primitives']),
        'world_minimum': lower, 'world_maximum': upper,
        'dimensions': [upper[i] - lower[i] for i in range(3)] if lower else None,
        'images': images, 'materials': document.get('materials', []),
    }

reports = [inspect(p) for p in sorted(SOURCE.rglob('*.glb'))]
output = ROOT / 'artifacts/final-ground-model-inspection.json'
output.parent.mkdir(exist_ok=True)
output.write_text(json.dumps(reports, indent=2), encoding='utf-8')
for r in reports:
    print(json.dumps({k: r[k] for k in ('path', 'triangles', 'animations', 'skins', 'dimensions', 'nodes')}, separators=(',', ':')))
print('Full report:', output)
