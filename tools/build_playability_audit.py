"""Build the measured, read-only playability diagnosis for 21 October 2026."""
from pathlib import Path
from html import escape
import base64
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/playability-audit-20261021'
DOCS = ROOT / 'docs'
controls = json.loads((OUT / 'controls-pickups.json').read_text(encoding='utf-8'))
world = json.loads((OUT / 'world-profile.json').read_text(encoding='utf-8'))

findings = [
    dict(title='The gun can stay locked after you move the mouse away', severity='Confirmed bug · fix first', file='src/player/player_turret.gd', line=79,
         why='Hovering an enemy sets its target score to 100. The automatic selection then requires a replacement to beat 120, although its normal scores are much smaller. The current target is not cleared when it leaves range. The timer called settle_timer is decremented but never used to release the lock.',
         evidence='In the probe, moving the cursor to empty ground 65 m away from the selected target did not release it. Moving that enemy beyond 140 m still did not release it.',
         correction='Separate direct mouse intent from optional aim assistance. Release/revalidate the target on cursor exit, range, visibility and death; compare fresh scores on the same scale. Add tests for leaving the cursor, switching targets, walls and targets leaving range.'),
    dict(title='The crosshair shows the mouse, even when the barrel cannot point there', severity='Confirmed aiming mismatch', file='src/ui/hud.gd', line=233,
         why='The HUD reticle is attached directly to the mouse. The gun is independently limited to ±110° yaw and −75°/+25° pitch. A rear cursor position is therefore unreachable, but the HUD gives no indication. Mouse projection also uses the y=0 plane rather than the actual building/aircraft surface.',
         evidence='After allowing the turret to settle with a cursor behind the aircraft, barrel direction was about 66.7° away from the requested direction. This is a clamp/feedback mismatch, not proof that all yaw math is reversed.',
         correction='Raycast the visible cursor into the actual world with a fallback plane. Show the real gun/impact aim point or a clear out-of-arc cue. Keep camera update order, launch direction and reticle based on the same aiming solution. Decide explicitly whether rear aiming rotates the aircraft or stays restricted.'),
    dict(title='The whole town is rebuilt before every deployment', severity='Confirmed startup cost', file='src/world/city_generator.gd', line=38,
         why='The scene requests a 16×16 grid. Each run creates procedural roads, building meshes, collision shapes, props and field dressing at runtime. DetailMesh builds packed vertex/index arrays on the main thread. There is no baked-map or reusable building-mesh cache in this construction path.',
         evidence='The measured town contains 142 buildings, 713 MeshInstance3D nodes and 2,219 descendant nodes. Two diagnostic runs loaded in 6.11 s and 5.97 s. The latest world-generation phase had a 302.6 ms maximum frame interval; the largest interval across the whole deployment was 763.3 ms.',
         correction='Cache/prebuild repeated intact archetype meshes and collision resources, or save a generated town as a scene/resource. Share instances where possible. Build required near-spawn content before revealing gameplay and schedule the remaining work only if a real streaming system is designed. Avoid rebuilding identical geometry on retry.'),
    dict(title='World generation has a frame-count delay and misleading progress', severity='Confirmed loading behavior', file='src/world/city_generator.gd', line=67,
         why='Generation yields by loop count: roughly 85 road-marking yields, 64 block yields and 64 field-dressing yields for this grid. That is about 213 frame waits before readiness, regardless of how little work a batch contains. The loading UI independently pushes world progress toward 95% after 0.8 s, rather than measuring completed batches.',
         evidence='The actual loader spent 215 frames in WORLD preparation in both runs. At a 60 FPS cap, 213 frame waits alone represent roughly 3.55 s. At lower frame rates, the same construction schedule takes longer.',
         correction='Use a measured millisecond work budget per frame instead of unconditional fixed-count yields. Publish completed/total generation work to the loader or show an honest indeterminate preparation state. Preserve the existing readiness contract and do not reveal an unfinished collision world.'),
    dict(title='Buildings appearing late in flight can be visibility cutoff, not loading', severity='Source-confirmed distinction', file='src/world/destructible_building.gd', line=56,
         why='Building meshes are hidden beyond 155 m with a 15 m transition margin. Several props and vegetation batches have similar 155–160 m cutoffs. The city is generated before session activation, so this path does not load buildings one by one as you fly.',
         evidence='The source applies a visibility range to the building mesh and main_game.gd waits for generation_complete before setting is_prepared. A moving-camera pop-in capture was not performed, so this explains a possible appearance symptom rather than proving every instance of it.',
         correction='Distinguish startup time from distance pop-in when reproducing the complaint. Align visibility distances, inexpensive distant silhouettes/LOD and fog with the normal camera. Do not simply disable all culling; the city contributes measurable rendering cost.'),
    dict(title='Flight and camera are tuned for substantial momentum', severity='Measured feel problem · design choice', file='src/player/player_helicopter.gd', line=641,
         why='Releasing input applies a gentle glide drag. W/S are heading-relative forward/reverse, A/D rotate, and Q/E strafe. The chase camera has separate yaw and position lag, roll, idle float, changing FOV and collision zoom. These layers make the aircraft feel less direct than a typical WASD survivor-game character.',
         evidence='The baseline helicopter reached about 36 m/s. After releasing thrust it travelled another 18.47 m during the first second and still moved at 9.34 m/s. During a sustained turn, camera heading lagged about 12.58°. These are separate controlled empty-world measurements.',
         correction='Fix aiming first, then tune a clear movement contract: stronger optional auto-braking, less chase-camera lag and less roll/float for combat. Verify collision zoom in town. If camera-relative WASD is desired, change the movement/input/UI contract deliberately rather than silently swapping keys. The current acceleration math is not itself proven broken.'),
    dict(title='Nearby XP travels quickly, but the combat and collection ranges disagree', severity='Measured collection and pacing issue', file='src/loot/pickup.gd', line=123,
         why='XP attraction uses a 48 m radius with a reduced vertical-distance penalty. Combat assistance can select an enemy up to 140 m away. Distant kills can leave gems outside attraction range, requiring a trip to collect them. LootManager also explicitly halves listed enemy XP, rounds down and clamps it; early small enemies commonly drop only 1 XP.',
         evidence='With the helicopter at 14 m altitude, stationary collection took about 0.32 s from 20 m, 0.50 s from 40 m and 0.55 s from 47 m horizontal distance. Gems at 48 and 60 m did not begin attracting within the 5 s test. At 48 m the remaining vertical penalty places the gem just outside the radius. The first level needs 10 cumulative XP; the next needs 25.',
         correction='Do not blindly increase suction speed again. Align credited-kill/engagement range with a clearly defined XP attraction policy and an altitude-aware collection rule. Decide target time/kills per level, then tune the drop multiplier and threshold curve together. XP transfer on arrival already works and must remain once-only.'),
    dict(title='Airborne loot snaps down because its idle height is captured too early', severity='Confirmed placement bug', file='src/loot/loot_manager.gd', line=165,
         why='The loot manager adds a pickup to the scene tree before assigning its spawn position. _ready immediately stores initial_base_y from the default position. The next idle animation resets position.y around that old base rather than the chosen drop altitude.',
         evidence='A real loot-manager drop at y=25.5 moved to approximately y=0.03 on its first idle update. This can make air loot appear to vanish or move away from where an aircraft was killed.',
         correction='Assign the intended local/global spawn transform before the pickup captures its bobbing baseline, or provide an explicit initialization method that sets both consistently. If ground drops are desired, project them to a real surface instead of accidentally snapping to y=0.'),
]

limits = [
    'Source inspection plus isolated Godot probes; no production gameplay source, control bindings, balance values or player save was changed.',
    'Godot 4.7.1, Compatibility/OpenGL 3.3, Intel Iris Xe, 1280×720. Profiling disabled FPS/VSync caps only inside the isolated process. It did not change the user settings.',
    'Frame samples are short (150 measured frames after 40 warm-up frames), from a fixed initial camera and a separate controlled 24-enemy combat sample. Twenty-one enemy nodes remained at the end. These are diagnostics, not a long-session performance guarantee or a hand-played match.',
    'The two initial profiling runs overlapped briefly with a small headless controls probe. Both had the same 215-frame world preparation count; timing is approximate and machine-specific.',
    'The rendered profiling process completed and wrote its measurements, then emitted renderer/resource-cleanup errors at exit; the runner therefore returned nonzero. Those errors are recorded, not treated as a clean test pass. They do not establish a particular in-game memory leak or explain the aiming bug.',
    'The focused controls/pickups probe completed without script errors, with ObjectDB cleanup warnings on the last run. The existing XP pacing suite passed 6/6.',
    'No moving-camera building pop-in recording, long soak test, controller hardware test, or continuous combat playthrough was performed. Mouse/aim and collection results were driven deterministically through the real methods.',
]

files = sorted({f['file'] for f in findings} | {
    'src/player/player_camera.gd', 'autoload/input_manager.gd', 'src/ui/menus/loading_screen.gd',
    'scenes/main_game.gd', 'scenes/main_game.tscn', 'src/world/field_dressing.gd',
    'src/loot/loot_manager.gd', 'data/game_constants.gd', 'src/player/run_progression.gd',
})
(OUT / 'source-sha256.json').write_text(json.dumps({p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in files}, indent=2), encoding='utf-8')

md = ['# Playability diagnosis — 21 October 2026', '',
      'The reported feel has several causes: a reproducible sticky targeting bug, a reticle that does not represent reachable gun aim, substantial flight/camera inertia, costly startup construction and an XP engagement/collection mismatch.', '',
      '## Findings', '']
for i, f in enumerate(findings, 1):
    path = (ROOT / f['file']).as_posix()
    md += [f"### {i}. {f['title']}", '', f"**{f['severity']}** — [{f['file']}:{f['line']}](<{path}:{f['line']}>).", '',
           f['why'], '', 'Evidence: ' + f['evidence'], '', 'Repair: ' + f['correction'], '']
md += ['## Rendered performance sample', '', '| Configuration | Median frame | p95 frame | Mean draw calls |', '|---|---:|---:|---:|']
labels = [('idle_town_visible','Idle town'), ('same_scene_city_geometry_hidden','Same scene, city hidden'), ('town_visible_sun_shadows_off','Town, sun shadows off'), ('controlled_24_enemy_combat','Separate 24-enemy combat sample')]
for key, label in labels:
    m=world[key]
    md.append(f"| {label} | {m['median_frame_ms']:.2f} ms | {m['p95_frame_ms']:.2f} ms | {m['mean_draw_calls']:.0f} |")
md += ['', 'The city and shadows have a measurable cost, and combat pushes slower frames beyond a 16.67 ms / 60 FPS budget in this short sample. However these measurements do not prove a permanently low-FPS game. Aiming and inertia problems reproduce independently of town rendering.', '',
       '## Recommended repair order', '',
       '1. Repair sticky aim and make the reticle tell the truth about barrel direction/range.',
       '2. Establish a stable combat camera and predictable braking; keep the movement contract explicit.',
       '3. Fix pickup spawn height; align XP accessibility and progression pacing with the intended engagement distance.',
       '4. Cache/bake repeated world geometry, replace fixed-frame yields with time budgets and report real generation progress.',
       '5. Retest a representative 5–10 minute run with real movement, repeated kills, level-ups, town traversal and retry. Record frame-time spikes, collision readability and time to each upgrade.', '',
       '## Verification and limitations', ''] + ['- '+s for s in limits]
md += ['', 'Evidence lives in artifacts/playability-audit-20261021/: controls-pickups.json, world-profile.json, source-sha256.json, town-profile.png and the two reproducible .gd probes. Raw logs are in artifacts/menu-repair-tests/.', '']
(DOCS / 'PLAYABILITY_AUDIT_2026-10-21.md').write_text('\n'.join(md), encoding='utf-8')

css = re.search(r'<style>(.*?)</style>', (DOCS / 'explosion-death-fx.html').read_text(encoding='utf-8'), re.S).group(1)
sections=[]
for i,f in enumerate(findings,1):
    sections.append(f'''<section><div class="eyebrow">{i} · {escape(f['severity'])}</div><h2>{escape(f['title'])}</h2><p>{escape(f['why'])}</p><p class="note"><strong>Evidence:</strong> {escape(f['evidence'])}</p><p><strong>Repair:</strong> {escape(f['correction'])}</p><small><code>{escape(f['file'])}:{f['line']}</code></small></section>''')
table=''.join(f'<tr><td>{escape(label)}</td><td>{world[key]["median_frame_ms"]:.2f} ms</td><td>{world[key]["p95_frame_ms"]:.2f} ms</td><td>{world[key]["mean_draw_calls"]:.0f}</td></tr>' for key,label in labels)
image=base64.b64encode((OUT/'town-profile.png').read_bytes()).decode('ascii')
page=f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Why the game feels unresponsive — project audit</title><style>{css}img{{display:block;max-width:100%;height:auto;border-radius:10px}}.metric{{font-size:30px;font-weight:800;color:var(--gold)}}.grid .card p{{margin-bottom:0}}</style></head><body><main>
<div class="eyebrow">Heli-Town Hell / measured playability review / 21 October 2026</div><h1>Why the game feels hard to control.</h1><p class="lead">There is a real aiming bug. Movement and camera momentum add delay, the whole town rebuilds on deployment, and XP can remain outside your collection range.</p>
<div class="grid"><div class="card"><div class="metric">~6 seconds</div><h3>Deployment</h3><p>142 buildings are generated at runtime. World preparation waits 215 frames.</p></div><div class="card"><div class="metric">18.5 metres</div><h3>Coasting</h3><p>Distance travelled in the first second after releasing forward thrust.</p></div><div class="card"><div class="metric">65 metres</div><h3>Cursor mismatch</h3><p>The gun stayed locked while the cursor moved this far away on the ground.</p></div></div>
<section><h2>What to fix first</h2><ol><li>Release sticky enemy targeting and show the real reachable aim point.</li><li>Reduce unwanted braking/camera delay after choosing the intended control style.</li><li>Fix loot altitude and align XP accessibility with combat distance.</li><li>Cache world geometry and give generation a real time budget and progress counter.</li><li>Verify a full combat run with movement, upgrades and retry.</li></ol><p class="muted">This is a diagnosis. Game code and the player's save were not changed.</p></section>
{''.join(sections)}
<section><h2>Does low FPS explain everything?</h2><p>No constant low-FPS problem was established by these short samples. The city and shadows cost frame time, and the slower combat frames exceeded a 60 FPS budget. The aiming and inertia problems were also reproduced in a small isolated world.</p><div class="tablewrap"><table><thead><tr><th>Configuration</th><th>Median</th><th>p95</th><th>Draw calls</th></tr></thead><tbody>{table}</tbody></table></div><p class="muted">p95 is the frame time at the slower end of the sample. 60 FPS allows about 16.67 ms per frame. These samples are short and do not certify sustained performance.</p></section>
<section><h2>Rendered town used for the diagnostic</h2><img src="data:image/png;base64,{image}" alt="Current helicopter and town in the production flight camera"><p class="muted">Fixed-camera, idle scene. The HUD FPS counter can lag the sampled interval; the table uses measured frame intervals. This image does not demonstrate a moving-camera pop-in test.</p></section>
<section><h2>What was tested, and what remains uncertain</h2><ul>{''.join('<li>'+escape(s)+'</li>' for s in limits)}</ul><p><a href="PLAYABILITY_AUDIT_2026-10-21.md">Detailed source review</a> · <a href="../artifacts/playability-audit-20261021/controls-pickups.json">Controls and pickup measurements</a> · <a href="../artifacts/playability-audit-20261021/world-profile.json">World measurements</a></p></section>
<footer>Review and diagnostic artifacts only. No movement, targeting, XP, art or production settings were changed.</footer></main></body></html>'''
(DOCS/'playability-audit.html').write_text(page,encoding='utf-8')
print('Created playability report with',len(findings),'findings and measured evidence.')
