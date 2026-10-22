# Playability diagnosis — 21 October 2026

The reported feel has several causes: a reproducible sticky targeting bug, a reticle that does not represent reachable gun aim, substantial flight/camera inertia, costly startup construction and an XP engagement/collection mismatch.

## Findings

### 1. The gun can stay locked after you move the mouse away

**Confirmed bug · fix first** — [src/player/player_turret.gd:79](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/player/player_turret.gd:79>).

Hovering an enemy sets its target score to 100. The automatic selection then requires a replacement to beat 120, although its normal scores are much smaller. The current target is not cleared when it leaves range. The timer called settle_timer is decremented but never used to release the lock.

Evidence: In the probe, moving the cursor to empty ground 65 m away from the selected target did not release it. Moving that enemy beyond 140 m still did not release it.

Repair: Separate direct mouse intent from optional aim assistance. Release/revalidate the target on cursor exit, range, visibility and death; compare fresh scores on the same scale. Add tests for leaving the cursor, switching targets, walls and targets leaving range.

### 2. The crosshair shows the mouse, even when the barrel cannot point there

**Confirmed aiming mismatch** — [src/ui/hud.gd:233](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/ui/hud.gd:233>).

The HUD reticle is attached directly to the mouse. The gun is independently limited to ±110° yaw and −75°/+25° pitch. A rear cursor position is therefore unreachable, but the HUD gives no indication. Mouse projection also uses the y=0 plane rather than the actual building/aircraft surface.

Evidence: After allowing the turret to settle with a cursor behind the aircraft, barrel direction was about 66.7° away from the requested direction. This is a clamp/feedback mismatch, not proof that all yaw math is reversed.

Repair: Raycast the visible cursor into the actual world with a fallback plane. Show the real gun/impact aim point or a clear out-of-arc cue. Keep camera update order, launch direction and reticle based on the same aiming solution. Decide explicitly whether rear aiming rotates the aircraft or stays restricted.

### 3. The whole town is rebuilt before every deployment

**Confirmed startup cost** — [src/world/city_generator.gd:38](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/world/city_generator.gd:38>).

The scene requests a 16×16 grid. Each run creates procedural roads, building meshes, collision shapes, props and field dressing at runtime. DetailMesh builds packed vertex/index arrays on the main thread. There is no baked-map or reusable building-mesh cache in this construction path.

Evidence: The measured town contains 142 buildings, 713 MeshInstance3D nodes and 2,219 descendant nodes. Two diagnostic runs loaded in 6.11 s and 5.97 s. The latest world-generation phase had a 302.6 ms maximum frame interval; the largest interval across the whole deployment was 763.3 ms.

Repair: Cache/prebuild repeated intact archetype meshes and collision resources, or save a generated town as a scene/resource. Share instances where possible. Build required near-spawn content before revealing gameplay and schedule the remaining work only if a real streaming system is designed. Avoid rebuilding identical geometry on retry.

### 4. World generation has a frame-count delay and misleading progress

**Confirmed loading behavior** — [src/world/city_generator.gd:67](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/world/city_generator.gd:67>).

Generation yields by loop count: roughly 85 road-marking yields, 64 block yields and 64 field-dressing yields for this grid. That is about 213 frame waits before readiness, regardless of how little work a batch contains. The loading UI independently pushes world progress toward 95% after 0.8 s, rather than measuring completed batches.

Evidence: The actual loader spent 215 frames in WORLD preparation in both runs. At a 60 FPS cap, 213 frame waits alone represent roughly 3.55 s. At lower frame rates, the same construction schedule takes longer.

Repair: Use a measured millisecond work budget per frame instead of unconditional fixed-count yields. Publish completed/total generation work to the loader or show an honest indeterminate preparation state. Preserve the existing readiness contract and do not reveal an unfinished collision world.

### 5. Buildings appearing late in flight can be visibility cutoff, not loading

**Source-confirmed distinction** — [src/world/destructible_building.gd:56](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/world/destructible_building.gd:56>).

Building meshes are hidden beyond 155 m with a 15 m transition margin. Several props and vegetation batches have similar 155–160 m cutoffs. The city is generated before session activation, so this path does not load buildings one by one as you fly.

Evidence: The source applies a visibility range to the building mesh and main_game.gd waits for generation_complete before setting is_prepared. A moving-camera pop-in capture was not performed, so this explains a possible appearance symptom rather than proving every instance of it.

Repair: Distinguish startup time from distance pop-in when reproducing the complaint. Align visibility distances, inexpensive distant silhouettes/LOD and fog with the normal camera. Do not simply disable all culling; the city contributes measurable rendering cost.

### 6. Flight and camera are tuned for substantial momentum

**Measured feel problem · design choice** — [src/player/player_helicopter.gd:641](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/player/player_helicopter.gd:641>).

Releasing input applies a gentle glide drag. W/S are heading-relative forward/reverse, A/D rotate, and Q/E strafe. The chase camera has separate yaw and position lag, roll, idle float, changing FOV and collision zoom. These layers make the aircraft feel less direct than a typical WASD survivor-game character.

Evidence: The baseline helicopter reached about 36 m/s. After releasing thrust it travelled another 18.47 m during the first second and still moved at 9.34 m/s. During a sustained turn, camera heading lagged about 12.58°. These are separate controlled empty-world measurements.

Repair: Fix aiming first, then tune a clear movement contract: stronger optional auto-braking, less chase-camera lag and less roll/float for combat. Verify collision zoom in town. If camera-relative WASD is desired, change the movement/input/UI contract deliberately rather than silently swapping keys. The current acceleration math is not itself proven broken.

### 7. Nearby XP travels quickly, but the combat and collection ranges disagree

**Measured collection and pacing issue** — [src/loot/pickup.gd:123](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/loot/pickup.gd:123>).

XP attraction uses a 48 m radius with a reduced vertical-distance penalty. Combat assistance can select an enemy up to 140 m away. Distant kills can leave gems outside attraction range, requiring a trip to collect them. LootManager also explicitly halves listed enemy XP, rounds down and clamps it; early small enemies commonly drop only 1 XP.

Evidence: With the helicopter at 14 m altitude, stationary collection took about 0.32 s from 20 m, 0.50 s from 40 m and 0.55 s from 47 m horizontal distance. Gems at 48 and 60 m did not begin attracting within the 5 s test. At 48 m the remaining vertical penalty places the gem just outside the radius. The first level needs 10 cumulative XP; the next needs 25.

Repair: Do not blindly increase suction speed again. Align credited-kill/engagement range with a clearly defined XP attraction policy and an altitude-aware collection rule. Decide target time/kills per level, then tune the drop multiplier and threshold curve together. XP transfer on arrival already works and must remain once-only.

### 8. Airborne loot snaps down because its idle height is captured too early

**Confirmed placement bug** — [src/loot/loot_manager.gd:165](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/loot/loot_manager.gd:165>).

The loot manager adds a pickup to the scene tree before assigning its spawn position. _ready immediately stores initial_base_y from the default position. The next idle animation resets position.y around that old base rather than the chosen drop altitude.

Evidence: A real loot-manager drop at y=25.5 moved to approximately y=0.03 on its first idle update. This can make air loot appear to vanish or move away from where an aircraft was killed.

Repair: Assign the intended local/global spawn transform before the pickup captures its bobbing baseline, or provide an explicit initialization method that sets both consistently. If ground drops are desired, project them to a real surface instead of accidentally snapping to y=0.

## Rendered performance sample

| Configuration | Median frame | p95 frame | Mean draw calls |
|---|---:|---:|---:|
| Idle town | 7.50 ms | 13.40 ms | 209 |
| Same scene, city hidden | 3.23 ms | 7.88 ms | 70 |
| Town, sun shadows off | 4.92 ms | 8.34 ms | 157 |
| Separate 24-enemy combat sample | 11.67 ms | 17.30 ms | 557 |

The city and shadows have a measurable cost, and combat pushes slower frames beyond a 16.67 ms / 60 FPS budget in this short sample. However these measurements do not prove a permanently low-FPS game. Aiming and inertia problems reproduce independently of town rendering.

## Recommended repair order

1. Repair sticky aim and make the reticle tell the truth about barrel direction/range.
2. Establish a stable combat camera and predictable braking; keep the movement contract explicit.
3. Fix pickup spawn height; align XP accessibility and progression pacing with the intended engagement distance.
4. Cache/bake repeated world geometry, replace fixed-frame yields with time budgets and report real generation progress.
5. Retest a representative 5–10 minute run with real movement, repeated kills, level-ups, town traversal and retry. Record frame-time spikes, collision readability and time to each upgrade.

## Verification and limitations

- Source inspection plus isolated Godot probes; no production gameplay source, control bindings, balance values or player save was changed.
- Godot 4.7.1, Compatibility/OpenGL 3.3, Intel Iris Xe, 1280×720. Profiling disabled FPS/VSync caps only inside the isolated process. It did not change the user settings.
- Frame samples are short (150 measured frames after 40 warm-up frames), from a fixed initial camera and a separate controlled 24-enemy combat sample. Twenty-one enemy nodes remained at the end. These are diagnostics, not a long-session performance guarantee or a hand-played match.
- The two initial profiling runs overlapped briefly with a small headless controls probe. Both had the same 215-frame world preparation count; timing is approximate and machine-specific.
- The rendered profiling process completed and wrote its measurements, then emitted renderer/resource-cleanup errors at exit; the runner therefore returned nonzero. Those errors are recorded, not treated as a clean test pass. They do not establish a particular in-game memory leak or explain the aiming bug.
- The focused controls/pickups probe completed without script errors, with ObjectDB cleanup warnings on the last run. The existing XP pacing suite passed 6/6.
- No moving-camera building pop-in recording, long soak test, controller hardware test, or continuous combat playthrough was performed. Mouse/aim and collection results were driven deterministically through the real methods.

Evidence lives in artifacts/playability-audit-20261021/: controls-pickups.json, world-profile.json, source-sha256.json, town-profile.png and the two reproducible .gd probes. Raw logs are in artifacts/menu-repair-tests/.
