import struct, json
import numpy as np

with open('assets/player/player.glb', 'rb') as f:
    f.seek(12)
    chunk_len, chunk_type = struct.unpack('<II', f.read(8))
    gltf = json.loads(f.read(chunk_len))
    bin_len, bin_type = struct.unpack('<II', f.read(8))
    bin_data = f.read(bin_len)

def get_buffer_data(acc_idx):
    acc = gltf['accessors'][acc_idx]
    bv = gltf['bufferViews'][acc['bufferView']]
    offset = bv.get('byteOffset', 0) + acc.get('byteOffset', 0)
    count = acc['count']
    ctype = acc['componentType']
    atype = acc['type']
    type_map = {5126: np.float32, 5123: np.uint16, 5125: np.uint32}
    dim_map = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}
    dtype = type_map[ctype]
    dim = dim_map[atype]
    raw = bin_data[offset : offset + count * dim * np.dtype(dtype).itemsize]
    return np.frombuffer(raw, dtype=dtype).reshape((count, dim))

body_prim = gltf['meshes'][0]['primitives'][0]
pos = get_buffer_data(body_prim['attributes']['POSITION'])
normals = get_buffer_data(body_prim['attributes']['NORMAL'])
uvs = get_buffer_data(body_prim['attributes']['TEXCOORD_0'])
indices = get_buffer_data(body_prim['indices']).flatten().astype(int)

triangles = indices.reshape((-1, 3))
print("Total body triangles:", len(triangles))

# Let's inspect triangles whose center in 3D is in the cockpit region
cockpit_tris = []
for t_idx, tri in enumerate(triangles):
    p0, p1, p2 = pos[tri]
    center = (p0 + p1 + p2) / 3.0
    if center[0] > -0.60 and center[0] < -0.22 and center[1] > 0.04 and abs(center[2]) < 0.16:
        n = (normals[tri[0]] + normals[tri[1]] + normals[tri[2]]) / 3.0
        n_len = np.linalg.norm(n)
        if n_len > 0: n /= n_len
        cockpit_tris.append((t_idx, center, n, uvs[tri]))

print("Cockpit region triangles:", len(cockpit_tris))
# Print a few samples
for i in range(min(5, len(cockpit_tris))):
    idx, c, n, uv = cockpit_tris[i]
    print(f"Tri {idx}: pos=({c[0]:.2f}, {c[1]:.2f}, {c[2]:.2f}) n=({n[0]:.2f}, {n[1]:.2f}, {n[2]:.2f}) uv_center=({uv.mean(axis=0)[0]:.3f}, {uv.mean(axis=0)[1]:.3f})")
