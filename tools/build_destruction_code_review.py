"""Produce the read-only destruction audit report from source and probe evidence."""
from pathlib import Path
from html import escape
import base64
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/destruction-code-review-20261020'
DOCS = ROOT / 'docs'
observations = json.loads((OUT / 'observations.json').read_text(encoding='utf-8'))
findings = [
    dict(priority='P1', title='Boss destruction is missing', file='src/enemies/boss/heavy_gunship_boss.gd', line=198,
         problem='The boss hides and frees itself without calling play_destruction. The generic FX listener skips enemies, so it does not supply a fallback. AudioManager also skips its generic enemy explosion sound.',
         evidence='Killing a real HeavyGunshipBoss through its DamageReceiver produced 0 burning heads and 0 composed explosions; the game entered BOSS_DECISION.',
         fix='Emit one boss destruction event before the existing decision pause, without replaying rewards or changing modal ownership. Make the initial visible flash meaningful while paused.'),
    dict(priority='P1', title='Transition cleanup misses flashes, dust and wreckage', file='src/effects/fx_manager.gd', line=377,
         problem='clear_combat_effects resets the pools but leaves separately created destruction nodes. Only the fireball container joins combat_explosions; the initial flash and contact dust do not. Legacy wreckage lives under the tree root with no cleanup group.',
         evidence='After 20 paused test blasts, manager cleanup left all 60 extra flash/fireball/dust nodes. The real UIFlow transient cleanup removed the fireballs but left 40 flash/dust nodes and 6 rigid debris bodies. They can survive into a new run and resume there.',
         fix='Give each composed destruction event one owned container or pooled slot, including its flash, dust and callbacks. Explicitly clear all wreck/debris owners during transition and reset run-scoped work.'),
    dict(priority='P2', title='The initial flash renders as a bright square', file='src/effects/fx_manager.gd', line=541,
         problem='The destruction flash uses a plain QuadMesh and an additive StandardMaterial3D with no alpha texture or UV-falloff shader. The whole rectangle is therefore visible.',
         evidence='The Compatibility-rendered capture shows a large pale square around the blast. The live material has neither a falloff ShaderMaterial nor an alpha texture.',
         fix='Reuse the existing weapon_fake_light.gdshader with an appropriate burst/falloff shape. Keep depth testing on and fade the mask to zero at its edges.'),
    dict(priority='P2', title='Fragment movement slows down when FPS drops', file='src/effects/burning_fragment_trail.gd', line=198,
         problem='min(delta, 0.033) discards elapsed time. This changes fragment age, trajectory and smoke fade below roughly 30 FPS; it is not just a limit on puff emission.',
         evidence='Feeding one second as 60 updates advanced head age to 1.00 s. Feeding the same second as 20 updates advanced it to only 0.66 s.',
         fix='Advance the full simulation time using a bounded fixed-step accumulator or suitable integration. Limit smoke samples independently, discarding excess sampling work rather than slowing the whole effect.'),
    dict(priority='P2', title='Explosion and debris budgets are not enforced', file='src/effects/fx_manager.gd', line=448,
         problem='The 48 heads, 256 puffs and 4 lights are bounded. Composed explosions, their meshes/materials/Tweens/contact dust, and legacy rigid debris are still allocated per request with no event or debris cap. There is no reserved hero event slot.',
         evidence='20 simultaneous requests created 20 composed fireball containers and 60 new top-level effect nodes; the brief proposed 12 ordinary events plus a reserved hero slot. This is a capacity check, not an FPS benchmark.',
         fix='Pool/cap complete event instances and physical debris, reserve player/boss capacity, and degrade distant smoke/dust first. Do not count only the pooled fragment arrays when reporting bounded resources.'),
    dict(priority='P2', title='Reduce Flashes does not cover the whole destruction effect', file='src/effects/burning_fragment_trail.gd', line=39,
         problem='Burning tips always use emission energy 2.5 and never read Reduce Flashes. Existing lights and flash/fireball materials do not refresh when the preference changes. The fireball Tween also targets the opaque edge color after its reduced initial alpha.',
         evidence='Tip emission stayed 2.5 before and after toggling the preference. An already active test light remained about 2.764 energy shortly after the toggle; it continued its ordinary fade instead of applying the new reduction.',
         fix='Apply reduced core size/intensity to tips and every destruction layer, preserve the reduced alpha throughout color ramps, and update active owners when settings change.'),
    dict(priority='P2', title='Surface impact is inferred from altitude and uses the actor center', file='src/player/player_helicopter.gd', line=1209,
         problem='Player and enemy crashes capture a collision normal but pass global_position as the blast point. Both additionally require y <= 3 to classify a surface hit. A real rooftop/wall impact above that height is classified as an airburst, while a low-altitude heuristic can claim ground contact without a collision.',
         evidence='Source: player_helicopter.gd:1209–1232 and base_enemy.gd:1065–1074. The actual get_slide_collision(...).get_position() is not used. This finding is based on the impact code; a rendered rooftop scenario was not run.',
         fix='Use the real collision position and normal, independent of world altitude. For timeout/no-contact, perform a bounded surface query or explicitly choose an airborne breakup.'),
    dict(priority='P2', title='Cosmetic fragments consume the global gameplay RNG', file='src/effects/burning_fragment_trail.gd', line=143,
         problem='The scatter is described as seeded, but uses global randf_range throughout launch and smoke creation. Visual requests therefore advance the same global RNG used by gameplay such as critical-hit rolls.',
         evidence='With the same global seed, inserting a fragment launch changed the next randf result. There is no separate cosmetic RandomNumberGenerator in this emitter.',
         fix='Use a dedicated cosmetic RNG with an explicit per-event seed. Keep smoke variation, fragment scatter and sound variation independent of gameplay randomness.'),
    dict(priority='P2', title='Player death starts the rupture sound twice', file='src/player/player_helicopter.gd', line=1150,
         problem='Death start explicitly plays explosion, then immediately calls play_destruction with the drone profile, which plays explosion again. This stacks the same rupture sound.',
         evidence='Source: player_helicopter.gd:1150–1155 and FXManager.play_destruction audio call at fx_manager.gd:531. The later heavy impact and defeat cue are separate legitimate beats.',
         fix='Choose one sound owner for the initial rupture. Retain the intentional later heavy contact sound and defeat cue.'),
]

files = sorted({f['file'] for f in findings} | {
    'autoload/ui_flow.gd', 'autoload/audio_manager.gd', 'src/effects/destruction_fx_profile.gd',
    'tests/test_destruction_system.gd', 'tests/test_death_animation_and_flow.gd',
    'tests/test_shooting_fx_verification.gd',
})
manifest = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in files}
(OUT / 'source-sha256.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')

intro = 'Partially implemented. The core effect system works, but this pass is not complete or ready to sign off against the destruction brief.'
checks = [
    ('Script parse check', '0 parse failures'),
    ('Existing destruction suite', '21 checks passed'),
    ('Existing player death/results suite', '12 / 12 passed'),
    ('Existing shooting FX suite', '10 / 10 passed'),
    ('Additional focused audit probe', 'Headless and Compatibility-rendered reproduction completed; problems recorded below'),
]
md = ['# Destruction code review — 20 October 2026', '', intro, '', '## Verified', '']
md += [f'- {name}: {result}.' for name, result in checks]
md += ['', 'The checks used isolated ZIVA_TEST_DATA_DIR profiles. Game source was not changed. The audit added only its probe, reports and evidence artifacts.', '',
       'Implemented: a shared FXManager, 48 fragment heads, 256 MultiMesh smoke puffs, four shared flash lights, a pausable effect root, ground/air death separation, player crash smoke and dying-input lockout.', '',
       '## Findings', '']
for index, f in enumerate(findings, 1):
    target = (ROOT / f['file']).as_posix()
    md += [f"### {index}. [{f['priority']}] {f['title']}", '',
           f"Location: [{f['file']}:{f['line']}](<{target}:{f['line']}>).", '',
           f['problem'], '', f"Evidence: {f['evidence']}", '', f"Correction: {f['fix']}", '']
md += ['## Other incomplete items', '',
       '- has_wreck/wreck_lifetime profile fields are currently not consumed by play_destruction. The player still calls the legacy six generic glowing boxes. Persistent wrecks were optional in the corrected reference brief, so this is an unfinished extension rather than a requirement to add long-lived wreckage.',
       '- The supplied render_destruction_showcase.gd directly calls FXManager rather than killing real actors, writes to a hardcoded external folder, and samples only 100 frames. It cannot certify real player/boss death integration or sustained performance.',
       '- The existing tests mostly check pool/state availability. They do not assert boss FX, complete teardown, flash shape, FPS-independent timing, live preference changes or rupture sound counts.', '',
       '## Evidence and limits', '',
       '- Rendered on Godot 4.7.1, Compatibility/OpenGL 3.3, Intel Iris Xe, 1280×720.',
       '- The flash capture deliberately pauses at spawn to expose the short-lived shape. It is an isolated effect inspection, not a normal gameplay screenshot or performance sample.',
       '- Boss probe uses the real boss DamageReceiver/callback/EventBus path in an isolated scene. It does not exercise the full boss-decision UI.',
       '- Some headless checks emitted ObjectDB cleanup warnings. This review does not attribute them to a particular production leak.',
       '- No sustained FPS benchmark, five-run end-to-end retry soak, or complete enemy-family visual pass was performed. The confirmed defects already prevent sign-off.', '',
       'Evidence: artifacts/destruction-code-review-20261020/observations.json, source-sha256.json, audit_destruction_probe.gd, initial-explosion-flash.png; logs under artifacts/menu-repair-tests/.', '',
       'Recommended order: repair boss integration and complete teardown first; then fix the masked flash, full-time simulation and event budgets; finish active settings, real contact positioning, cosmetic RNG and sound ownership.', '']
(DOCS / 'DESTRUCTION_CODE_REVIEW_2026-10-20.md').write_text('\n'.join(md), encoding='utf-8')

css = re.search(r'<style>(.*?)</style>', (DOCS / 'explosion-death-fx.html').read_text(encoding='utf-8'), re.S).group(1)
cards = []
for index, f in enumerate(findings, 1):
    cards.append(f'''<section><div class="eyebrow">{escape(f['priority'])} · Finding {index}</div><h2>{escape(f['title'])}</h2><p>{escape(f['problem'])}</p><p class="note"><strong>Evidence:</strong> {escape(f['evidence'])}</p><p><strong>Correction:</strong> {escape(f['fix'])}</p><small><code>{escape(f['file'])}:{f['line']}</code></small></section>''')
image_data = base64.b64encode((OUT / 'initial-explosion-flash.png').read_bytes()).decode('ascii')
rows = ''.join(f'<tr><td>{escape(n)}</td><td>{escape(r)}</td></tr>' for n, r in checks)
page = f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Destruction code review — 20 October 2026</title><style>{css}img{{display:block;max-width:100%;height:auto;border-radius:10px}}.verdict{{border-color:#b5904c}}.problem{{color:#f2c47c}}</style></head><body><main>
<div class="eyebrow">Heli-Town Hell / code review / 20 October 2026</div><h1>Implemented in part.<br>Several fixes still needed.</h1><p class="lead">{escape(intro)}</p>
<section class="verdict"><h2>What works</h2><p>Burning fragments and pooled smoke puffs exist. Ground enemies now use a different death path from aircraft. Player crash smoke, input lockout and the shared four-light pool are connected.</p><div class="tablewrap"><table><thead><tr><th>Check</th><th>Result</th></tr></thead><tbody>{rows}</tbody></table></div><p class="muted">Passing these existing tests does not cover the missing cases below. All tests used isolated saves. This review changed no game source.</p></section>
<section><h2>The visible problem</h2><p>The initial explosion flash is an unmasked bright square. This Compatibility-rendered capture is frozen at spawn so the shape can be inspected.</p><img src="data:image/png;base64,{image_data}" alt="An isolated explosion rendered as a large pale rectangular quad above the ground"><p class="muted">The correct implementation should use a masked burst or radial falloff. This is an effect inspection, not a gameplay performance benchmark.</p></section>
{''.join(cards)}
<section><h2>What remains unverified</h2><p>A sustained FPS benchmark, complete enemy-family visual pass and five-run death/retry soak were not performed. Some headless runs printed ObjectDB cleanup warnings; these are not attributed to a particular production leak.</p><p>Optional wreck settings are also unused, and player wreckage still uses six generic glowing boxes. The supplied showcase bypasses real actor deaths, so it does not prove the boss/player integration is complete.</p><p><a href="DESTRUCTION_CODE_REVIEW_2026-10-20.md">Detailed Markdown review</a> · <a href="../artifacts/destruction-code-review-20261020/observations.json">Probe observations</a> · <a href="explosion-death-fx.html">Implementation brief</a></p></section>
<footer>Rendered probe: Godot 4.7.1 / Compatibility OpenGL 3.3 / Intel Iris Xe / 1280×720. Source hashes and a reproducible probe are saved in artifacts/destruction-code-review-20261020/.</footer>
</main></body></html>'''
(DOCS / 'destruction-code-review.html').write_text(page, encoding='utf-8')
print('Created code review HTML and Markdown with', len(findings), 'findings.')
