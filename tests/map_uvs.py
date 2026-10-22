import json
from PIL import Image, ImageDraw

def map_uvs():
    with open("assets/player/player.glb", "rb") as f:
        f.seek(12)
        clen = int.from_bytes(f.read(4), 'little')
        f.seek(20)
        g = json.loads(f.read(clen))
        f.seek(12 + 8 + clen + 8)
        bin_data = f.read()

    bvs = g['bufferViews']
    accs = g['accessors']

    # Get body mesh (mesh 0)
    m = g['meshes'][0]
    p = m['primitives'][0]
    pos_acc = accs[p['attributes']['POSITION']]
    uv_acc = accs[p['attributes']['TEXCOORD_0']]
    idx_acc = accs[p['indices']]

    # Load positions, uvs, indices
    import struct
    def read_floats(acc, count, comp_type=5126):
        bv = bvs[acc['bufferView']]
        offset = bv.get('byteOffset', 0) + acc.get('byteOffset', 0)
        res = []
        for i in range(acc['count']):
            vals = struct.unpack_from(f"<{count}f", bin_data, offset + i * count * 4)
            res.append(vals)
        return res

    def read_indices(acc):
        bv = bvs[acc['bufferView']]
        offset = bv.get('byteOffset', 0) + acc.get('byteOffset', 0)
        c_type = acc['componentType']
        res = []
        fmt = "<H" if c_type == 5123 else "<I"
        stride = 2 if c_type == 5123 else 4
        for i in range(acc['count']):
            val = struct.unpack_from(fmt, bin_data, offset + i * stride)[0]
            res.append(val)
        return res

    positions = read_floats(pos_acc, 3)
    uvs = read_floats(uv_acc, 2)
    indices = read_indices(idx_acc)

    print(f"Loaded {len(positions)} positions, {len(uvs)} UVs, {len(indices)} indices ({len(indices)//3} triangles)")

    # Draw UV wireframe and find UV bounds for key areas (cockpit: y>0.1, z<-1.5, abs(x)<0.6)
    w, h = 2048, 2048
    uv_img = Image.new("RGB", (w, h), (0, 0, 0))
    draw = ImageDraw.Draw(uv_img)

    cockpit_tris = []
    body_tris = []
    tail_tris = []
    wing_tris = []

    for i in range(0, len(indices), 3):
        i0, i1, i2 = indices[i], indices[i+1], indices[i+2]
        p0, p1, p2 = positions[i0], positions[i1], positions[i2]
        u0, u1, u2 = uvs[i0], uvs[i1], uvs[i2]

        avg_p = [(p0[j] + p1[j] + p2[j])/3.0 for j in range(3)]
        # Transform: ApacheModel transform was (0,0,-7.2; 0,7.2,0; 7.2,0,0) with z_offset 1.376
        # In ApacheModel local coords:
        # x_local = avg_p[0], y_local = avg_p[1], z_local = avg_p[2]
        # Visuals: x_vis = 7.2 * z_local, y_vis = 7.2 * y_local, z_vis = -7.2 * x_local + 1.376

        x_vis = 7.2 * avg_p[2]
        y_vis = 7.2 * avg_p[1]
        z_vis = -7.2 * avg_p[0] + 1.376

        pts = [(u0[0]*w, (1.0 - u0[1])*h), (u1[0]*w, (1.0 - u1[1])*h), (u2[0]*w, (1.0 - u2[1])*h)]

        # Classify
        if z_vis < -1.0 and y_vis > -0.2 and abs(x_vis) < 0.8:
            cockpit_tris.append(pts)
            draw.polygon(pts, outline=(0, 255, 255))
        elif z_vis > 3.0:
            tail_tris.append(pts)
            draw.polygon(pts, outline=(255, 255, 0))
        elif abs(x_vis) > 1.2:
            wing_tris.append(pts)
            draw.polygon(pts, outline=(255, 0, 255))
        else:
            body_tris.append(pts)
            draw.polygon(pts, outline=(80, 180, 80))

    uv_img.save("artifacts/uv_classified_wireframe.png")
    print(f"Classified: {len(cockpit_tris)} cockpit, {len(body_tris)} body, {len(tail_tris)} tail, {len(wing_tris)} wing triangles.")

if __name__ == "__main__":
    map_uvs()
