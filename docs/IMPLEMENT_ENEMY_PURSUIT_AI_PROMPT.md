# Enemy pursuit and shooting implementation prompt

Prepared from the current project scripts on 17 October 2026. This turn reviewed
code; it did not run a new AI playtest or change gameplay. Behavior and tuning below
are proposed for this game, not claims about the reference games' internal code.

Copy the prompt below into the coding AI working in this Godot project.

---

Implement more persistent, readable enemy pressure in ZIVA HELI TOWN HELLL.
Work in `C:/Users/Prime 3/Documents/ziva-heli-town-helll`.

I want the feeling of Megabonk's advancing hordes combined with varied ranged
encounters inspired by Risk of Rain 2, adapted to a helicopter fighting through
a destructible town. Enemies should enter near the action, acquire the player,
approach useful attack positions, shoot with readable timing, and follow when the
player moves. The town should remain important as cover and navigation space.

Implement and verify the behavior in the real game. Keep explanations simple.
Do not stop at a plan, merely increase enemy health/count, or make every enemy
use the same movement and firing routine.

## 1. Inspect the existing systems before editing

Read these current files and their callers:

- `src/enemies/enemy_spawner.gd`
- `src/enemies/base_enemy.gd`
- `src/enemies/enemy_data.gd`
- `src/enemies/procedural_raider.gd`
- `src/enemies/air/*.gd`, `ground/*.gd`, `support/*.gd`, `boss/*.gd`
- `autoload/combat_director.gd`
- `src/world/urban_pathfinder.gd`
- `src/combat/projectile.gd` and `damage_receiver.gd`
- `scenes/main_game.gd`, `src/player/player_helicopter.gd`
- Existing spawning, pathfinding, combat, damage, pacing and performance tests.

Reuse working navigation, damage, wave progression, score and loot systems.
Keep the current art, player controls, HUD and renderer intact except where small
attack indicators are necessary. Resolve any startup/import problems before
collecting baseline results, preserving the original player assets.

Code observations to verify against current files:

- Spawning already uses player-centered 62–95 m candidate distances, 2–4-unit
  approach sectors, collision checks and a 40-enemy population ceiling. Do not
  recreate these systems. Final post-snap safe distance and camera visibility
  need explicit checking.
- Normal population targets begin at 5, 7 and 10. Tuning pressure should consider
  engagement time and attacker mix, not just maximum population.
- Ground street navigation and stuck recovery already exist. `nav_has_los` in
  BaseEnemy is a horizontal vehicle-height clearance ray, but some weapons use
  it as firing permission. Driving clearance and muzzle-to-helicopter visibility
  must be separate.
- ProceduralRaider has role movement and firing logic, often with a 120 m attack
  range. A distant unit may fire well before it reaches its desired engagement
  band. Review this deliberately for each role.
- Escort-fighter movement combines a sinusoidal approach term with strong tangent
  movement; it needs a reliable close-in phase before any attack pass/orbit.
- AttackGunship can leave SETUP after 2.2 seconds without an attack slot. Remove
  this permission bypass; waiting enemies should continue useful movement.
- The director shares one timestamp dictionary for air/heavy leases and uses wall
  clock expiry. Check multi-resource ownership, release and pause behavior.
- Predictive targeting needs a near-zero quadratic-coefficient guard when target
  and projectile speeds are similar. Turret visuals and real firing direction
  must agree.

## 2. Define the actual encounter loop

Player deploys safely → short opening grace → small enemy groups enter → enemies
acquire the active player → approach or flank toward a useful firing position →
telegraph → fire → recover/reposition while retaining pursuit.

Treat movement and weapon readiness as related but independent decisions. Waiting
for cooldown or an attack permission must not leave an enemy stranded. Light
skirmishers may move while firing; artillery may deliberately brace. Keep attack
runs for aircraft that need them, while ordinary pursuers remain engaged.

Use explicit, observable behavior states such as ENTER, PURSUE, POSITION, WINDUP,
FIRE, RECOVER and DEAD, mapped to the existing architecture where possible.
Do not force a new monolithic state machine onto every role. Record why a unit is
not attacking: out of range, blocked shot, turning, cooldown, entering, no target,
waiting for permission or no reachable position.

## 3. Player start and safe enemy spawning

- Keep player deployment in a verified clear position at the existing valid flight
  height. Start enemy scheduling after the player, camera and world are ready.
- Preserve a roughly 2-second Normal opening grace as the first tuning baseline.
  A retry/new run resets director state, references, projectiles and leases. Do
  not introduce a new respawn mechanic; if an existing respawn exists, reacquire
  the new player and apply its existing protection rules.
- Generate enemy candidates around the player's CURRENT position. Prefer varied
  approach sectors and reachable intercept routes, including sectors ahead of a
  moving player, rather than building an endless trailing queue.
- Start by evaluating the existing 62–95 m ring. Validate after lane snapping and
  altitude adjustment. Use a configurable planar exclusion radius (start near
  40 m and tune for camera/role size), valid map bounds, support beneath ground
  units, hull clearance and an actual path for ground units.
- Prefer spawns outside the camera frustum with a margin. If a visible spawn is
  necessary, use a visible entry cue and a short non-attacking entry period.
  Spawning behind a building does not permit a unit to appear inside it.
- Use actual hull size, including elites, in clearance tests. After bounded failed
  attempts, defer and try another sector; never use an unchecked fallback at the
  origin or on the player. Enforce caps on every runtime spawn route.
- Keep replenishment in small groups. Spread work across frames and avoid a huge
  synchronous collision-query burst at the beginning of a wave.

## 4. Persistent pursuit suited to a helicopter

- Acquire the player promptly; reacquire if the instance changes. Stop attacks
  when the player is dead, the run ends or gameplay is paused.
- Outside engagement distance, closing toward a reachable firing position has
  priority over circling, lateral weaving and random movement.
- Re-evaluate destinations as the player moves. Ground units pursue road positions
  that can shoot at the helicopter, not the helicopter's airborne coordinates
  or an unreachable point directly beneath a rooftop.
- Separate horizontal navigation distance from 3D weapon range and elevation.
  A tank can fire upward when the muzzle ray is clear, even if a horizontal road
  ray is blocked. A clear driving route alone must not authorize a shot through
  an elevated obstruction.
- If cover blocks a direct weapon, choose a nearby reachable firing position with
  line of sight. Hold a useful flank briefly rather than picking a different one
  every frame. Avoid repeatedly aiming at a wall or endlessly trying an unreachable
  rooftop target. Reconsider routes when destruction changes obstruction.
- Give units stable personal offsets and local separation so they do not all
  target exactly one point. Use spatially bounded neighbor queries. Keep vehicle
  turning limits, street clearance and the existing unstick recovery.
- Detect actual lack of movement/progress over time, excluding deliberate firing
  holds. After roughly 1.5–2 seconds stuck, replan or use a bounded recovery maneuver.
  Persistent unreachable offscreen units may retire without rewards and be
  replaced legally. Never teleport visible enemies onto the player.
- The player cruises around 36 m/s, with aircraft variations. Do not make slow
  tanks magically catch a fleeing helicopter. Use routes, ranged threat and new
  entry sectors to sustain pressure. Fast drones may intercept; the player should
  still be able to escape a particular attack by maneuvering.

## 5. Give the existing roster distinct jobs

Use data-driven role defaults and per-variant overrides. Proposed initial PLANAR
engagement bands, to be tuned against actual 3D reach, map scale and camera:

| Role | Example existing units | Movement and attack | Starting band |
|---|---|---|---|
| Close pursuer | hunter_drone, scout_drone | Close reliably, then short lateral movement and light bursts | 18–30 m |
| Mobile shooter | technical_truck, scout_buggy, assault_apc | Drive toward a clear road firing position; shoot while moving where appropriate | 25–45 m |
| Ground heavy | flak_tank, siege_tank, gatling_heavy | Advance deliberately, telegraph a stronger volley, recover | 35–65 m |
| Ranged specialist | sam_launcher, rail_crawler, mortar_crawler | Establish a clear attack position; slower dangerous attacks with strong cues | 55–85 m |
| Attack aircraft | attack_gunship, attack_wing, escort_fighter | Close first, commit to a finite pass, break briefly and return | 25–55 m approach band |
| Support | shield_drone, repair_drone | Follow useful allies near the fight; reposition/reacquire if allies die | Relative to ally |
| Suicide threat | kamikaze_drone | Visible approach and committed dodgeable charge | Collision/charge role |

Keep flame attacks short-range and bombers aligned with their actual attack volume.
Do not make a ground explosion threaten an aircraft at any height automatically.
Define whether each weapon is direct fire, anti-air proximity, guided missile or
ground area denial; its damage must match that definition.

Use range hysteresis: enter engagement at one distance and resume full pursuit at
a somewhat larger distance. This prevents rapid pursue/stop/pursue oscillation.
Retreat only far enough to restore minimum range; do not back away indefinitely.

## 6. Make every shot believable, threatening and dodgeable

- Require a valid player, correct 3D range, appropriate muzzle alignment, cooldown,
  entry protection expiry and the required attack permission.
- Check the actual muzzle-to-aim-point path for direct fire. Recheck each burst
  round; do not fire a stale burst through cover that moved into the way.
- Use a short visual/audio cue for ordinary volleys, and a stronger cue for rockets,
  rail attacks, charges and artillery. Starting values: approximately 0.2–0.4 s
  light windup, 0.5–0.8 s heavy windup and 0.8–1.2 s sniper/rail warning.
- Commit dangerous aimed shots near the end of the warning, leaving a final
  response window. Do not perfectly retarget a committed rail shot each frame.
  Light weapons can track but need finite turn speeds and reasonable spread.
- Use limited prediction, not perfect future knowledge. Start common weapons
  below the current near-perfect lead where necessary; bound prediction time,
  handle zero/near-zero math cases, and tune from moving-target tests.
- Keep ordinary shots non-homing. Guided weapons need explicit warning, finite
  turn rate and lifetime, countermeasure behavior, and a dodgeable trajectory.
- Tune projectile speed together with range and cue time. At short range, very
  fast projectiles need a meaningful pre-shot cue; simply painting a bright tracer
  does not make an otherwise instant hit dodgeable.
- Spawn at actual muzzle positions. Make visible barrel direction agree with
  projectile direction; do not launch sideward bullets from an unturned turret.
- Verify collisions along movement segments for fast shots, shooter exclusion,
  environment blocking, team/friendly-fire rules and damage delivery. For area
  damage, explicitly decide cover occlusion and vertical reach so walls/roofs do
  not produce surprising invisible hits.
- Cancel pending attacks and release permissions when the enemy dies, loses its
  valid target, is interrupted or leaves the scene. Pause freezes combat timers.

## 7. Maintain pressure without an unreadable firing wall

Keep population and simultaneous dangerous attacks as separate budgets. Preserve
the 40-enemy maximum as the initial ceiling. Increase engagement reliability first;
then test Normal early targets around 8, 10 and 12 as a proposed tuning pass, with
Casual and Hard still differentiated. Record and justify changes to older exact-
number specifications and tests.

Ordinary low-damage pursuers should not all wait behind one heavy-attack slot.
Use affordable light-attack cadence and projectile limits while limiting major
volleys, rail shots and guided missiles. Begin with one simultaneous major warning
early and scale carefully after playtesting. Stagger cooldowns so groups do not
fire on the same frame; avoid exact synchronized rings around the player.

Repair permission ownership: no timeout bypass, no dead holder, no indefinite
starvation. If multiple budgets are required, grant them atomically or release a
partial acquisition immediately. Use per-budget leases or explicit attack tokens
with pause-aware expiry. When a lease expires, the corresponding attack must
actually cancel or reacquire; removing bookkeeping alone is insufficient.

Waiting units keep pursuing or positioning. Increase danger through role mixtures,
arrival cadence and readable overlapping patterns before multiplying health and
projectile speed. Preserve wave/upgrade pauses, bosses, rewards and difficulty
settings; do not convert the whole run structure into a different mode incidentally.

## 8. Structure and performance

Put reusable targeting, shot visibility and attack validation in shared helpers.
Keep variant decisions data-driven: behavior role, range band, approach speed,
repath period, windup, cooldown, burst count, prediction, separation radius and
attack-budget cost. Avoid adding a separate contradictory copy for every enemy.

Run physics movement at the physics rate. Stagger expensive perception/path queries
across agents, initially around 5–10 Hz for perception and 2–4 Hz for path refresh,
with event-driven updates where needed. Keep final shot validation timely. Cache
the player reference, use bounded neighbor queries, and avoid full-tree searches
or A* for every enemy every frame. Preserve projectile/effect limits. Reuse pooling
where it already exists; add it only where profiling warrants the complexity.

Add a development-only view for state, target, path, movement goal, weapon range,
shot line, cooldown, permission ownership and reason for not firing. Use counters
for spawn attempts/failures, first engagement, path failures, stuck time, shots
actually emitted, landed damage and budget wait. Counting currently alive
projectiles is not a cumulative shots-fired measurement.

## 9. Verify outcomes in playable encounters

Use seeded tests with meaningful assertions and a rendered 60–90-second playtest.
Inspect existing tests before extending them; do not count moving velocity alone
or a toggled state flag as proof of useful combat.

1. Player stationary in an open area: pursuers spawned at 70–90 m begin closing
   within about 0.5 s after entry, reach an appropriate band and threaten the player.
   Measure actual progress and first valid attack time. Roughly 3–6 s for common
   pursuers is an initial open-area goal, not a universal tank/artillery deadline.
2. Player flying away: enemies update their pursuit/attack positions; incoming
   sectors maintain pressure without teleporting visible units or exceeding caps.
3. Building between enemy and player: direct shots are blocked; ground enemies
   use a legal route to a firing position; air enemies clear roofs safely.
4. Player hovering above a roof: ground vehicles stay grounded, choose valid firing
   positions and handle turret elevation limits without spinning under the player.
5. Player strafing/dodging: stationary exposure is dangerous, while responding to
   a telegraph can evade committed attacks. Report measured hit behavior rather
   than guaranteeing success from a constant alone.
6. Crowded junction: groups avoid persistent overlap, recover from obstruction and
   reach useful positions without passing through buildings.
7. Destruction changes cover: routes and muzzle visibility respond to the new
   geometry; no stale full-height obstruction or shooting through surviving cover.
8. Death during windup/burst, target loss, wave transition, pause/upgrade, restart:
   no late shot, leaked budget, stale target or wall-clock expiry during pause.
9. Spawn at boundaries and failed placement: caps and safe distance hold after all
   position adjustments; invalid candidates defer rather than forcing a spawn.
10. Test at 10, 25 and 40 enemies with comparable rendering/encounter conditions.
    Report CPU/frame time, path/raycast counts, projectiles and stuck incidents.
    Aim for the existing 60 fps target on the same hardware; report limitations.

Review existing tests including `test_enemy_spawning_and_movement.gd`,
`test_spawning_doc_spec.gd`, `test_urban_pathfinder.gd`,
`test_ground_unstick_and_wedging.gd`, `test_enemy_wall_avoidance.gd`,
`test_enemy_combat_intelligence.gd`, `test_enemy_damage_delivery.gd`,
`test_all_enemy_brains.gd`, `test_pacing_modes.gd` and the benchmark.
Run the relevant suite and adapt assertions only where this request deliberately
changes the design; preserve collision, lifecycle and budget invariants.

## 10. Deliver the implementation

Provide working code and tunable role data, a simple description of the new loop,
before/after encounter evidence, test/benchmark results and remaining limitations.
The result must visibly show enemies arriving, approaching, finding useful firing
positions, warning, shooting and following the moving player through the town.

---

Reference context: the official [Megabonk page](https://store.steampowered.com/app/3405340/Megabonk/)
describes horde survival, generated maps, loot and upgrades; the official
[Risk of Rain 2 page](https://store.steampowered.com/app/632360/Risk_of_Rain_2/)
describes fighting hordes of monsters in a 3D action game. The specific AI loop,
state design and tuning values above are recommendations for ZIVA, not reverse-
engineered implementations of either title.
