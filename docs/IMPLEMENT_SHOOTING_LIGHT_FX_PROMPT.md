# Implement shooting light effects in Heli-Town Hell

Work in `C:/Users/Prime 3/Documents/ziva-heli-town-helll`.

Implement the following shooting presentation pass in the existing Godot game. Read AGENTS.md, GRAPHICS_ART_DIRECTION.md and MENU_FLOW_NOTES.md first. Inspect current source before editing because other project work may have changed it. Preserve unrelated changes. This task concerns weapon presentation; preserve weapon damage, fire cadence, ammo, spread, targeting, homing, collision, enemy decisions, attack-slot rules, rewards and menu behavior.

REFERENCE AND INTENT

Reference: https://www.youtube.com/shorts/JP9b5E_G-QY — “Game Dev Hack about Lights,” @Smitty_Games.
The inspected visual sequence shows tank headlight patches, a quad in the Godot editor, and an unshaded additive shader with a UV falloff. Adapt that inexpensive fake-light technique to shooting. The reference demonstrates lighting, not a complete shooting-effects specification. The timings, shapes and budgets below are proposed art direction for THIS game, not measurements from the video.

Desired result: when the helicopter or an enemy actually fires, a small warm flash appears at the correct barrel, a readable tracer or rocket exhaust moves along the real projectile, and a short impact flash appears exactly where it hits. A nearby road or wall may receive a subtle light patch. Heavy blasts may briefly illuminate nearby surfaces using a tightly budgeted real light. Keep the chunky, pixel-textured Megabonk-inspired readability and the military Nuclear Strike identity. Do not turn the town into a smooth neon or photorealistic scene.

A glowing quad is a visible piece of geometry: it does NOT cast light onto surrounding models, create shadows, or automatically conform to a road. Emission is not scene illumination. Do not call a flat light patch a real projected light or claim bloom is required. Ordinary muzzle flashes should work without bloom. Separate three things: an attached muzzle flash, an independently moving projectile visual, and an optional patch aligned to a real surface.

CURRENT PROJECT FINDINGS TO RECHECK

- project.godot uses gl_compatibility and has an existing FXManager autoload at src/effects/fx_manager.gd. Keep that renderer and extend the existing service rather than adding a competing manager.
- src/player/player_weapons.gd::_launch_weapon_projectiles spawns the primary projectiles. It obtains one muzzle transform before its projectile loop. Add one muzzle burst per successful firing action, not one flash per shotgun pellet.
- src/player/player_turret.gd::get_active_muzzle_transform alternates barrels EVERY time it is called. Reuse the transform chosen for the actual shot; do not call this getter again merely to place an effect.
- src/player/player_salvo.gd::_fire_salvo is a separate launch path. At inspection it calls p.setup twice for each missile. Do not attach one-shot FX to setup without an idempotency guard. Normalize this local initialization only if needed and prove that shot counts, projectile behavior and damage remain unchanged.
- scenes/combat/projectile.tscn currently uses one small orange emissive cylinder for many projectile types. src/combat/projectile.gd handles swept collision, homing, impact, expiry, explosions and cluster children. Preserve that simulation. Provide explicit visual profiles rather than inferring friendliness from weapon type alone.
- projectile.gd::_on_impact currently discards the collision normal, calls damage/mod effects, then generic impact sparks. Capture the collision point and normal before resolving damage because the impacted object can be destroyed by that resolution.
- FXManager also spawns sparks from damage_dealt at a randomized position near an entity center. Without coordination this can duplicate projectile impact sparks. Keep non-projectile damage feedback through an explicit fallback and choose a single owner for each projectile impact burst; avoid broad timing-based suppression that could hide legitimate simultaneous hits.
- FXManager::spawn_explosion currently caps explosion containers at 16 but creates a fresh OmniLight3D per explosion with range 32 * scale_mult. This is a candidate for the shared flash-light budget, not a reason to add another light to every bullet.
- Enemy firing is distributed across src/enemies/ground/*.gd, src/enemies/air/*.gd, src/enemies/procedural_raider.gd and src/enemies/boss/heavy_gunship_boss.gd. Inventory all actual projectile-spawn functions and map each to a visual profile. Procedural raiders already apply variant-specific tracer overrides; preserve or deliberately translate their meaning.
- src/enemies/base_enemy.gd owns start_telegraph/update_telegraph/clear_telegraph. Preserve windup, aim commitment, cover checks, attack permissions and cancellation. A muzzle flash means a projectile was actually emitted, not that an attack was merely planned.
- src/enemies/enemy_spawner.gd uses multiple visual builders including raider_visuals.gd and field_raider_visuals.gd. Inspect imported model paths as well as procedural builds before locating muzzle markers.
- src/shaders/tactical_toon.gdshader and town_atlas.gdshader contain lit surface paths. Verify that any optional real flash light affects actual in-game materials. Do not replace the town material or bake weapon flashes into the atlas.
- UIFlow owns transitions and clears combat transients. FXManager currently processes ALWAYS. New gameplay effects must be explicitly pause-safe and cleared when leaving/restarting a run.
- SettingsStore already applies AudioManager.reduce_flashes and screen_shake_level. Reuse those settings.
- Preserve capital E in assets/Enemy/ paths. Scout Buggy source models live under assets/Enemy/scout_buggy_Game_Asset/. Do not modify or re-export supplied enemy models just to add an external Marker3D.

1. BUILD THE SMALL SHARED EFFECT SYSTEM FIRST

Extend FXManager with typed, clearly named methods for muzzle bursts, projectile presentation and impacts. Suggested API shapes (adapt to existing conventions):
  play_muzzle(profile_id, muzzle_transform, source_node, shot_direction)
  play_impact(profile_id, hit_position, hit_normal, surface_context)
  request_flash_light(position, color, energy, radius, duration, priority)
  clear_combat_effects()

Use explicit profiles carrying faction, weapon family and optional variant; damage data remains authoritative for combat. Shot direction must come from the final launch velocity or committed aim, not the helicopter body's heading. Recoil/spread can make these different. One muzzle burst can represent a multi-pellet volley while each pellet retains its own simulation. Cluster submunitions create impact feedback without generating a new vehicle muzzle flash.

Prefer a small Resource class plus reusable effect nodes under src/effects/ and scenes/effects/. Suggested names: WeaponFXProfile, MuzzleFlashFX, ImpactFlashFX, SurfaceLightPatch. Put the common shader under src/shaders/weapon_fake_light.gdshader. Names are suggestions, not permission to duplicate existing systems.

Warm reusable meshes, materials and pools during world preparation, before the loading screen reveals gameplay. Pool cosmetic nodes only unless there is a demonstrated need to change projectile allocation. Do not rewrite the combat/projectile lifecycle as part of this presentation pass.

2. IMPLEMENT THE FAKE LIGHT MATERIAL

Create a Godot spatial shader with unshaded, blend_add, cull_disabled and depth_draw_never. Keep depth testing ENABLED. Disable shadow casting on effect mesh instances. Do not use depth_test_disabled to make flashes visible through buildings.

Expose tint, intensity, opacity, UV scale, falloff and optional UV quantization. Build a centered radial mask from UV distance with a smooth or stepped falloff. For an elongated patch, stretch the mesh or scale UV axes. Use the mask for alpha and test the actual additive result in Compatibility so the visible edge fades to nothing and no rectangular border remains. Keep shader math simple; do not depend on screen/depth textures, Forward+ features, Decal nodes, volumetric fog or a glow post-process.

Use one small emissive star/core and a slightly larger soft falloff shape for a muzzle burst. Most of the glow should be restrained; the bright core stays chunky. A short crossed-quad or low-poly burst must remain readable from the gameplay camera. Billboard only the halo if needed; preserve the barrel direction in the directional burst. Do not billboard a surface patch away from its surface.

Avoid huge transparent quads with mostly empty pixels. Share meshes and shaders. Use per-instance values supported by this renderer or a bounded material pool; do not mutate a single shared material's tint/intensity when that would change all active effects. Avoid an unbounded duplicate ShaderMaterial for every bullet.

3. PLAYER WEAPON LOOKS — STARTING VALUES, THEN TUNE IN CAMERA

All distances below are approximate world meters and must be judged from the normal gameplay camera, not a close-up preview. Durations use simulation time.

Machine gun: pale amber core #FFF0B0 and orange edge #FFAD48; roughly 0.35–0.75 m wide, 0.8–1.5 m directional burst, 0.04–0.07 s. Alternate exactly with the real muzzle selected for the shot. Short amber tracer, no persistent headlight beam. Repeated flashes must remain separate restrained pulses rather than a giant opaque sphere.

Shotgun: one wider fan burst per trigger, approximately 0.7–1.2 m wide and 0.06–0.09 s. Preserve the actual pellet directions. One optional subtle surface splash per trigger, not one surface raycast/light per pellet. Impacts remain small and bounded under many simultaneous pellets.

Missile: brief launcher flare 0.06–0.10 s, small orange exhaust core and a thin capped smoke/exhaust trail following the moving missile. Emit trail samples by distance or capped time step; never connect the muzzle to the missile with a full-length glowing beam. Homing turns must bend the trail correctly and an exploding missile must leave no orphan trail.

Rocket: more forceful short launcher flash 0.08–0.12 s, warm exhaust and a compact readable impact burst. Preserve existing recoil. Visual blast radius should relate to the real blast but be clamped for visibility; a level-5 giant damage radius must not become a screen-filling transparent quad. Distinguish the impact core from the wider danger area if one is shown.

Painted salvo: apply the same family style through its separate launch function. Coalesce flashes from the same barrel in one frame to avoid overbrightness; do not drop or combine actual missiles. Preserve equipped mod presentation, trajectory, attribution and statistics.

Mods: add restrained accents only when their corresponding gameplay effect actually applies. For example EMP/shock may use a brief cool accent; napalm may leave a small warm fire effect. Preserve existing flame/rail/rocket enemy distinctions. Do not infer a new damage/status effect merely from a cosmetic color.

4. ENEMY SHOOTING MUST BE READABLE

Use an orange-red triangular/pointed burst for ordinary hostile fire so it differs in shape as well as hue from the player's compact amber star. Keep an existing special variant's cyan or flame identity when important. Do not use color alone to communicate danger: retain projectile shape, motion and the existing telegraph.

Wire all armed types found in the current spawner: infantry, gatling/flak/siege ground weapons, missile carriers/SAM, scout/interceptor/gunship weapons, procedural field raiders and boss volleys. Map shared families to one profile and use variant overrides only when needed. Unarmed support enemies and kamikaze contact attacks should not emit gun flashes.

At the actual projectile spawn, use a real barrel-tip Marker3D where available. Add a marker under the correct moving turret/barrel transform in procedural visuals or an external wrapper for an imported model. Use a documented safe fallback only for assets without a barrel. Verify barrel tips on the Scout Buggy body/turret assembly and other visual builders; avoid hardcoded vehicle-center flashes when a turret exists. Markers must not alter collision shapes or animation pivots.

Do not trigger fire effects on attack-slot request, LOS failure, canceled windup, disabled weapon, stun or reloading. Preserve all such behavior. Boss multi-projectile volleys may use one stronger burst per physical barrel, not a separate real light for every projectile. Enemy warning meshes remain clearer and longer-lived than decorative sparks.

5. IMPACTS AND OPTIONAL SURFACE PATCHES

At a swept hit, use the real collision point and normal. Orient the burst outward from the surface. For projectile impacts use one cosmetic event per impact, even when direct damage, blast damage, status damage and entity_destroyed signals occur in the same frame. A distinct death explosion can still coexist with the hit burst; do not spawn two copies of the same blast presentation.

Non-explosive lifetime expiry fades the tracer without inventing a wall impact. Explosive expiry already resolves gameplay blast damage: give that one coherent blast visual at the same location. Ensure cluster and napalm paths each resolve their intended cosmetic event once. Do not apply damage from FX code.

If adding the video-like light patch, place a short-lived additive quad on a verified road/ground/wall surface with a small normal offset to avoid z-fighting. Raycast using existing environment mask 2, filtering out unsuitable dynamic objects as necessary. Cast from the relevant light/impact region and limit distance; do not force every helicopter muzzle flash onto the road far below it. Omit the patch when no valid surface is nearby.

For walls, align to the hit normal. For roads, follow the actual ground height. Check a small set of edge samples for larger patches; shrink/fade or skip a patch that crosses a curb, wall, roof edge or disconnected surface. This technique is an approximation and cannot wrap around geometry. A flat quad is not a decal projector. Keep it small enough that this limitation is rarely visible.

Do not draw an enemy warning ring as decoration. A patch is weak light spill, not a laser aim line or damage-area promise. Start optional road patches at roughly 0.8–2 m across and 0.06–0.14 s; let near heavy impacts use a larger but capped patch. A helicopter firing high above the road can show a muzzle flash with no ground patch.

6. USE A SMALL REAL-LIGHT BUDGET ONLY WHERE IT HELPS

Default ordinary machine-gun/infantry shots to geometry-only flashes. To make a nearby helicopter side, tank or building actually brighten, reserve a bounded pool of short-lived OmniLight3D nodes for high-priority nearby launcher flashes and explosions. All pooled flash lights must have shadows disabled. Start with at most 4 active weapon/explosion flash lights in total, not 4 per enemy; tune after profiling. Give player/heavy nearby events priority and merge nearby simultaneous requests rather than accumulating lights.

Start ranges around 6–12 m, durations around 0.06–0.18 s, and energy tuned to the existing exposure and art palette. Reduce oversized explosion light ranges only as part of this shared budget, retaining the explosion particle presentation. Existing helicopter fire/strobes are separate continuous lights: include them when assessing overlap; do not silently disable unrelated effects.

Add hysteresis or a brief ownership interval when prioritizing lights so they do not pop between distant events every frame. Never trade away projectile visibility or damage when the light pool is full. Quad flashes still play when optional illumination is unavailable. Keep this effect functional on current lit materials and clearly report any surface that is intentionally unshaded.

7. POOLING, PAUSE, CLEANUP AND SETTINGS

Initial cosmetic budgets (tuning targets, not benchmark claims): 48 simultaneous muzzle bursts, 32 impact bursts, 16 surface patches, 32 missile/rocket trails and 4 real flash lights. Share budgets across both factions. Distance/screen cull decoration and prioritize nearby player-threatening shots. A visible hostile projectile's core must remain even if its extra halo/trail is dropped. Never cull combat simulation according to FX visibility.

Use reusable slots and bounded trail buffers; no per-bullet new Timer, Tween, Mesh or ShaderMaterial in steady state. Expiry can use one pausable update loop. Keep trail segments short and cap their total count as well as emitter count. Distinguish cosmetic dropped requests from actual fired shots in debugging. Pool counts must return to zero when combat ends.

FXManager being ALWAYS must not cause active-run effects to animate while gameplay is paused. Use a gameplay effect root with explicit PAUSABLE behavior and do not advance lifetimes from an always-processing manager while paused. Do not use shader TIME for lifetime animation that would continue independently of simulation time. UI effects, if any, remain separate. Avoid default always-processing SceneTreeTimers for gameplay expiry.

Wire cleanup into existing UIFlow transitions and run teardown. On menu, retry, results, loading, player death or scene replacement, clear the appropriate combat effect slots and release all pooled light owners. Ensure old callbacks cannot affect a newly loaded run. If a muzzle owner is freed or a surface is destroyed, stop following it safely. An effect attached to a moving vehicle must not stick to world origin after despawn. Clean shutdown must not emit freed-instance errors.

Respect Reduce Flashes at spawn AND for currently active effects when changed. Reduce intensity, alpha, bright-core area and real-light contribution; keep a readable muted projectile and attack warnings. Screen Shake Off stays off. Do not introduce a new full-screen flash or unrequested camera shake. Avoid adding settings controls unless there is a clear need; reuse existing settings first.

8. IMPLEMENT IN REVIEWABLE STAGES

A. Inventory the actual spawn functions, visual builders and ownership paths. Record a profile-coverage checklist. Create the shared shader/pool and a small isolated FX showcase scene with a ground tile, wall, player barrel and enemy barrel. Compare geometry-only and optional real illumination without changing normal play.
B. Integrate primary player fire, then salvo, then enemy families and boss volleys. Preserve all combat math. Integrate collision-normal impact events and remove only duplicate effects that this pass can identify reliably.
C. Add restrained trails/surface patches and the shared real-light budget. Keep optional layers individually switchable for developer profiling, without cluttering player menus.
D. Validate normal gameplay in the town from the normal camera; tune against texture detail, aircraft altitude, outlines, dense enemies and explosion overlap. Do not stop at a beautiful close-up showcase.

9. VERIFICATION AND ACCEPTANCE

Use isolated test data through ZIVA_TEST_DATA_DIR and the existing tools/run_menu_checks.py conventions. Do not change the user's profile or purchases during testing. Add focused tests for lifecycle/event correctness rather than snapshot tests that only mirror constants.

- One successful MG trigger creates one correctly alternating barrel burst. Empty ammo, cooldown and reload create none. A shotgun trigger creates one muzzle burst regardless of pellet count. Spread, ammo and damage are identical with FX on/off.
- Salvo missiles and cluster children each preserve their spawn counts, damage and shot statistics. Repeated setup or a repeated callback cannot duplicate one-shot FX.
- Verify each armed spawner family and boss volley visually. Canceled telegraphs, blocked LOS and lost attack slots create no firing flash. Threat cores and existing attack warnings remain readable when cosmetic budgets are exhausted.
- A building/ground hit creates one impact at the collision point with the correct outward normal. One blast causes one blast visual. Ordinary expiry creates no fake impact; explosive expiry produces the existing gameplay blast and its matching FX once.
- Test low and high helicopter altitude, close walls, roofs, building destruction, curb boundaries and camera rotation. No visible glow through opaque cover, large floating light rectangles, copied ground patch on a distant road, or obvious patch bleeding across a wall.
- Hold rapid fire with enemies and Overdrive; pause for several seconds, open settings, change Reduce Flashes, resume, die, retry and return to menu. No paused lifetimes advancing, stuck lights, orphan trails or old-run FX after transition. Repeat at least five runs.
- Record active/pooled counts during stress and after cleanup. Pool exhaustion must degrade decoration only. Check that material/resource count plateaus after warm-up rather than increasing for every shot.
- Capture a reproducible rendered before/after comparison with the same seed, camera, population and fire pattern. Measure frame time and rendering statistics after warm-up, report median and p95 over a useful sample, plus maximum visible FX and light counts. State the hardware, renderer, resolution and sample duration. Do not claim 60 FPS or a specific overhead without measurement. If software/headless rendering is the only available test, say so; it cannot establish the user's GPU performance.
- Run relevant existing weapon/enemy damage, pursuit and menu transition checks where available. Parse new shaders and scripts and inspect the rendered game for transparency, wall occlusion and orientation; headless tests alone cannot validate appearance. Report existing unrelated failures separately.

DELIVER

Implement the working effects, not just a plan. Return a short explanation, changed-file list, screenshots or short captures of player/enemy fire and impact examples, coverage checklist for all firing families, verification results, measured performance and any remaining limits. Document the effect profiles/budgets so later weapons and enemy models can use the same service.

Do not redesign menus, enemy AI, progression, map layout or base textures. Do not replace the renderer, require an external VFX plugin, generate a new enemy model, or modify damage balance to make the visuals look stronger. The effects should make the current combat easier to read and more satisfying.
