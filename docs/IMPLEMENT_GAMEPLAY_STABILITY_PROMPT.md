# Repair playability, damage, health and death in ZIVA

Work in `C:/Users/Prime 3/Documents/ziva-heli-town-helll`. The user reports dying extremely quickly while the HUD appeared to show about 35% health. Diagnose and implement the repairs; do not stop after a plan or hide defects by making the player permanently invulnerable. Read AGENTS.md, recheck current files and preserve concurrent work, enemy assets and shared-wheel conventions.

Read `docs/GAMEPLAY_AUDIT_2026-10-21.md` and its actual logs first. It distinguishes runtime reproduction, source inspection, conditional risks and unverified user-specific causes. Do not state that the exact user's incident is solved until an equivalent case is reproduced and verified. A screenshot of 35% health does not itself prove authoritative health was positive at death.

## 1. Establish a reproducible baseline

Record the current aircraft/loadout, selected difficulty, scene, seed, active upgrades, wave, hull/max hull, fuel, shield/dash state, collision bounds and current GameManager state. Use an isolated test profile or intercept persistence for diagnostics; never settle fake deaths/rewards into the user's real save. Capture startup/parse errors before tuning balance. Check the real menu → loadout → loading → game → death/results → retry path, not only direct main-game scene loading.

Use a bounded damage history containing simulation time/frame, source ID/name/faction/type, incoming amount, wave-scaled amount, armor/resistance, protection flags, accepted damage, before/after hull, impact/contact ID, and resulting death/state transition. Record authoritative health and displayed health on the lethal frame and following render frames. Keep instrumentation gated, inexpensive and out of release-facing screens. Distinguish shell impact, blast, repeated scrape, enemy body contact, environmental chains, fuel starvation and a void fallback.

The audit's seed-21021 stationary/unarmed sample died around 8.98 s of run time, not the first second. Its last position was after the death animation. Do not misreport this as a live hover failure or a complete balance benchmark. Add real moving, firing and evasive runs.

## 2. Correct damage math before adjusting difficulty

Inspect `src/combat/damage_data.gd`, `src/combat/projectile.gd`, `src/combat/damage_receiver.gd`, `src/player/player_helicopter.gd`, `src/world/volatile_hazard.gd` and other actual damage producers. DamageData currently applies combat_damage_multiplier in its constructor; Projectile._explode then constructs a new DamageData from that already-scaled amount and the same attacker. Runtime proof: base 10 × 1.25 created payload 12.5, but a center blast dealt 15.625. Define whether payload damage is raw or resolved and enforce scaling once across direct hits, blast copies, status effects, salvo fragments, expired projectiles and chains. Preserve metadata/status attribution when cloning without reapplying attack bonuses.

Keep owner/faction/self-damage policy explicit across direct hits and area damage. Check each receiver at most once per explosion even when it has multiple shapes. Maintain valid falloff, cover and height rules consistently for environmental explosions where intended. Do not casually make every chain explosion globally harmless; identify deliberate self-damage versus accidental owner hits and document the chosen behavior.

## 3. Give player health one authoritative mutation path

Player hull is currently maintained by PlayerHelicopter, separately from DamageReceiver on enemies. Do not attach a second unsynchronized health authority to the player. Centralize accepted player damage, healing and death transitions, using structured source information and explicit protection reasons. Clamp accepted health to [0, max_hull] before emitting health changes. Route collision scrape through that path; currently it directly subtracts hull and bypasses is_invulnerable and armor. Controlled reproduction lost 4.4 hull in 12 contact ticks despite active invulnerability and 24% armor.

Audit all collision, starvation, hazards, projectile and forced-death paths. `_die()`/death animation/run settlement must be idempotent; repeated lethal events cannot pay out twice or restart dying. Prevent repair/pickup callbacks from silently reviving a dead terminal player. Keep a clearly logged exceptional rule for an actual terrain void if it bypasses normal hull; do not use that fallback to hide collisions or bad spawn placement.

Replace ambiguous invulnerability ownership with an explicit aggregated protection query or equivalent: shield, dash, entry/debug and dying reasons must not clear one another. Current dash completion unconditionally clears the shared flag even if shield time remains. Confirm shield-plus-dash timing, pause/resume and collision protection. Keep intended collision-resistance and armor semantics, with no accidental double resistance or bypass.

## 4. Repair collision pressure and contact classification

Current impacts can remove 15–50 ground or 20–60 wall hull, repeat after only 0.22 s, and stack with 22/25 hull-per-second scrape. These values explain why 35 hull can vanish in a legitimate damage calculation, but may make control recovery unreasonably harsh.

Classify terrain, building, enemy body, pickup, boundary and slope contacts using actual collider identity/layers and normal velocity. Do not label every non-floor enemy collision a Building Crash. Separate a new high-energy impact from resting contact and sustained scraping. Use a contact-aware cooldown/hysteresis rather than repeated full crash packets for the same unresolved contact. Avoid applying maximum impact plus an unbounded scrape packet several times during a single collision recovery.

As a proposed repair behavior, gentle touchdown/resting ground contact should not drain hull indefinitely; a real high-speed crash remains dangerous. Make thresholds and DPS configurable, with documented units and a measured maximum short-window burst for Normal. Keep escape/deflection controls responsive without bouncing the player into new full-damage packets every tick. Do not eliminate legitimate lethal hits just to guarantee survival from any state.

Inspect aircraft spawn height/ground intersection, collision dimensions and visual/collider alignment, enemies entering the rotor/body volume, boundary clamps, roof clearance and slow-frame integration. Do not infer those defects from a wreck's final position. Check actual live telemetry.

## 5. Make the HUD tell the truth immediately

Inspect `src/ui/hud.gd`, `src/ui/survival_hud.gd`, `autoload/event_bus.gd`, `autoload/game_manager.gd`, and the death/results UI. A controlled 35/100 → 40-damage hit starts dying at hull 0 while the label remains 35/100 until the next approximately 0.1 s poll; it reached 0/100 after 0.15 s in the fixture.

Update the primary health number/fill on authoritative events and on initialization/rebinding. An optional delayed damage trail may animate behind it but cannot substitute for the current health. Health must visibly reach zero before/with a lethal presentation. Keep hit indicators and damage numbers aligned to actual mitigated damage; show valid source/cause and distinguish fuel from hull. Refresh max-hull changes and repair together. Guard against duplicate HUD/player bindings after retry. Keep the 35%-health vignette as visual feedback, not a death condition.

## 6. Restore fair encounters without removing progression

After fixing math and collision defects, measure enemy hits in 0.25/0.5/1 s windows, approach ranges, warning readability, projectile speed, overlapping bursts, spawn grace, distance exclusions, permitted simultaneous attackers and wave scaling. Preserve variant identity, readable lead/commit windows and progressive challenge. Tune early Normal separately from later waves and Hard; do not compensate for a bug with a global damage divide or invisibly change every enemy's stats. If a short post-hit grace or aggregate damage budget is introduced, scope it to a documented player-survivability rule and verify environmental hazards and distinct attacks still behave intentionally.

Review fuel drain/starvation, dash/flared-missile availability, responsive movement and pause/input leakage. Check large frame spikes and CPU/GPU cost on the actual renderer. Report median and tail frame times under equivalent conditions, not a single FPS label in a paused screenshot. Do not redesign the environment, camera or imported assets just to fix damage unless a measured issue requires it.

## 7. Required evidence

Add meaningful regressions for: explosion scaling once; multi-shape receiver de-duplication; shield/armor/resistance across each player damage source; dash ending with shield active; harmless resting contact; one crash versus ongoing contact; repeated hits in the same frame; 35 hull with a sublethal hit staying alive; a valid lethal hit reaching exactly zero and dying once; healing after terminal death; zero-hull HUD in the lethal frame; retry reset; pause/fuel/void behavior and no save pollution from test runs.

Use representative aircraft/loadouts and seeded Normal encounters. Include at least 60 s of active moving/firing play, building contact and escape, missile avoidance, a pause/level-up/retry cycle, and an advanced-wave check. These are verification scenarios, not a promise that standing still unarmed must survive indefinitely. Preserve the existing relevant suites, inspect their assumptions, and do not disable entire combat systems in acceptance runs. Show before/after damage histories and a rendered gameplay demonstration. Report precisely which causes of the original complaint were confirmed, fixed or remain uncertain.

Deliver the actual source changes, focused tests, logs, validation and remaining risks. Complete this stability work before accepting the XP/card redesign as a playable release.
