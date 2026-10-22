# Implement an autonomous encounter director for ZIVA

Work in `C:/Users/Prime 3/Documents/ziva-heli-town-helll`.

Implement a data-driven, credit-based encounter spawning system for this existing single-player helicopter action-survival game. Preserve its Nuclear Strike-inspired military combat, low-poly presentation, integrated ground vehicles, aerial enemies, wave progression and progressive difficulty. Deliver working code and gameplay evidence, not just a design.

Read the current AGENTS.md first. Reinspect current source before editing and preserve concurrent changes. This prompt supersedes the generic spawner proposal; do not import unrelated monster, multiplayer, stage-loop or elemental-elite systems.

## 1. Extend the existing architecture

Inspect at minimum:

- `autoload/combat_director.gd`
- `src/enemies/enemy_spawner.gd`
- `src/enemies/enemy_data.gd`
- `src/enemies/base_enemy.gd` and actual ground/air/support controllers
- `autoload/game_manager.gd`, event bus and boss/extraction flow
- The city generator, active camera, collision layers and threat indicators
- `src/player/xp_manager.gd`, physical loot settlement and `LevelUpUi`
- Existing spawning, encounter, roster and attack-slot tests

`CombatDirector` already owns waves, themes, population targets and pause-aware air/heavy attack leases. `EnemySpawner` already handles opening cohorts, replenishment, enabled-variant filtering, gates/caps and sector-based placement. Extend/refactor these responsibilities instead of installing competing global directors.

Keep one authoritative encounter state. Fast and slow purchasing streams should be components/data owned by the existing director, with spawning delegated to the existing spawner.

Replace the existing automatic opening/replenishment purchases when the credit system takes ownership. Never let legacy and new loops both fill the same population deficit. Preserve useful public spawning APIs and make their safety/eligibility contract explicit. Normal production spawns must pass shared cap/roster validation; isolated fixture bypasses must be explicit and non-production.

## 2. Preserve the actual roster and progression

Only these five ground vehicles are enabled:

| ID | Vehicle | Encounter role |
| --- | --- | --- |
| `scout_buggy` | Scout Buggy | Light mobile shooter |
| `assault_apc` | Assault APC | Armored carrier/mobile pressure |
| `rail_crawler` | Azure Siege Tank | Long-range precision rail threat |
| `siege_tank` | Desert Ironclad | Heavy cannon threat |
| `gatling_heavy` | Ironclad Sentinel | Rotary autocannon threat |

Keep `rocket_buggy`, `flame_tank`, `mortar_crawler`, `sam_launcher`, `technical_truck`, `flak_tank`, `missile_carrier` and `infantry_squad` disabled through both automatic selection and public spawning. Preserve their sources. Two future cars are not supplied yet; provide extensibility without inventing or enabling them.

Build aerial/support cards from existing enabled variants with working scene/controller routing. Include existing attack helicopters, attack planes/interceptors, drones and minelayers according to their actual IDs and gates. Do not turn the roster into drones only or infer new units from descriptive names. Inventory the supported air IDs in the implementation report.

Preserve all integrated models, shared wheels, articulated turret aiming/elevation, recoil, rotary barrels and chassis motion. Use exact `assets/Enemy/` path casing. Do not substitute procedural placeholders for supplied models.

Preserve wave gates, per-variant caps, current difficulty modes, early-wave learning protection, current themes, wave-clear events/repair, the wave-10 boss decision/extraction contract and endless progression after it. Verify the real boss flow before migrating spawning; no duplicate boss or timer-only boss completion.

## 3. Resource-based spawn cards and purchasing streams

Create typed Godot resources or an equivalent validated data layer for spawn cards and director tuning. Reuse authoritative EnemyData facts instead of duplicating them in another inconsistent roster.

Define stable card ID, variant ID, category, positive cost, selection weight, wave eligibility, allowed streams/themes, bounded group size, placement requirements and optional supported modifier. Validate unknown/disabled variants, malformed costs, impossible group sizes and conflicting rules at load/test time.

Use military categories such as light/mobile, heavy armor, attack aircraft, support and area denial. A group card pays for every member and reserves all relevant capacity before spawning.

Implement two independently budgeted streams:

- Fast stream: small, frequent purchases of eligible light/mobile threats and appropriate low-cost aircraft.
- Slow stream: saves for eligible tanks, attack aircraft and other existing high-threat units, with longer cadence and clear breathing room.

Use configurable intervals, credit rates, wallet caps, maximum purchases per evaluation and per-frame spawn-work limits. Treat “fast/slow” as tuning concepts, not permission to bypass caps or continuously flood the player.

Choose a weighted category with affordable eligible cards, then a weighted card. Empty categories must not stall valid alternatives. Define whether unaffordable heavy purchases save or fall back after a bounded wait; do not immediately spend the slow wallet on cheap units forever.

Commit spending only after a valid instance/placement succeeds. Reserve capacity and credits for pending/deferred work so both streams cannot overspend or exceed caps. Failed/cancelled members refund their exact reservation once. No negative wallets or infinite selection loops.

## 4. Difficulty economy tied to this run

Use active combat seconds, current wave and selected difficulty. Do not introduce completed-stage/save-based difficulty or multiplayer scaling into this single-player run.

Start with an explicit, tunable model such as:

`D = clamp(difficulty_factor * (1 + time_factor * active_minutes + wave_factor * max(wave - 1, 0)), D_min, D_max)`

`income_per_second = base_stream_income * D * theme_income_factor`

These are starting equations, not final balance values. Document units and calibrated parameters. Preserve existing EnemyData wave stat scaling unless measured tuning requires a documented change. Do not apply a second hidden damage/health multiplier through director credits or modifiers. Credit difficulty primarily changes purchase opportunities/composition within existing threat limits.

Evaluate income and purchases only during eligible ACTIVE combat. Freeze on pause, upgrade drafts, boss decisions and other non-combat states. No catch-up payout after resume, frame stalls or scene loading. Reset wallets, pending work, RNG state and reservations on a new run; cancel them on run end.

Keep current early population targets (starting around 5, then 7 and 10 before difficulty adjustments) as the initial pacing baseline. Preserve the existing hard population ceiling of 40, rather than targeting 40 immediately. Enforce total, family/category and variant caps at commit time, counting pending reservations. Boss/summoned units need an explicit consistent accounting policy.

Never dump accumulated credits as a surprise high-density wave after invalid placement or reaching the population cap. Use bounded banks, decay/overflow policy and capped release across multiple evaluations. Limit or suspend income at sustained cap according to documented tuning.

Do not add hypothetical holdout/exploration directors. Carry bounded balances through ordinary waves only if appropriate. Any future event transfer must be once-only, conserve credits, obey capacity and retain paced deployment; no instant spike on boss transitions or upgrade dismissal.

## 5. Spatial cohorts suited to a flying player and city streets

Extend the existing seeded approach-sector system. Keep one chosen sector for each small cohort so threats enter directionally instead of appearing randomly on every side. Limit cluster density and simultaneous sectors. Provide safe fallback sectors when one is blocked.

Current source uses a 40 m planar exclusion, candidate distances around 62–95 m, and a 25 m forward interception offset for moving players. Treat these as baseline values to measure, not universal constants. Account for helicopter speed, camera distance, model size and enemy weapon range before changing them. Recheck exclusion distance after street snapping and all placement adjustments.

Prefer positions outside the active camera frustum, testing the enemy's bounds rather than only its center. Ordinary instant spawns must not visibly pop into the viewport. If no valid hidden placement exists, defer; an intentionally visible entry requires a real arrival mechanism and non-damaging readable warning, not an arbitrary final-attempt bypass.

Ground placement must use valid drivable street/terrain corridors, adequate footprint clearance, correct surface height and a viable route toward engagement. Reject rooftops, building interiors, water/void where applicable, overlaps and inaccessible pockets. Avoid assuming all ground is Y=0.

Air placement must respect terrain/roof clearance, altitude bounds, map edges and aircraft turning/approach space. Preserve each aircraft's real engagement behavior. Minelayers must enter legitimately and must not materialize mines directly on the player.

Use bounded candidate attempts, cached queries where safe and deferred retries. Never spend an unbounded frame searching for a spawn.

Do not use the original proposal's universal 120 m despawn threshold: the Azure rail threat alone has 130 m weapon reach, and the helicopter moves quickly. Tune family-specific retirement distance, dwell time and hysteresis beyond relevant engagement/view ranges. Avoid retiring units engaged with the player, visible threats, bosses or mission targets.

Administrative retirement grants no XP, kill score, credits, loot or death-triggered effects. Release slot leases and population accounting cleanly. Keep existing airborne projectiles' ownership/lifetime valid. Prefer no economy refund initially; if measured tuning needs one, use a bounded once-only refund that cannot create a recycle loop. Do not pool complex enemies until reset correctness and profiling justify it.

## 6. Controlled variation and supported elites

Use a dedicated seedable encounter RNG. Avoid global random calls affecting selection or placement; record the seed and significant external inputs for reproductions. Reproduce the same decisions for identical seed, inputs and simulation steps; do not promise identical combat across arbitrary frame rates.

Select a small eligible composition pool per wave group, retaining enough light and air/ground options to keep gameplay viable. Reevaluate when new gates unlock so a run-start pool cannot exclude all later tanks or aircraft. Themes adjust weights, not eligibility or caps. Preserve the existing themed cadence and identities.

Armored Column favors the actual APC/tanks. Swarm Tide favors eligible light vehicles/drones without enabling infantry. An optional Aerial Frenzy may be a bounded, explicitly signaled composition variant only if tested; it must not replace mandatory boss/mission behavior or silently alter all existing waves.

Reuse only modifiers whose mechanics are actually implemented and verified. Existing enum entries alone are not proof of functionality. Prefer the current supported military elite/shielded behaviors with restrained visual identification. Do not add Blazing, Glacial, Malachite, Celestine or unsupported elemental affixes.

Elite purchases must be explicit costed cards/upgrades with gates, caps and controlled probability. Replace or coordinate the spawner's independent modifier roll so it cannot silently turn a purchased basic unit into an unbudgeted elite or stack modifiers twice.

Do not force an elite merely because the wallet is large. Do not convert a blocked boss/heavy purchase into an entire-wallet elite horde. If a desired purchase is unavailable, wait, choose a bounded legal alternative or retain/decay credits according to policy. Ordinary directors cannot purchase duplicate milestone bosses.

## 7. Fair attacks independent of population

Preserve and extend CombatDirector's existing air/heavy lease scheduler rather than creating a second slot system. Honor variant requirements, including units needing both lease types. Acquire/release atomically where necessary; release on death, retreat, cancellation, retirement, timeout and run reset. Waiting units should maneuver, not freeze or fire without permission.

Keep wave-dependent attack limits as the baseline. Heavy rail shots, cannon bursts, aircraft attack runs and missile locks must retain their actual windup, commitment and cooldown. Respect tank elevation/reachability limits; directors do not authorize firing through impossible aim solutions or cover.

For a new off-screen damaging attack, provide a clear directional threat warning and configurable preparation window, initially around 1.5–2 seconds for heavy/missile threats. Integrate with existing indicators and state machines; do not stack duplicate countdowns or apply the same delay to every bullet. Define how warning/leases behave on pause and when the target becomes invalid. Avoid displaying an indicator per enemy every frame.

Spawning is not a substitute for pursuit AI. Verify vehicles/aircraft can approach a valid engagement band, acquire a permitted attack, shoot and reposition without spawn-only inactivity.

## 8. Preserve XP, UI and rewards

XpManager remains the authoritative run XP/level/draft queue. Award XP only through valid physical collection, never spawning, retirement or direct enemy death. GameManager.start_new_run resets it. RunProgression remains a compatibility mirror, and LevelUpUi remains the production overlay.

Director banks are encounter credits, separate from player money/score/XP. Never mutate player economy to pay for spawns. Preserve resource cards, real weapon/controller effects and draft pause behavior. Spawned enemies retain their intended loot; retired enemies yield nothing.

## 9. Verification and delivery

Add focused tests for:

1. Income/spending conservation, reservations, failed placements, refunds, caps and bounded work.
2. Two streams share population constraints without starving heavy purchases or doubling legacy replenishment.
3. Wave gates, five active ground models, disabled-type rejection and eligible air inventory.
4. Fixed seed/input reproducibility and varied composition across seeds.
5. Sector coherence, post-snap exclusion, hidden placement, footprint/altitude clearance and no-valid-position deferral.
6. Blocked-map/population-cap recovery without a banked spawn avalanche.
7. Pause, level-up, boss decision, death, retry and scene-transition cancellation/reset, with no catch-up spending.
8. Wave-10 boss uniqueness/clear conditions and endless progression.
9. Attack lease cleanup, combined-slot handling and real off-screen warnings.
10. Administrative retirement gives no rewards, splits, explosions or stale leases.
11. Real kill → physical loot → collection → XpManager → one draft per gained level remains intact.

Run relevant existing suites; do not blindly satisfy stale full-roster tests by enabling disabled enemies. Update obsolete assumptions explicitly while preserving meaningful coverage.

Demonstrate at least 60 seconds of active moving/firing early Normal combat, a bounded invalid-placement recovery, a real paused draft/resume, an advanced-wave encounter and boss transition. Verify all five integrated ground rigs still move, aim and fire properly. Use isolated test persistence, not fake rewards/deaths written to the user's save.

Record seed, wave/theme, both wallets/income, eligible cards, purchases/rejections, active/reserved populations, spawn sector/distance, active attack leases and retirements in bounded debug telemetry. Keep it out of normal release HUD. Compare frame-time median/tail and spawn-query work under equivalent conditions; report actual hardware/renderer context and limitations.

Deliver source/resources, tuning table with units, migration notes, test logs and rendered gameplay evidence. Explain remaining failures honestly. Do not declare the feature complete from resource definitions, passing isolated math tests or screenshots alone.
