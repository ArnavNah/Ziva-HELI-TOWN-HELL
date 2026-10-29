"""Read GLB metadata without modifying user assets."""
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
rows = []
for path in sorted((ROOT / "assets/Enemy/air").rglob("*.glb")):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<III", data)
    assert magic == 0x46546C67 and version == 2
    chunk_length, chunk_type = struct.unpack_from("<II", data, 12)
    document = json.loads(data[20:20 + chunk_length])
    accessors = document.get("accessors", [])
    meshes = document.get("meshes", [])
    triangles = 0
    for mesh in meshes:
        for primitive in mesh.get("primitives", []):
            if primitive.get("mode", 4) == 4:
                acc = primitive.get("indices", primitive.get("attributes", {}).get("POSITION"))
                if acc is not None:
                    triangles += accessors[acc]["count"] // 3
    row = {"file": str(path.relative_to(ROOT)).replace("\\", "/"), "bytes": len(data),
           "triangles_mesh_definitions": triangles, "mesh_count": len(meshes),
           "animation_count": len(document.get("animations", [])),
           "skins": len(document.get("skins", [])), "materials": len(document.get("materials", [])),
           "images": [{"name": im.get("name"), "uri": "<embedded data URI>" if im.get("uri", "").startswith("data:") else im.get("uri"), "mimeType": im.get("mimeType")} for im in document.get("images", [])],
           "nodes": [{key: value for key, value in node.items() if key in ["name", "mesh", "children", "translation", "rotation", "scale", "matrix"]} for node in document.get("nodes", [])]}
    rows.append(row)
out = ROOT / "artifacts/air-model-review"
out.mkdir(parents=True, exist_ok=True)
(out / "glb-inventory.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
for row in rows:
    print(f'{row["file"]}: meshes={row["mesh_count"]}, triangles={row["triangles_mesh_definitions"]}, animations={row["animation_count"]}, skins={row["skins"]}')
    print("  " + "; ".join(f'{node.get("name", "(unnamed)")} mesh={node.get("mesh", "-")} at={node.get("translation", [0,0,0])}' for node in row["nodes"]))
