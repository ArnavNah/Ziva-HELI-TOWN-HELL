"""
Re-pack player.glb with pristine PNG textures (normal, basecolor, ORM)
Updates all internal bufferViews, buffers, and GLB headers cleanly.
"""
import struct, json, os

def pack_pristine_glb(
    glb_in="assets/player/player_backup.glb",
    normal_path="assets/player/player_apache_normal.png",
    basecolor_path="assets/player/player_apache_basecolor.png",
    orm_path="assets/player/player_apache_orm.png",
    glb_out="assets/player/player.glb"
):
    print(f"Repacking {glb_out} from {glb_in}...")
    with open(glb_in, 'rb') as f:
        f.seek(12)
        clen = int.from_bytes(f.read(4), 'little')
        ctype = f.read(4)
        g = json.loads(f.read(clen))
        blen = int.from_bytes(f.read(4), 'little')
        btype = f.read(4)
        orig_bin = f.read(blen)

    with open(normal_path, 'rb') as f:
        norm_bytes = f.read()
    with open(basecolor_path, 'rb') as f:
        base_bytes = f.read()
    with open(orm_path, 'rb') as f:
        orm_bytes = f.read()

    bvs = g['bufferViews']
    new_bin = bytearray(orig_bin[0 : bvs[5]['byteOffset']])

    while len(new_bin) % 4 != 0: new_bin.append(0)
    bvs[5]['byteOffset'] = len(new_bin)
    bvs[5]['byteLength'] = len(norm_bytes)
    new_bin.extend(norm_bytes)

    while len(new_bin) % 4 != 0: new_bin.append(0)
    bvs[6]['byteOffset'] = len(new_bin)
    bvs[6]['byteLength'] = len(base_bytes)
    new_bin.extend(base_bytes)

    while len(new_bin) % 4 != 0: new_bin.append(0)
    bvs[7]['byteOffset'] = len(new_bin)
    bvs[7]['byteLength'] = len(orm_bytes)
    new_bin.extend(orm_bytes)

    while len(new_bin) % 4 != 0: new_bin.append(0)
    new_rotors_start = len(new_bin)
    old_rotors_start = bvs[8]['byteOffset']
    shift = new_rotors_start - old_rotors_start

    for i in range(8, len(bvs)):
        bvs[i]['byteOffset'] += shift

    new_bin.extend(orig_bin[old_rotors_start : 27572264])
    while len(new_bin) % 4 != 0: new_bin.append(0)

    g['buffers'][0]['byteLength'] = len(new_bin)

    json_str = json.dumps(g, separators=(',', ':'))
    json_bytes = bytearray(json_str.encode('utf-8'))
    while len(json_bytes) % 4 != 0: json_bytes.append(0x20)

    total_len = 12 + 8 + len(json_bytes) + 8 + len(new_bin)

    with open(glb_out, 'wb') as out_f:
        out_f.write(struct.pack('<III', 0x46546C67, 2, total_len))
        out_f.write(struct.pack('<II', len(json_bytes), 0x4E4F534A))
        out_f.write(json_bytes)
        out_f.write(struct.pack('<II', len(new_bin), 0x004E4942))
        out_f.write(new_bin)

    print(f"Success! Packed {glb_out}: {total_len} bytes.")

if __name__ == "__main__":
    pack_pristine_glb()
