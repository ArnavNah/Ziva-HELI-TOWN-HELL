# Air model replacement and helicopter animation brief

ZIVA HELI TOWN HELLL • Asset and code inspection • 30 October 2026

## Finding

There are eight supplied aircraft sets, including three helicopters. All eight production visual wrappers load and render. Replacement routes already exist in the code; this is a completion and verification task, rather than eight untouched placeholders. No supplied GLB contains a skeleton or baked animation clips. The three helicopters already contain separate rotor nodes and a procedural rotor controller, so they do not need a new skeletal rig just to spin their blades.

The render below uses equal thumbnail sizes for inspection. It does not show relative in-game scale.

![Rendered model contact sheet](../artifacts/air-model-review/model-contact-sheet.png)

## Which enemy each model should replace

| Supplied model | Existing enemy ID | Recommendation | Current wrapper extent W × H × L | Approx. triangles |
| --- | --- | --- | --- | --- |
| Iron Viper Gunship | attack_gunship | Standard attack helicopter; retain rapid cannon bursts | 7.86 × 3.34 × 9.97 | 12,289 |
| Crimson Desert Gunship | rocket_gunship | Rocket attack helicopter; retain bracket salvos | 5.91 × 2.66 × 9.10 | 11,099 |
| Desert Rotorblade Miniature | heavy_gunship_boss | Coaxial Heavy Gunship Boss; strongest helicopter silhouette | 11.08 × 3.25 × 11.85 | 1,758 |
| Crimson Skyblade | interceptor | Fast attack jet; high-speed strafing passes | 4.16 × 1.69 × 5.90 | 3,756 |
| Astra Viper | escort_fighter | Agile fighter escort; preserve escort role | 4.86 × 1.72 × 6.48 | 10,675 |
| Ironclad Skyrunner | attack_wing | Armored attack aircraft; preserve attack-wing burst behavior | 5.91 × 1.85 × 5.25 | 9,568 |
| Ironclad Skycarrier | heavy_bomber | Heavy bomber/transport silhouette; bombs from underside bay | 8.11 × 2.31 × 7.01 | 11,051 |
| Viperhawk Gunship | torpedo_vtol | Primary recommendation: missile VTOL with twin ducted fans | 6.68 × 1.60 × 5.73 | 11,605 |

Extents are measured from production wrapper meshes, including helicopter rotor reach. Triangle counts are source assembled mesh definitions, not a complete rendering-cost measurement. Units are Godot world units; verify against the player and buildings before treating them as real-world meters.

Viperhawk currently also replaces stealth_vtol and minelayer. Reusing its mesh is efficient, but three identical silhouettes can hide different threats. Keep these existing routes unless intentionally revised; use shared geometry with distinct loadout markers, materials and effects. The primary fit is torpedo_vtol. Minelayer needs an underside deployment socket and visible mine warning; stealth needs its own readable state treatment. Do not add three duplicate enemy types or duplicate GLBs.

Do not replace the modular Airborne Titan with Desert Rotorblade. Although RaiderVisuals includes a boss_air_titan alias, the actual modular boss builds its own visuals, engine weakpoints and launch bay. Preserve those systems. The Skycarrier asset also does not automatically replace that boss. Keep existing scout, hunter, kamikaze, shield and repair drone visuals until suitable models are supplied.

## What is verified, and what remains

- Verified: all eight wrappers instantiate and render in Godot 4.7.1; all three helicopters bind their required rotors. A 0.03125-second update produced main/upper −45°, tail +67.5°, and coaxial lower +45°, with zero rotor-node origin movement. This confirms rotation and fixed node pivots, not long-duration blade clearance or full combat correctness.
- Current rotor rates are 1,440 degrees/second main/coaxial and 2,160 degrees/second tail. Conventional rotors use local Y and local X respectively; coaxial rotors rotate oppositely around local Y. Inspect the geometry in motion before accepting axis alignment and hub centering.
- Remaining: attack_gunship uses a root-relative gun origin; rocket_gunship uses a randomized root-relative origin. Interceptor expects Airframe/Weapons/Muzzle_L and Muzzle_R, while the new model sits under Visuals/Model. Minelayer drops from a fixed root offset. Visible weapon sockets need to become the authoritative firing/deployment origins.
- Remaining: the rotor controller offers start, stop and speed multiplier methods, but does not itself implement flight-load response, spool transitions or a death-state policy. Existing air steering already banks and pitches the enemy root; additional visual motion must account for that.
- Import hygiene: the review produced stale external texture UID warnings for Crimson Desert, Astra Viper and Crimson Skyblade, with successful text-path fallback. Seven nested textures/albedo.png files have JPEG signatures despite their PNG extension; Desert Rotorblade's is PNG. These files are not necessarily corrupt, but should be normalized through a controlled import pass. Do not blindly rename referenced textures or delete user sources.
- Not verified by this inspection: live combat damage, director encounter balance, controller aiming against these meshes, extended performance, and death/reuse behavior. Require the acceptance checks below before calling integration complete.

## Copy-ready master implementation prompt

```text
Complete the supplied air-model integration in the existing Godot project:
C:/Users/Prime 3/Documents/ziva-heli-town-helll

Start by reading AGENTS.md and inspecting the current working files. Other work may already have integrated parts of this request; preserve it and complete the gaps. Do not replace working systems with a parallel implementation. New enemy assets stay under res://assets/Enemy/air/ with the capital E preserved.

Use these existing role assignments:
iron_viper_gunship -> attack_gunship
crimson_desert_gunship -> rocket_gunship
desert_rotorblade_miniature -> heavy_gunship_boss
crimson_skyblade -> interceptor
astra_viper -> escort_fighter
ironclad_skyrunner -> attack_wing
ironclad_skycarrier -> heavy_bomber
viperhawk_gunship -> torpedo_vtol primarily; preserve current stealth_vtol and minelayer routes with explicit role-specific shared-resource configuration and readable visual differences.

Audit the actual production path: src/enemies/enemy_spawner.gd, src/enemies/raider_visuals.gd, scenes/enemies/air/*.tscn, src/enemies/air/helicopter_rotor_controller.gd, src/enemies/air/attack_gunship.gd, rocket_gunship.gd, interceptor.gd, minelayer.gd, the existing procedural aircraft controller, BaseEnemy and src/enemies/boss/heavy_gunship_boss.gd. Inspect tools/build_clean_air_scenes.gd before changing wrappers: do not let a stale generator overwrite completed socket/rig work. Asset-folder *_visuals.tscn files are not the authoritative production wrappers.

Keep enemy identity, behavior states, spawn gates, per-type caps, entry grace, attack-slot reservations, windup, cooldown, damage scaling, projectile ownership, offscreen fairness, XP drops and boss settlement intact. Use existing AI controllers and move only the visual model under them. Preserve the seven active ground vehicles and disabled ground roster. Do not modify the modular Airborne Titan/ground fortress to fit a normal aircraft mesh.

1. Normalize the visual contract. Use one visual assembly per enemy, retain imported rest transforms, and align visible nose direction with gameplay forward. Keep model scale in the visual wrapper; avoid scaled physics roots. Compare every aircraft to the player helicopter, roads and buildings in the actual gameplay camera. Current wrapper bounds in the audit are a baseline, not automatic target dimensions. Fit simple hull/wing damage collision volumes and explicit visual/spawn bounds; do not make an enormous full-rotor collision box by default. Check ground clearance, wall clipping, spawn visibility and target selection at the final scale.

2. Add an explicit shared air weapon-socket interface. Author Marker3D nodes at visible cannon barrels, rocket/missile tube exits, bomb bays and mine deployment points. Resolve markers reliably beneath Visuals; do not depend on obsolete Airframe paths. The socket's global transform must drive projectile origin, muzzle flash, tracer origin and relevant obstruction checks consistently. Separate model mounting orientation from aim direction. Reject invalid shots through the model/world rather than teleporting projectiles to the enemy center. Missing required production sockets should report a clear diagnostic.

3. Keep outlet selection deterministic and side-effect free when queried. Preview/LOS/HUD queries must not advance the sequence; only an actual successful shot advances it. Alternate left/right gun or missile outlets when appropriate. Preserve existing damage and burst counts; a mesh showing many tubes does not authorize more projectiles or stronger attacks. Prevent self-collision and duplicate shot signals. Mines and bombs use underside sockets while retaining existing arming, lifetime, warning and damage rules.

4. Finish the three helicopter rigs using the specific prompts below. Reuse the assembled GLBs' separate moving nodes. Do not add duplicate fuselage/rotor instances, create unnecessary skeletons, or spin both a legacy rotor animation and the new controller. Animate rigid parts with delta time; preserve rest transforms. Wire state-aware rotor behavior to the existing enemy lifecycle, pause, death and any reuse/reset path.

5. For fixed-wing/VTOL assets, inspect actual geometry before promising propeller, fan or door animation. Their imported files expose a combined Body rather than separate ready-to-spin parts. Where required, make a derived export from the supplied Blender source with named independent meshes and correct hub pivots. Preserve originals, UVs, materials, silhouette and alignment. Do not rotate the whole engine nacelle, wing or fan shroud to fake blade rotation. Only animate landing gear, bay doors, control surfaces or movable guns if isolated geometry exists or is deliberately prepared.

6. Match the current low-poly military art direction: olive/sand/red for the supplied gunships and legible faction accents. Reuse shared materials, meshes and textures; keep albedo sRGB and data textures linear, respecting the actual roughness/metallic channel packing. Make metal/glass readable without blowing out exposure or making aircraft invisible at distance. Use the supported renderer. Resolve reproducible UID/import warnings through source/import configuration, never by hand-editing generated .godot cache binaries. Normalize mislabelled JPEG-as-PNG files only with reference-safe migration and reimport. Avoid duplicate imported source exports in the shipped resource graph.

7. Add focused validation for actual factory-spawned enemies and rotor/socket behavior, then perform rendered combat checks. Report which changes are implemented and which need model authoring. No claim of full combat verification based only on loading a PackedScene. Record before/after screenshots, relevant logs, measured visual bounds, and remaining issues in docs.
```

## Helicopter 1 — Iron Viper / attack_gunship

```text
Finish Iron Viper as the normal attack_gunship using scenes/enemies/air/iron_viper_visuals.tscn and assets/Enemy/air/iron_viper_gunship/iron_viper_assembled.glb. The imported hierarchy under Visuals is Model/Fuselage/Main_Rotor and Model/Fuselage/Tail_Rotor. These already bind to HelicopterRotorController; preserve their imported hub origins and rest transforms. Standalone fuselage, main_rotor and tail_rotor GLBs are available for repair/reference, but do not instance them over the assembled version.

Spin the main rotor around local Y and tail rotor around its shaft, currently local X. Keep the body, mast and fixed tail structure stationary relative to the fuselage. Verify the separated tail piece does not include a structure that should remain fixed. Use the existing 1440/2160 deg/s as an initial visual baseline; expose per-rig settings and validate aliasing at 30/60/120 FPS. Optional rotor blur must replace/fade the blades consistently rather than doubling opaque geometry or hiding attack telegraphs.

Bind steady flight, acceleration and damage/death presentation to the existing controller. If using spool transitions, make active-aircraft spawn start at flight RPM, and do not briefly show stopped blades during entry. Pause freezes the rig; death follows the existing death lifecycle without extending collision/damage lifetime. Reset any retained animation state on reuse. Cosmetic bob, recoil and lean belong on an isolated visual offset and must not double BaseEnemy's existing bank/pitch.

Place one or two cannon muzzle markers only where the actual model has gun exits; use matching sockets for shot and flash, keeping the existing six-shot burst and attack permission checks. The large visible rocket pods do not justify adding rocket attacks to this role. If the chin gun is one inseparable fuselage mesh, use a fixed firing arc consistent with the weapon rather than pretending it independently tracks; prepare a derived isolated gun only if tracking is required. Verify nose/aim alignment, no self-hit, and no fuselage or rotor recoil from gun animation.
```

## Helicopter 2 — Crimson Desert / rocket_gunship

```text
Finish Crimson Desert as rocket_gunship using scenes/enemies/air/crimson_desert_visuals.tscn and assets/Enemy/air/crimson_desert_gunship/crimson_desert_assembled.glb. Moving nodes are Model/Fuselage/Main_Rotor and Model/Fuselage/Tail_Rotor beneath Visuals. Keep the fenestron/tail duct fixed; rotate only the inner tail fan about its actual shaft. Verify which polygons are in the separate tail mesh; if shroud geometry is included, separate it in a derived asset before animation. Preserve pivots and rest orientations.

Use the existing conventional rotor controller, main local Y and tail local X after geometric confirmation. Apply the same spawn/pause/death/reuse and frame-rate requirements as Iron Viper. Add subtle attack recovery presentation without rotating the physics body away from its real aim or double-applying existing flight bank.

Author left/right rocket outlet markers on the visible pod tube mouths. Replace the randomized root-offset launch origin in rocket_gunship.gd with deterministic valid outlets. Retain the existing three-rocket bracket salvo, shot spacing, warning window, attack-slot checks and damage. Alternate visible pod outlets across the salvo; marker queries must not consume a tube. Make flame, smoke and projectile originate at the same selected mouth with launch direction consistent with the model and existing aiming constraints. Do not animate the whole pod unless a genuine separated mount exists. Ensure rockets clear the aircraft and do not impact their own collider on creation.

Show a clear preparation cue before the first rocket using the established windup; do not hide stronger attacks inside decorative effects. Validate all three shots while turning, at both ends of permitted attack range, and with a blocked firing line. Resolve the recorded stale texture UID fallback warnings without losing material assignments.
```

## Helicopter 3 — Desert Rotorblade / Heavy Gunship Boss

```text
Finish Desert Rotorblade as heavy_gunship_boss using scenes/enemies/air/desert_rotorblade_boss_visuals.tscn and assets/Enemy/air/desert_rotorblade_miniature/desert_rotorblade_assembled.glb. The separate moving nodes are Model/Fuselage/Upper_Rotor and Model/Fuselage/Lower_Rotor beneath Visuals. Rotate them in opposite directions around local Y at equal configurable magnitude. There is no conventional tail rotor. Do not use rotors_combined.glb for independent counterrotation or instance it over the assembled rotors.

Preserve both shaft origins and vertical separation. At the current uniform Model scale 12.5 the rotor-center height separation is about 0.555 world units. Confirm blade clearance and hub centering visually at speed and through boss maneuvers; zero node-origin movement alone does not prove correct blade clearance. Keep fixed mast/fuselage stationary relative to the aircraft. The current wrapper bounds are approximately 11.08 x 3.25 x 11.85 including rotors; compare boss readability to the two normal gunships and the gameplay camera before changing scale.

Connect the rig to src/enemies/boss/heavy_gunship_boss.gd while preserving its real attacks, phases, health, telegraphs, death rewards and once-only completion. Give existing spread/barrage attacks explicit model sockets instead of a missing turret_pivot or generic root+UP fallback. Determine which visible weapon geometry can support those attacks; prepare isolated mounts only when needed. Add controlled visual recoil and heavier recovery without changing hit detection or concealing phase warnings. Rotor spool/damage smoke are presentation driven by existing state, not new hidden combat modifiers.

Keep this model out of the modular Airborne Titan replacement path. That boss has engine weakpoints and a launch bay that must remain functional. Test the real Heavy Gunship Boss spawn route, phase transitions, death during attacks, pause and run restart; confirm no duplicate boss visuals, damage, XP/reward settlement or end-of-wave callbacks.
```

## Remaining five model-specific implementation prompts

```text
CRIMSON SKYBLADE -> INTERCEPTOR
Use scenes/enemies/air/crimson_skyblade_visuals.tscn. Keep the dedicated Interceptor AI's fast strafe, outbound break and re-engagement rather than converting it into a hovering drone. Replace obsolete Airframe/Weapons/Muzzle_L and Muzzle_R lookups with authored gun sockets on the new Visuals rig. Both forward cannon outlets must match projectile/flash locations; retain the existing permitted burst. Bank using the existing flight controller, with purely cosmetic control-surface motion only if those meshes are isolated. Align thrust glow to real exhausts and keep it subtle. Check that projected bounds and warnings cover fast edge-of-screen approaches. The interceptor script and data currently disagree on projectile speed; identify the authoritative intended value and resolve explicitly as a separate tuning decision instead of silently rebalancing during the mesh replacement.

ASTRA VIPER -> ESCORT_FIGHTER
Use scenes/enemies/air/astra_viper_visuals.tscn. Preserve escort_fighter identity, wave gate and existing burst/cooldown/attack-slot behavior. Add correct forward weapon sockets and exhaust effects; verify formation/crossing flight, bank and turn readability against the interceptor. Do not replace escort behavior with interceptor logic just because both assets are jets. Do not animate the single imported Body as a movable control surface. Resolve the recorded stale texture UID fallbacks through the import workflow and keep materials consistent in gameplay lighting.

IRONCLAD SKYRUNNER -> ATTACK_WING
Use scenes/enemies/air/ironclad_skyrunner_visuals.tscn. Preserve attack_wing's existing attack profile and early wave availability. Place cannon markers at actual visible hardpoints and verify burst origins during banking. The aircraft has visible propeller/engine features, but its supplied imported model is a combined Body; inspect the Blender source and extract rotor/propeller-only geometry into a derived export if moving blades are required. Pivot at each hub and spin around each engine shaft, with nacelles and wings fixed. Reuse materials and use distance-aware presentation. Do not add bomber attacks solely because the aircraft resembles a transport.

IRONCLAD SKYCARRIER -> HEAVY_BOMBER
Use scenes/enemies/air/ironclad_skycarrier_visuals.tscn for the normal heavy_bomber role. Preserve slow heavy attack behavior, existing bomb warning/damage and director heavy-air budget. Place a BombDrop socket beneath an appropriate belly bay, keep bombs clear of the hull, and align their visible deployment and ground warning with the real detonation location. Prepare propeller-only meshes from the combined Body before animating them. Bay-door animation is optional until separate door geometry exists; do not swing the fuselage. This is not the modular Airborne Titan boss. Validate visibility and collision at the current roughly 8.11-unit wingspan.

VIPERHAWK -> TORPEDO_VTOL; SHARED STEALTH/MINELAYER VARIANTS
Use scenes/enemies/air/viperhawk_gunship_visuals.tscn. Main role is torpedo_vtol: author the actual red-pod launch sockets, preserve missile/torpedo behavior and lock warnings, and prevent own-hull collisions. Both ducted fans need independently isolated inner blade geometry before spinning; keep circular shrouds, wings and fuselage fixed. Tilt whole nacelles only if separate pivots are deliberately authored and the visual transition follows existing flight states. Reuse the same underlying mesh/material resources for existing stealth_vtol and minelayer wrappers with configuration differences: readable stealth state and correct weapon sockets for stealth; underside MineDrop marker, arming/deployment cues and existing 4.5-second base drop cadence for minelayer. Do not let socket setup change hazard lifetime, count, arm delay or damage. Do not create a new enemy ID merely for a cosmetic variant.
```

## Required acceptance evidence

- Spawn every mapped enemy through the real public spawner and the Heavy Gunship Boss through its actual boss route. Confirm correct AI, one visual assembly, expected wave eligibility/cap and no ground-roster changes.
- For each helicopter, verify bound nodes, shaft centering, fixed mast/shrouds, no doubled spin and no drifting transforms. Compare simulated rotation after equal elapsed time at 30/60/120 FPS, accounting for wraparound. Test pause, restart, death while firing and any actual pooling/reset path.
- Observe real bullets/rockets/bombs/mines from their visible sockets while moving and banking. Check alternating outlets, blocked shots, self-collision, windup and one damage application. Pure socket queries must not advance an outlet index.
- Play normal encounters with the current camera and controller. Check aircraft readability, aim/collider alignment, effects obscuring targets, rotor overlap, occlusion, spawn edges and player survivability. Preserve existing attack-slot fairness and all damage gating.
- Compare scene/resource counts and rendering performance with representative wave populations. Share mesh/material resources; measure draw calls, texture memory and frame time before introducing LODs. Do not claim a fixed FPS target without recording hardware and encounter load.
- Reimport and reload to confirm no reproducible missing-resource/texture UID warnings. Preserve source files and document any derived geometry. Report tests actually run, screenshots, remaining authoring work and any behavior changes separately.

## Review artifacts

The inspection used tools/inspect_air_model_pack.py and tests/review_air_model_pack.gd. Outputs are artifacts/air-model-review/glb-inventory.json, runtime-inventory.json, model-contact-sheet.png and artifacts/strike-review_air_model_pack.log. The Godot review exited successfully with the import warnings described above. Gameplay implementation files and supplied model geometry were not changed by this review.
