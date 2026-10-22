# Implement vehicle explosions and helicopter destruction

Work in `C:/Users/Prime 3/Documents/ziva-heli-town-helll`.

Implement a coherent stylized destruction system for enemy vehicles, enemy aircraft and the player's helicopter in the existing Godot game. Read AGENTS.md, GRAPHICS_ART_DIRECTION.md and MENU_FLOW_NOTES.md first. Inspect current files before editing; preserve unrelated ongoing work.

REFERENCE AND SCOPE

The PRIMARY destruction reference is https://www.youtube.com/shorts/f3TZXzZ6KDI (“RTS Nav Routes,” @Smitty_Games), specifically the vehicle explosion near the end, around 29–31 seconds. The inspected frames show a compact bright yellow-orange burst, burning fragments spreading outward, and curved segmented dark smoke trails behind their bright tips. The aftermath clears rapidly; a persistent wreck is not clearly shown. Match these visible features. Do not claim the creator's exact assets, shader, particle implementation or settings are known. The following timings and budgets are proposed starting values, not measured source parameters.

The earlier https://www.youtube.com/shorts/JP9b5E_G-QY clip is a SECONDARY lighting reference only. It is not the reference for this destruction motion. The new link supersedes the earlier destruction brief's assumption about which clip to match.

The intended sequence is easy to read: a quick warm flash, a compact irregular fireball, several burning fragments on outward arcs, and dark smoke puffs marking their paths before they fade. These curved smoke trails are the signature detail; a generic fireball plus one vertical smoke plume does not satisfy this reference. Keep the Megabonk-inspired chunky forms and pixel-textured military-town art direction. Player and enemy destruction should use the same visual family, with size and timing adjusted for each vehicle. Do not make every kill a huge cinematic fireball or a realistic fluid-smoke simulation. A small recognizable scorched wreck is an optional game-specific addition, not a reference requirement; default ordinary kills to the quick-clearing reference presentation.

Coordinate with docs/IMPLEMENT_SHOOTING_LIGHT_FX_PROMPT.md. That document is a proposal, not proof that its pool, shader or APIs already exist. Inspect the code. Reuse its shared FX/light service if implemented; otherwise build the minimum reusable version here. Do not create a second competing FXManager or two independent flash-light budgets.

This task changes destruction presentation, including the movement of dead visual bodies. Preserve live combat balance, projectile damage, the explosive-enemy modifier's gameplay damage, collision attribution, score, XP, loot, boss rewards, wave counts, run settlement and menu ownership. FX must never apply new damage.

CURRENT SOURCE FINDINGS TO VERIFY

1. `project.godot` uses `gl_compatibility`; `FXManager` already points to `src/effects/fx_manager.gd`. Keep the renderer. There is no need for a third-party VFX plugin.
2. `FXManager.spawn_explosion` creates fresh CPUParticles3D fire/smoke, meshes, materials, a Tween and an OmniLight3D per request. It caps explosion containers at 16. The light range is currently 32 * scale_mult. It uses colored sphere particles and lacks a deliberately authored hot-to-smoke lifetime sequence. Improve that rather than adding another overlapping explosion system.
3. `FXManager._on_entity_destroyed` emits the generic explosion on the lethal event, before an enemy death spiral finishes. It also handles compliments, damage numbers and bounty popups. Preserve those independent feedback/reward consumers while choosing ONE owner for destruction visuals.
4. `src/combat/damage_receiver.gd` marks is_dead, emits destroyed(data), then emits EventBus.entity_destroyed. Burn deaths use the same settlement route. Ordering matters: a subclass can hide/queue_free itself or pause gameplay inside its destroyed callback before the generic EventBus handler runs. Capture needed visual data while it is valid; do not depend on a future read from a freed node.
5. `src/enemies/base_enemy.gd::_on_destroyed` releases slots, clears telegraphs, handles the explosive modifier, then puts enemies into DEATH_SPIRAL with random angular and horizontal velocity. Ground vehicles therefore inherit aircraft-like spinning. `_process_death_spiral` frees them on floor contact or after 2.5 s. Split the visual response for ground and air without changing live movement or death settlement.
6. Enemy builders include `raider_visuals.gd`, `field_raider_visuals.gd` and imported model wrappers. Determine vehicle family from explicit role/data, not a loose substring in a node name. Infantry/support units need suitable small profiles rather than tank wreckage.
7. `src/enemies/boss/heavy_gunship_boss.gd::_on_destroyed` awards rewards, emits boss_defeated, opens BOSS_DECISION, hides itself and queue_frees. Preserve rewards and decision ordering. Do not call the base death handler in a way that duplicates modifier damage or rewards.
8. `src/player/player_helicopter.gd` already has `_start_death_sequence`, `_process_death_sequence`, `_on_death_impact`, `death_impact_occurred`, rotor slowdown, descent and a delayed player_died event. Keep and improve this route; do not bypass it with an immediate Game Over screen.
9. Player descent currently calls spawn_explosion every 0.10 s. Replace that with one managed smoke/fire trail, not repeated complete blast containers. Impact currently calls three large explosions (2.6, 1.8, 1.8 scale) and spawn_airframe_wreckage. Replace those overlapping calls with one composed crash event containing any deliberately staggered secondary puffs.
10. The player impact fallback occurs after 1.6 s even without real ground contact, followed by a 0.85 s post-impact hold before player_died. A timeout is not proof of ground contact. Use the real contact position/normal when available; otherwise show an airborne breakup or a verified nearby surface, never invent a ground blast in midair.
11. `FXManager.spawn_airframe_wreckage` currently makes six generic glowing rigid-body boxes, with a 3.5 s cleanup Tween. Its container is not in the combat_explosions group. Give new wreckage explicit ownership and cleanup, and use recognizable stylized parts instead of random glowing cubes.
12. `autoload/audio_manager.gd` plays explosion on entity_destroyed, while player death has its own explosion/alarm/heavy/defeat calls. Coordinate presentation audio to avoid double booms when adding the new effects.
13. `GameManager` pauses RESULTS and BOSS_DECISION. `UIFlow` owns retry/loading/menu transitions and clears selected transient groups. `FXManager` processes ALWAYS. New effects need explicit pause semantics and transition cleanup.
14. Player flight returns early while is_dying, but the child weapon/salvo/Super/countermeasure input paths currently rely on UIFlow's active-run gate. Verify these cannot still fire or activate during the crash while the run remains ACTIVE. Add a shared dead/dying player guard where needed without disabling normal live controls.

1. CREATE SHARED DESTRUCTION PROFILES

Extend the existing FXManager. Suggested reusable pieces: DestructionFXProfile Resource, a composed ExplosionFX scene, a bounded smoke-trail emitter, a WreckVisual scene and optional lightweight debris pieces. Keep files under src/effects/, scenes/effects/ and src/shaders/ as appropriate.

Profiles should describe visual size, flash duration/intensity, fire/smoke curves, burning-fragment counts, arc speeds, smoke sample spacing, optional wreck lifetime, audio choice and camera-impact strength. Use distinct profiles for a light ground vehicle, heavy ground vehicle, small drone, enemy helicopter/VTOL, boss and each player aircraft's optional wreck shape. Use actual visual bounds with a clamped profile scale; never derive screen coverage directly from damage radius or health.

Separate event phases: lethal/breakup, actual impact, and settled wreck. A context includes a unique death instance identity, run identity, vehicle family, position, normal/contact validity, transform, linear velocity, visual bounds and deterministic cosmetic seed. Keep source references weak or validated. Snapshot necessary data before freeing gameplay objects.

Choose exactly one emission route per phase. Do not add effects independently to both destroyed and entity_destroyed and deduplicate by arbitrary proximity/time. Two vehicles can die at the same point legitimately. Use an explicit death/phase key or owned per-entity flags; expire bookkeeping on teardown. Do not suppress the EventBus signal used for loot or scoring just to prevent duplicate FX.

2. AUTHOR THE EXPLOSION IN LAYERS

These layers overlap; the explosion should not wait for one layer to finish before the next begins. Values below are starting values for a medium enemy vehicle, not measurements from the clip.

A. Initial flash: 0.04–0.08 s; small pale yellow core (#FFE6A3) with an orange falloff (#FF9B3F). Start sharply and fade quickly. No full-screen white flash. Keep depth testing enabled so buildings occlude it. Use the shared additive unshaded quad material for the halo if available. A glowing quad does not itself illuminate other models.

B. Fireball: approximately 0.05–0.25 s. Several overlapping irregular low-poly lobes expand quickly and decelerate, rather than forming a perfect spherical balloon. Animate visible color/scale/opacity over lifetime: pale amber to orange, burnt orange, then dark brown. Avoid a row of identically sized orange balls. Use a small number of mesh particles or authored flipbook shapes with restrained rotation and variation. The fireball should visually die away, not just disappear at its final size. Keep the central body small enough that the departing burning fragments remain the main readable motion.

C. Burning fragments WITH smoke trails: approximately 0.10–0.90 s of visible head movement, followed by a short smoke fade. Start with 3–6 distinct outward/upward launch directions for a medium vehicle, with irregular angular spacing so this is not a symmetrical fireworks ring. Each fragment has a tiny pale-hot/orange head and a dark body; its path bends downward under gravity. Scatter is an explosion motion, not homing missiles or a straight aiming beam. Add only a few smaller sparks. All fragments are cosmetic and have no damage hitboxes.

D. Segmented trail smoke: start immediately behind the moving burning fragments. Emit small irregular charcoal/brown puffs at bounded distance intervals, leaving old puffs in WORLD SPACE. Older puffs expand slightly, drift gently and fade, while the bright head moves onward. The result is several visible curved dark trails, not one stationary vertical plume. Start an ordinary event's total visible duration around 1.0–1.8 s and tune against the clip; allow longer smoke only for a deliberate hero/wreck profile. Use compact low-poly puffs or small textured billboards; smoke uses a normal alpha or dithered/opaque approach appropriate to the art, not additive black. No glowing gray cloud or perfectly smooth opaque tube.

E. Dust/contact response: one low, restrained gray-brown burst only at real ground/wall contact. Orient to the contact normal. An optional thin short ring is dust, not a neon shockwave or attack-warning circle. Keep airbursts free of ground dust and scorch marks.

F. Optional wreck: darkened original vehicle colors, broken silhouette and a small fading ember. Leave this disabled for the reference-matching ordinary-kill profile. If enabled as an artistic extension, a small wreck may persist 2–4 s before a quiet dissolve/shrink/fade appropriate to the material. Smoke should not obstruct enemy tells or pickups. Do not make a wreck glow uniformly orange like molten metal. A persistent wreck is not an acceptance criterion for matching the clip.

BURNING-FRAGMENT TRAIL IMPLEMENTATION — ESSENTIAL

Treat each fragment head as a small pooled cosmetic trajectory: update position from velocity and gravity using simulation delta, with optional bounded drag. Inherit a restrained fraction of vehicle velocity and use a separate seeded cosmetic RNG. Emit smoke by accumulated world distance, starting around 0.2–0.5 m between puffs, with both per-step and per-head limits. Do not emit one puff per render frame; that changes density at different FPS. Cap sampling after a hitch so the system never spawns an unbounded catch-up burst.

Each puff stores its own initial world transform, age, size and tint. Smoke already emitted must not move with its parent fragment or rotate with a falling helicopter. Stop adding puffs when a head expires; let existing puffs fade. Spawn small uneven clumps so the path reads as dark segmented smoke, with a bright hot tip distinct from the older trail. Avoid a permanent luminous line along the entire arc.

Prefer a bounded head simulation plus pooled puff geometry/particle slots with shared meshes/materials; do not allocate a new emitter, timer, mesh and material for every puff. If using CPUParticles3D per trail owner, keep owner count bounded and prove that restart clears prior particles and that world-space emission works. Do not depend on GPU-only trail/collision features. Tiny meshes or billboard sprites can produce the look without a bespoke image asset.

Use environment-only swept tests for decorative heads if collision is needed; terminate or allow at most one mild bounce, then stop fire emission. No collision damage or reward events. Old puffs may finish briefly near the surface, but heads must not pass through walls and make new trails on the far side. Do not turn the whole tank or helicopter into the burning fragment: the arcs belong to small ejected pieces.

Tune scale from the normal gameplay camera. Medium fireball width may start around 1–1.5 times the vehicle width, with a maximum screen-coverage clamp or simpler profile cap. A large boss can have multiple offset puffs within one owned event instead of a single gigantic sphere.

Use CPUParticles3D and simple reusable meshes as the first implementation path because this project already uses them. Set color/scale curves and one-shot timing deliberately; verify restart/reset before pooling. For moving smoke trails, emitted particles should remain behind in world space after emission rather than rotating or following the aircraft as a solid cloud. Do not require GPU particle collisions, a renderer migration, depth-based soft particles or volumetric smoke. Any alternative must be tested on the actual Compatibility renderer.

3. GROUND VEHICLE KILL SEQUENCE

On lethal damage, immediately stop live movement, aim, firing and telegraphs; release attack slots once. Keep the original once-only death event/reward path. Remove the dead actor from live threat/target queries as already expected. Hide or replace its intact visual at the explosion's peak, not a full frame before feedback appears.

Show one compact blast at the engine/ammo/body region. Give the dead visual a brief grounded jolt or sag if suitable, and launch the small burning fragments with curved smoke trails. The whole tank must not randomly somersault like a helicopter. Hide the intact body at peak breakup. Default to quick-clearing fragments; optionally replace it with a small scorched chassis and 2–4 recognizable cosmetic parts. If enabled, keep the wreck on the verified road/terrain surface; do not snap it through walls or to y=0 on elevated terrain.

Debris must not block the player's flight, navigation, shots or pickup collection, and must have no DamageReceiver/enemies/player groups. If using RigidBody3D, collide with environment only, disable unnecessary contact reporting, cap lifetime and freeze/sleep when settled. Decorative nonphysical fragments are preferable for most kills.

Preserve the gameplay detonation of the EXPLOSIVE modifier at lethal time exactly once. Its visual can be stronger, but a cosmetic secondary burst must not apply it again. Do not move loot/reward settlement to the end of the wreck animation.

4. ENEMY AIRCRAFT KILL SEQUENCE

At lethal damage show a small engine rupture and start a single smoke/fire trail. Release combat ownership immediately. Stop attack logic and make the body non-targetable. Then run the existing short fall/spin as a controlled dead-visual response, with rotor slowdown for helicopters and suitable roll/dive for drones/VTOLs.

Avoid using the same uncontrolled three-axis spin for all aircraft. Retain some initial horizontal velocity, clamp tumble and descend under gravity. Do not rebuild live AI or flight physics. Cosmetic movement randomness must use a separate RNG so it cannot change future enemy spawning or damage rolls.

On the first valid surface contact, create one impact event at the contact point/normal, hide the intact body and end its falling smoke source. The main breakup uses the same bright fragment heads and dark arcing trails as ground kills. Existing smoke particles can finish their lifetimes; small recognizable wreck parts are optional. If the maximum fall duration is reached in open air, create one airborne breakup with no ground patch, dust or grounded wreck. Never emit two impacts because a collision and timeout happen in the same frame.

The visual corpse must not stay in active enemy population counts or own attack slots until the animation ends. Preserve once-only scoring, drop ownership and wave progression from the original lethal event. Do not make the run wait for decorative debris to settle.

5. PLAYER HELICOPTER KILL ANIMATION

Reuse the existing player death functions and flags with an explicit once-only phase guard. At lethal damage stop fire, salvo painting/launch, Super, flares, reload activation and manual flight control. Preserve invulnerability during the crash; incoming hits must not restart it. Preserve any intentional immediate-death path used by tests/debugging while preventing duplicate player_died events.

At death start: one restrained fuselage rupture, existing alarm/rotor failure cue and a short camera impulse that respects Screen Shake. Keep the aircraft visible so the player understands it has lost control.

During descent: one attached smoke/fire source, rotor slowdown and the current bounded spin/fall response. Replace the full-explosion-every-0.1-second loop. Keep a readable aircraft silhouette; do not hide it in a constant enormous fireball. Sample trailing particles in world space and stop the trail safely if the aircraft is freed.

At actual contact: capture the real contact transform/normal before hiding the intact body; create ONE composed major crash event using a compact hot core and roughly 5–8 burning fragments with curved dark smoke trails, subject to the global cap. Use the reference's motion rather than merely enlarging the old sphere explosion. Small secondary fire puffs may be staggered inside that event, but should not each allocate a full explosion/light/audio stack. Recognizable fuselage, rotor/hub, tail and skid/armor fragments can replace generic bits where practical; a persistent central wreck is optional. Use matching Apache/Nighthawk/Warlock colors and proportions where their visuals differ.

If the 1.6 s fallback occurs while airborne, perform an air breakup at the current location. Do not label it a ground impact or place an unsupported scorch mark. Preserve the existing roughly 0.85 s post-impact/breakup viewing hold and player_died -> GameManager settlement -> RESULTS route unless a measured bug requires a narrowly justified change. Game Over must not appear before the main crash beat or be delayed by long smoke/debris lifetimes.

Keep the camera on the final crash/breakup location during the hold, with no snap to world origin or a freed wreck node. Do not add slow motion or change Engine.time_scale. Preserve existing results focus, Retry/Hangar/Menu buttons, payout deduplication and protected modal states.

6. WRECKAGE ASSETS AND MATERIALS

Start with simple authored/procedural low-poly parts and shared palette materials. A flattened angular chassis with 2 recognizable parts is more useful than six identical cubes. Reuse detached visual submeshes where practical, stripping scripts, lights, collision, animation playback and gameplay groups. Do not duplicate an entire live enemy scene as a wreck. Apply scorch to copied/instance-safe materials so intact vehicles are not darkened globally.

User-supplied enemy models remain under assets/Enemy/ (capital E). Scout Buggy source assets are under assets/Enemy/scout_buggy_Game_Asset/: Desert_Recon_Buggy_Body.glb, Desert_Recon_Buggy_Tire.glb and Desert_Recon_Buggy_Turret.glb. Inspect their imported hierarchy before detaching parts. Use wrappers or separate wreck scenes; do not overwrite or destructively re-export these source GLBs.

Preserve the town's pixel texture density and material family on exposed parts. Do not introduce glossy photorealistic debris or giant smooth black spheres. An optional small pixel flipbook can be created later, but the first version should work with meshes/shaders already available. AI-generated images are texture drafts, not rigged breakup models or finished timing curves.

7. LIGHTS, AUDIO, PAUSE AND PERFORMANCE

Use the SAME flash-light budget as weapon FX: initially at most 4 active weapon/destruction flash lights combined, with no shadows and priority for the player's crash and nearby heavy kills. Start real light ranges around 6–12 m for ordinary destruction, tune a capped player/boss range after testing. Do not retain a large range solely because scale_mult is high. Light brightness must not change the rest of the scene's material settings.

Ordinary kills need one main detonation sound. Player/boss sequences may deliberately have a small rupture followed by a later heavy contact sound. Audit AudioManager's entity_destroyed listener and explicit player calls so the same phase is not played twice. Bound simultaneous explosion voices during chain kills; preserve volume settings, alarms, music and defeat cue. Do not synthesize an extra gameplay hit or reward signal just to trigger sound.

Suggested initial global cosmetic caps: 12 ordinary composed explosions plus 1 reserved player/boss hero slot, 8 falling-aircraft smoke sources, 48 burning-fragment heads, 256 fragment-trail puffs, 12 optional wreck visuals, 32 optional physical debris bodies total and 4 shared real flash lights. Most burning heads should be kinematic cosmetics, not rigid bodies. Start each ordinary event with 3–6 heads, 8–16 core/spark particles and a strictly bounded share of the global puff pool; use less detail for distant kills. These are tuning targets, not measured safe GPU limits. Do not stack these on top of the old 16-explosion system; replace or adapt it coherently. Under overload reduce head count/puff density for distant events while keeping a readable nearby trail motif and reserved hero capacity.

Prewarm shared resources/pools during existing loading/world preparation. Reuse meshes, curves and materials; maintain bounded buffers. Pool reset must clear particles, transforms, old owners, timers, audio leases and phase identifiers. A reused slot must not receive an old callback. When overloaded, reduce distant smoke/debris first. Preserve a minimal readable flash for visible deaths and reserve capacity for the player's final crash.

Effects must pause with gameplay. Use an explicitly pausable gameplay-effects root and simulation-time lifetimes; an ALWAYS autoload must not advance death particles, wreck physics, shader lifetimes or delayed callbacks behind pause/settings/upgrade screens. Do not solve boss-pause visibility by making every effect ALWAYS. Boss decision currently pauses immediately: preserve that timing, make the initial destruction state visible before the pause, and allow later cosmetic stages to resume only with normal gameplay. Do not hold boss rewards or a decision modal hostage to a multi-second cinematic.

At RESULTS the battlefield may intentionally remain frozen behind the existing overlay. At Retry/Menu/Loading clear all prior-run explosions, trails, wrecks, debris, sound/light owners and pending callbacks. Add explicit transient grouping or a central clear method to UIFlow rather than assuming the old wreck containers are already covered. Do not require an expiry timer to fire while the tree is paused to clean up a run.

Respect Reduce Flashes both at spawn and while an effect is active: reduce core size, intensity, rapid flicker and real-light energy while keeping the fire/smoke silhouette. Screen Shake Off remains off. Do not add global exposure pumping, a full-screen flash, chromatic aberration or uncontrolled camera movement. Keep enemy projectile cores, attack tells, pickups and navigation readable through smoke.

8. VALIDATION AND DELIVERY

Use ZIVA_TEST_DATA_DIR and existing tools/run_menu_checks.py conventions. Never use the player's real save for verification. Add meaningful focused tests and rendered captures; do not claim a headless pass proves the visuals.

Test light and heavy ground vehicles, Scout Buggy, drones, enemy helicopters/VTOLs, an explosive modifier, boss, and all player aircraft. Test direct hits, burn kills, two simultaneous lethal hits, chain explosions and cleanup/despawn without a kill. Retirement/despawn must not become a death explosion or award loot.

Prove each death settles score/loot/XP once, releases slots once, emits each visual phase once and creates no extra damage. Ground tanks remain grounded. Airborne timeout has no fake ground dust/wreck. Surface crashes use the correct point/normal. No invisible active collider, targetable wreck, shooting corpse, orphan smoke or endless falling actor remains.

For the player test low altitude, high altitude, wall/roof/terrain contact, timeout breakup, repeated lethal damage during descent and held fire/Super/flaring input. Assert one final player_died and one run settlement. Verify the impact hold and results flow, then Retry/Hangar/Menu. Use and adapt tests/test_death_animation_and_flow.gd and the existing render_death_animation_preview.gd/render_death_screen_preview.gd after checking their current assumptions. Do not weaken once-only or navigation assertions just to make the new presentation pass.

Test pause/settings/Reduce Flashes during descent, after impact and while smoke is active. Test simultaneous boss and player death, boss decision during other protected menus, and at least five death/retry cycles. Modal ownership and results priority must remain correct. No effect may unblock gameplay input by changing GameManager state itself.

Create a small reproducible showcase with frame captures around initial flash, departing burning fragments, fully curved smoke trails and rapid fade, plus real town-camera captures. At the middle frame, several separate dark curved trails with hot tips must be clearly visible: a vertical smoke plume alone fails the reference comparison. Include optional wreck captures separately so they are not confused with observed reference details. Compare the same camera/seed/population before and after. Test the trail simulation at different frame rates and after a forced hitch; puff density and arc motion should remain consistent and capped. Record renderer, resolution, hardware, sample duration, median/p95 frame times, peak effect/head/puff/light/debris counts and post-cleanup counts. Run a sustained chain-kill scenario after warm-up and check memory/resources plateau. Report measured limits; do not promise 60 FPS or claim an exact match to the reference without evidence.

Deliver the implemented scenes/scripts, changed-file list, profile settings, per-family coverage checklist, rendered captures, test results and any unresolved limitations. Document how a future enemy model supplies its death family and wreck parts. Keep live enemy AI, menu redesign, damage balance, environment textures and unrelated features outside this pass.
