# Menu and run flow

Implemented 19 October 2026. Keep the military pixel-art presentation and simple player-facing labels.

## Ownership

- `UIFlow` owns scene transitions, the active loader, confirmation dialogs, menu return destinations, and the held-input release gate.
- `GameManager` owns the simulation state, pause/resume state, fresh run identity, and once-only settlement. `LOADING` is a protected state.
- `SettingsStore` owns validated preferences, delayed automatic saves, display-mode preview/rollback, and applying preferences to the engine/audio/camera/effects.
- `ProfileManager` owns credits, upgrades, mods, records, remembered aircraft, guarded transactions, safe profile writes, and fresh-aircraft loadout application.
- `data/aircraft_specs.gd` owns aircraft baseline hull, fuel and cruise speed. UI previews and gameplay use it.

## Required routes

Main menu -> aircraft selection -> loading -> ready gameplay. Selection -> Hangar -> Back returns to the same aircraft. Results -> Hangar opens the actual Hangar. Retry and confirmed Restart use the shared loader.

Pause -> Settings -> Back stays paused. Pause cannot dismiss Upgrade, Boss Decision, Results, or Loading. Results take priority over earlier dialogs. A boss decision arriving during an upgrade waits for the queued upgrade choices.

Only activate gameplay after the loader's readiness handoff and reveal. Start the run and director once, at activation. Release launch/confirm input before allowing gameplay actions. Never use GUI event consumption alone to gate globally polled controls.

## Persistence and safety

Profile and settings use separate files. Writes go to a temporary file and retain a backup before replacement. Invalid profile JSON is preserved and purchases disabled. Failed purchases roll back credits and rank. Run IDs prevent duplicate settlement/history entries. Settings defaults do not reset progression.

Tests must launch with `ZIVA_TEST_DATA_DIR` set before autoloads run. Use `tools/run_menu_checks.py`; it isolates every suite below `artifacts/menu-repair-tests/`. Never use the player's profile as a fixture.

## Permanent effects

| System | Runtime consumer |
|---|---|
| Engine | Cruise speed and thrust acceleration |
| Rotor | Yaw and collective lift response |
| Armor | Maximum/current hull |
| Airframe | Damage mitigation, capped at 24% |
| Fuel | Maximum/current fuel |
| Targeting | Turret tracking and salvo painting rate |
| Weapon system | Weapon, painted-salvo and Super damage |
| Countermeasures | Flare capacity and cooldown |

| Perk | Runtime consumer |
|---|---|
| Magnet radius | Pickup attraction threshold |
| Vector thrusters | Dash speed and cooldown |
| Scavenger rig | Coin/salvage pickup amounts, rounded up |
| Rotor armor | Impact and scrape hull damage reduction |
| Combat computer | Salvo target-search radius and missile speed |
| Lean burn | Fuel consumption |
| Devastator core | Super charge gain |
| EMP rounds | Machine-gun EMP proc chance |

All eight mods have runtime effects: incendiary, armor piercing, missile EMP, cluster bomblets, napalm field, shaped charge, shock and slug. Apply loadouts once from a fresh baseline. Preserve temporary run progression separately.

## Verification commands

```powershell
python tools/run_menu_checks.py --parse
python tools/run_menu_checks.py
python tools/run_menu_checks.py --rendered
python tools/run_menu_checks.py --script tests/test_menu_guards.gd
python tools/run_menu_checks.py --script tests/test_menu_exit.gd
python tools/run_menu_checks.py --script tests/test_menu_effects.gd
python tools/run_menu_checks.py --script tests/test_loading_animation_transition.gd
python tools/run_menu_checks.py --rendered --script tests/test_menu_navigation_edges.gd
python tools/run_menu_checks.py --script tests/verify_menu_persistence.gd --profile-source profile-headless-test_menu_repair
python tools/run_menu_checks.py --script tests/test_score_and_high_score_system.gd
python tools/run_menu_checks.py --script tests/test_death_animation_and_flow.gd
python tools/run_menu_checks.py --script tests/verify_vehicle_selection.gd
```

The scripts use the installed Godot executable at `C:/Users/Prime 3/Desktop/Godot.exe`. Rendered captures and reports stay in the project. Injected controller events are not a physical controller hardware test. Loading timings measure this machine and existing import/shader caches; they are not a gameplay FPS benchmark or a guarantee of stall-free rendering.
