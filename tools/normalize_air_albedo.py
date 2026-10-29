"""Reference-safe migration: keep paths/UIDs and decoded sRGB pixels unchanged."""
from pathlib import Path
from PIL import Image
import hashlib, json
ROOT=Path(__file__).resolve().parents[1]
records=[]
for path in sorted((ROOT/'assets/Enemy/air').glob('*/textures/albedo.png')):
    with Image.open(path) as image:
        if image.format!='JPEG': continue
        decoded=image.convert('RGB')
    backup=ROOT/'.codex-backups/air-albedo'/path.parent.parent.name/'albedo.jpg'
    backup.parent.mkdir(parents=True,exist_ok=True)
    if not backup.exists():backup.write_bytes(path.read_bytes())
    before=hashlib.sha256(decoded.tobytes()).hexdigest()
    decoded.save(path,format='PNG')
    with Image.open(path) as image:
        assert image.format=='PNG' and hashlib.sha256(image.convert('RGB').tobytes()).hexdigest()==before
    records.append({'path':str(path.relative_to(ROOT)),'decoded_pixel_sha256':before,'backup':str(backup.relative_to(ROOT))})
out=ROOT/'artifacts/air-model-review/texture-migration.json'
out.write_text(json.dumps(records,indent=2))
print(f'Normalized {len(records)} albedo files, preserving decoded pixels, paths and import UIDs')
