# Enemy pursuit and wave progression — 19 October 2026

Implemented in the existing Godot project. Ziva's localhost bridge on port 7012 was unavailable; validation used the installed Godot 4.7.1 executable directly.

## Behavior

- All offensive enemy variants approach the player before their weapon behavior runs. Initial planar acquisition range is 90% of the variant's engagement range, clamped to 18–60 m. A 12 m release margin prevents rapid switching at the edge.
- Enemies move during the two-second entry window but cannot shoot. Entry time no longer depends on whether a subclass changes its behavior state during startup.
- If the player escapes the release radius, enemies cancel warnings/bursts, release attack permissions and pursue the new position. Interceptors reset their ingress and gunships reset their attack setup.
- State transitions reset their elapsed time. Ground recovery timers and aircraft-controlled recovery phases no longer override one another.
- Attack gunships complete their full warning before firing and retain their separate break-away/reposition phases.
- Ground units follow clear streets without treating adjacent buildings as destinations for avoidance. Shorter vehicle probes and blended steering retain forward progress while navigating real obstacles. Air roof-clearance behavior remains active.
- Support drones keep their ally-support behavior; suicide and mine enemies retain their specialized attacks after approaching.

## Progressive difficulty

Newly spawned enemies snapshot their wave strength. Normal difficulty multipliers:

| Wave | Hull | Movement speed | Damage | Firing cooldown | Reinforcement interval |
| --- | --- | --- | --- | --- | --- |
| 1 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |
| 5 | 1.28 | 1.048 | 1.10 | 0.93 | 0.90 |
| 10 | 1.63 | 1.108 | 1.225 | 0.8425 | 0.775 |
| 20 | 2.33 | 1.228 | 1.45 | 0.68 | 0.60 |
| Eventual cap | 2.40 | 1.24 | 1.45 | 0.68 | 0.60 |

Casual/Hard adjust hull and damage strength to 0.85/1.12 of the Normal profile. Existing enemy modifiers remain additive to this progression. Warnings, projectile speed, burst sizes, wave gates, variant caps, and the 40-unit population ceiling remain in place. Reinforcement cadence still respects each wave theme. Boss wave 10 keeps reduced simultaneous attack permissions; endless waves restore the later-wave four air/three heavy permissions.

Enemy damage scaling is captured once in DamageData construction, so reusing hit data for blast victims cannot compound its multiplier. Player damage is unaffected.

## Validation

- `tests/verify_enemy_pursuit.gd`: **66/66** checks, including all 23 shooting variants approaching before firing, entry protection, wave progression, spawn-time stats, damage attribution, gunship warning duration, chasing an escaping player, cover, roadside navigation, and pause behavior.
- `tests/test_enemy_combat_intelligence.gd`: **6/6** predictive aiming, turret tracking, flank variety, reactive jink and boss lead checks.
- `tests/test_enemy_wall_avoidance.gd`: **4/4**. This older fixture omits a ground floor and manually advances custom logic in addition to normal physics; it is supplemental steering coverage. The new suite and live encounter exercise full physics on actual floors.
- `tests/test_enemy_spawning_and_movement.gd`: **4/4**. Fixed the fixture's invalid reference after a suicide drone completed its attack.
- `tests/render_enemy_pursuit.gd`: **passed** in the rendered main game. A technical truck, rocket buggy, attack gunship and hunter drone spawned 80–105 m away and each approached and fired. Observed first-shot 3D distances were about 33 m, 38 m, 40 m and 10 m respectively. All entry timers had expired before firing.
- No script errors in the final runs. Some headless fixture runs report ObjectDB cleanup leaks at exit; the final rendered run exited cleanly. This pass does not certify the concurrently edited menu flow or a frame-rate target.

Rendered captures: `artifacts/enemy_pursuit_approach.png` and `artifacts/enemy_pursuit_combat.png`. Logs are in `artifacts/strike-*.log`. Before-change copies of every modified existing file are in `.codex-backups/enemy-pursuit-20261019/`.

Changes are confined to enemy AI, enemy hit strength, wave attack permissions, enemy replenishment cadence and their verification fixtures. Concurrent gameplay/menu work was preserved.
