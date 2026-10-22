# Final ground vehicle implementation verification

Checked 2026-10-23 against the user's pasted implementation requirements, current production files, Ziva MCP project information, and independent rendered Godot tests.

**Verdict: both vehicles are integrated and functional, but the complete requested implementation is not finished.** Four issue categories remain, producing ten failed checks across the two vehicles. This verification changed no production scripts, scenes, or assets. The new audit and this report are verification artifacts.

## Verified working

| Requirement | Evidence |
| --- | --- |
| Exactly seven active ground vehicles | Roster test passed; 9,600 wave/theme selections respected enabled variants and wave gates |
| Eight old ground variants stay disabled | Public spawning rejects all eight; retained ground roles remain selectable |
| Original model preservation | All twelve original inspected GLBs still match the saved SHA-256 hashes |
| Correct production visual and AI routing | Both instantiate through `EnemySpawner.spawn_enemy_type`; actual ground classification and correct models verified |
| Four Raptor / six Desert wheels | Verified on production-spawned enemies |
| Shared wheel Mesh and Material identities | Both production rigs reference the same `universal_wheel_mesh.res` and surface material |
| Body orientation and Raptor gun/muzzle direction | Source forward and movement forward agree; actual cannon and marker forward agree |
| Articulated weapon basics | Existing suite verifies elevation limits and repeated drift-free Raptor recoil |
| Eight Desert launch outlets | Markers present, alternate pods, queries preserve index, actual shot advances one tube |
| Actual missile behavior | Desert emits `enemy_rocket`, missile damage type, speed 78, blast radius 3.5 |
| Actual damage to player | Swept projectiles from both variants reduced the fixture player's health |
| Autonomous combat | Real enemy brains independently navigated windup and emitted shots: six Raptor rounds and four Desert missiles in the observed seven-second windows |
| Ground collision | Both remained on a real StaticBody3D collision floor during autonomous combat |
| Death and collection | One ground kill per death, one coin pickup, correct physical XP amounts (4/6), no immediate death XP, collection awards XP once |
| Existing handling/stability checks | Helicopter handling 16/16; gameplay stability and upgrades 20/20 |

## Confirmed defects

### 1. Mechanical reachability does not gate the final shot

**Priority: high.** `src/enemies/procedural_raider.gd:154` checks line of sight when windup completes, then fires at line 169 without checking the current `is_aligned` result. That result is only checked later in the attack-readiness branch at line 211. The burst branch at lines 180–182 similarly checks obstruction without checking current mechanical reachability/alignment.

Independent reproduction for each new vehicle: place the target above the turret's elevation limit during the final windup interval. The turret correctly returns `false` for reachability, but the enemy still emits one projectile. Projectile velocity is aimed directly at the target, so it can leave in a direction the weapon cannot physically reach.

Required correction: verify reachability/alignment against the actual committed shot direction at emission and on burst rounds. Keep warning/aim commitment and selected muzzle consistent. Cancel or defer impossible shots and release/resume attack slots safely.

### 2. Wheel rotation uses incorrect radii and omits elite visual scale

**Priority: medium.** `src/enemies/ground/multi_axle_wheel_controller.gd:13` defaults to radius 0.58. Neither new scene overrides it. Line 108 multiplies only by enemy-root `scale.x`; elite scaling is applied to Visuals by `BaseEnemy`.

Measured from the actual shared mesh and production wheel transforms:

| Vehicle | Controller radius | Actual wheel radius | Actual radius with Visuals ×1.2 |
| --- | ---: | ---: | ---: |
| Raptor | 0.5800 | 0.6868 | 0.8241 |
| Desert | 0.5800 | 0.6359 | 0.7631 |

Consequently the wheels spin too fast for traveled distance, with a larger mismatch on elite variants. Standard Raptor/Desert spin rates are approximately 18%/10% too fast; with elite visual scaling approximately 42%/32% too fast.

Required correction: calibrate per-vehicle radii and include the relevant visual/ancestor world scale exactly once, preferably deriving the effective rolling radius from the actual wheel configuration/transform. Preserve the shared Mesh/Material.

### 3. Requested chassis dynamics are missing from both new rigs

**Priority: medium.** Each new scene's Visuals node runs only `MultiAxleWheelController`. `HullModel` has no motion controller or `ChassisMotion` hierarchy, and the builder only reparents Visuals/Turret. The wheel controller rotates wheel pivots; it never animates hull pitch or roll.

Independent production hierarchy inspection confirms that neither new vehicle attaches a chassis controller. Existing tank chassis animation does not automatically apply to these rigs.

Required correction: add restrained movement-driven acceleration/braking pitch, cornering roll, and damped settling while maintaining wheel contact and synchronized turret seating. Preserve physical collider transforms.

### 4. Death rewards ignore configured vehicle scores

**Priority: medium.** `src/combat/damage_receiver.gd:187` emits a hardcoded 50-point score for all enemies instead of the enemy's configured `score_value`.

Actual EventBus settlement payloads:

| Vehicle | Configured base score | Emitted base score |
| --- | ---: | ---: |
| Raptor | 140 | 50 |
| Desert | 210 | 50 |

The observed run-score increase was 55 after the current combo multiplier. The audit captures the base EventBus payload separately so combo effects cannot explain the mismatch. Kill count, coin collection, and physical XP checks passed.

This is a shared death-settlement defect that also affects other enemies. Required correction: emit authoritative configured enemy score, preserving once-only settlement and zero immediate XP.

## Test results and reproduction

- Existing rendered integration suite: **64/64 passed**. Its showroom uses a visual plane without a physics floor; it primarily checks hierarchy/controller methods and does not establish full gameplay acceptance.
- Active roster verification: **passed**, including 9,600 selections and disabled public-spawn rejection.
- New independent rendered requirements audit: **39/49 passed, 10 failed**. The failures correspond to the four categories above; nonzero exit status is expected until production defects are fixed.
- Helicopter lateral/turn handling: **16/16 passed**.
- Gameplay stability/upgrades: **20/20 passed**. An intentional invalid-upgrade rejection warning is part of that suite.
- Completed rendered audit had no parser/runtime errors. Its failures are requirement assertions.

Run the independent audit with an isolated save profile:

```powershell
python tools/run_menu_checks.py --rendered --script tests/verify_final_ground_requirements.gd
```

Evidence:

- `tests/verify_final_ground_requirements.gd`
- `artifacts/final-ground-requirements-audit.json`
- `artifacts/menu-repair-tests/verify_final_ground_requirements-rendered.log`
- `artifacts/audit-raptor_raider-rig.png`
- `artifacts/audit-desert_barrage_rover-rig.png`
- `artifacts/menu-repair-tests/test_seven_ground_vehicles_integration-rendered.log`
- `artifacts/menu-repair-tests/verify_active_ground_roster.log`

## Limits of this verification

The autonomous combat tests use production enemies, collision, projectiles, damage, loot, and event settlement in an isolated arena with a stationary player fixture. They are not a full representative city-wave performance benchmark. Frame-time regression, all terrain/road-clearance cases, exhaustive pause/teleport/pooling behavior, and complete visual minimap acceptance remain unverified. Minimap source does classify both new IDs as ground through EnemyData's family field.

AGENTS.md currently describes all seven as fully verified. That claim is stronger than the observed implementation: the defects above remain reproducible. No guidance file or production behavior was changed during this check.
