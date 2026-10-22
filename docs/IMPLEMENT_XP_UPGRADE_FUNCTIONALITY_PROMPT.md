# Repair XP collection and make every upgrade mechanically trustworthy

Implement in `C:/Users/Prime 3/Documents/ziva-heli-town-helll` after the gameplay stability prompt. Read AGENTS.md, `docs/GAMEPLAY_AUDIT_2026-10-21.md`, current files and actual logs. Preserve existing enemy models/shared wheel resources, current profile progression and unrelated work. Deliver working systems with measured gameplay effects, not only renamed cards or changed variables.

## 1. Trace the complete XP path

Inspect `src/combat/damage_receiver.gd`, `src/enemies/base_enemy.gd`, enemy_data, `src/loot/loot_manager.gd`, `src/loot/pickup.gd`, `src/player/run_progression.gd`, `autoload/game_manager.gd`, event_bus, the HUD and any boss/special kill emitters.

Normal DamageReceiver death currently emits zero direct XP; LootManager creates physical gems from enemy specs. GameManager still awards positive direct kill XP when supplied, and gem pickup updates RunProgression without updating GameManager.run_xp. Audit actual live producers before asserting a default double-XP bug. Establish one authoritative run-XP ledger and explicit grant reasons/IDs. Physical gems should award run XP exactly once on valid collection; intended scripted XP grants must use an explicit path that cannot duplicate a kill gem.

Define exactly what is cumulative run XP versus within-level progress. Preserve or deliberately retune cumulative threshold semantics, overflow across multiple levels, MAX_RUN_LEVEL and no extra cards at cap. Negative/zero/malformed grants and wrong-run pickup callbacks must be harmless. Enemy death/loot settlement must not create duplicate drops on multiple hit, burn, chain or queued-free callbacks. Preserve legitimate boss/elite rewards and separate weapon-mastery XP from run XP.

## 2. Reliable collection with readable pacing

Use the existing magnetic pickup behavior rather than starting over. Current XP/coin effective magnet radius has an 85 m minimum, and kills within 140 m horizontal/50 m vertical can start immediate attraction. Measure feel at flight speeds/altitudes before increasing these further. Animate visible launch, acceleration, approach and absorption without stranding gems behind the aircraft or making the whole map instantly disappear into the player.

Award on confirmed collection through an idempotent state transition. Keep value conservation when merging nearby gems, including an already-attracting gem; no disappearing value, duplicate reward or independent merged object surviving with its old value. Merged gem appearance and reward text should reflect its current total. Separate awarded state from cosmetic fade so pause/death/scene teardown cannot award twice or lose an already-authorized grant. Ensure invalid/dead players and run transitions cannot attract/apply old-run drops. Bound pickup count, merge lookup, particles, audio voices and reward-toast frequency; pool only where profiling justifies it.

Record a simple kill/drop/collect ledger so a tester can prove value conservation across multiple real kills and physical pickups. No scenery XP unless explicitly intended. A multi-level burst must preserve surplus XP and the precise number of queued choices.

## 3. Make upgrade selection an atomic progression transaction

RunProgression.apply_upgrade_choice currently clears offers/consumes a choice before validating the name. Runtime proof: an invalid, non-offered name removed a queued choice and all current offers. Fix validation in the progression authority, not only in UpgradeDialog.

Use stable upgrade IDs and an offer/session token or equivalent current-offer identity. Validate active run, allowed state, queued count, membership, eligibility/caps, player/component validity and duplicate/stale input. Compute and apply the effect successfully before consuming exactly one choice and emitting a single result. Reject invalid/replayed selections without changing state, queue, stats or economy. The UI may disable itself while committing but cannot decide gameplay truth. Reconcile lost UI callbacks and retries without reapplying the effect.

Respect GameManager state ownership. Review MENU/PAUSED/EXTRACTION as well as current RESULTS/LOADING/BOSS_DECISION guards. Do not resume ACTIVE from an invalid upgrade callback while another modal owns pause or the run is over. Prevent current-weapon selection or held fire from leaking through 1/2/3/confirm inputs. Preserve the existing 0.35 s presentation delay and 2.5 s consecutive-choice breather unless measured testing justifies a documented UX adjustment. During an active choice, world/enemy/projectile/fuel clocks must freeze while modal UI operates. Define input release/safe resume behavior.

## 4. One upgrade catalog for truth, preview and presentation

Replace scattered name-match logic and separate `_benefit()` copy with a typed/catalogued definition per stable ID: title, icon key, category/rarity, stack/rank/cap, eligibility, components affected, numeric changes, temporary duration if any, prerequisites, effect handler and preview calculation. Use effective-stat resolvers shared by gameplay, card before/after values, HUD and reload/fire paths. Avoid modifying global GameConstants dictionaries per player/run.

Confirmed examples to repair or clarify:

- **Extended Mag:** currently multiplies remaining rounds. A 300-round MG became 390 until reload restored 300; at zero rounds the card left zero despite “Refill” copy. Proposed intended redesign: +30% magazine capacity per valid stack with a defined refill policy. Store an effective capacity modifier and use it for start/complete reload, pickup refill, overdrive, weapon switch, profile reset and HUD denominator. Verify the new capacity survives reload; do not merely increase current ammo or redefine it silently as permanent without updating the catalog/copy/tests.
- **Overclock Rounds / Hair Trigger / Speed Loader:** multipliers are consumed by weapon code. Verify real target damage, fired-shot interval and actual reload duration with fixed mastery/loadout/buffs; a dictionary change alone is insufficient. +25% reload speed means duration divided by 1.25, not necessarily 25% less time. Spell out units and cap interactions.
- **Reinforced Hull:** show both max-hull increase and actual repair, clamped correctly; update live max/current HUD immediately. Armor must affect real hits after damage-path repair.
- **Reactive Armor:** +6 percentage points up to 24%, not multiplicative “6% stronger armor.” Hide it at cap or show the exact partial final increment; never offer a zero-effect stack as a useful choice.
- **Turbine Tune / Salvo Overclock / Vector Jets:** respect drain/cooldown/speed floors and caps; preview the true attainable benefit. Compare actual fuel consumed, salvo ready time and measured flight movement, not just exposed fields. Don't offer a capped benefit with an inflated percentage.
- **Airstrike:** current effect touches all enemies while copy says nearby. Define a real range/target contract and implement it, or accurately label an intended global strike. Verify damage, cover/height/attribution as intended and reject unusable effects when appropriate.
- **Aegis Field / Field Repair:** honor real protection duration and healing state; a temporary shield cannot become permanent because a fallback sets a boolean. Healing cannot resurrect terminal death accidentally.
- **Ghost Rotor:** current label promises reduced drag, but inspected effect only multiplies cruise_speed. Implement a real, measured drag modifier with a defined effect or remove the unsupported claim. The same applies to evolution names promising a weapon pattern not actually implemented.
- **Evolution/legendary cards:** encode prerequisites and one-per-run constraints, avoid duplicates/capped/no-op offers, and define actual mechanics rather than relying on impressive flavor text. Keep cosmetic flavor separate from mechanically verified benefits.

Keep modifiers composable across run upgrades, hangar/loadout, weapon mastery, overdrive, shields and aircraft type. Reset run-only modifiers cleanly on retry. Do not permanently mutate shared materials, global config or saved aircraft stats as a side effect of an in-run card.

## 5. Prove effects end to end

The current XP/card test suite reports 6/6 but its “enemy calibrated drop” test manually spawns a value-1 gem, and its “physical collection” test directly calls add_run_xp. Those tests do not prove the real enemy death → drop → attraction → pickup → level → offer → selection path. Replace weak assertions with meaningful event-path coverage while preserving valid existing tests. Do not reintroduce double XP just to match obsolete comments.

Test each catalog effect for successful apply, once-only apply, caps, bad input and reset. Exercise all four weapons, reload after magazine upgrade, zero-ammo selection, upgrades while a reload/buff is active, full-health/near-cap choices, multiple levels from one pickup batch, empty eligible pools, death/pause/boss/extraction state transitions and gamepad/keyboard duplicate inputs. Measure actual bullets hitting a damageable target, fired intervals, reloads, hull, mitigation, flight speed, fuel and salvo timers. Keep unrelated enemies static only in isolated measurement fixtures; acceptance includes the real encounter loop.

Deliver catalog/resolvers, corrected XP and transactions, real gameplay effect tests and an honest per-card validation matrix. Feed these same data/preview APIs into the UI polish task. A professional-looking card whose effect is unimplemented must not ship.
