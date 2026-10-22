# Menu repair implementation report

Implemented 19 October 2026.

- Deploy, Retry and Restart share one guarded loader with resource, world-preparation, readiness and reveal phases. Loading errors offer Retry/Back.
- Roads, blocks and vegetation prepare in frame batches. Gameplay starts after reveal, and held launch input must be released before gameplay input arms.
- Pause respects upgrade, boss, loading and results states. Settings Back returns to pause. Confirmations protect Restart, return-to-menu and Quit.
- Selection is remembered. Hangar remembers its caller. Return to Hangar opens the actual Hangar. Stats and controls help use current runtime data.
- Audio, FPS, VSync, camera shake, reduced flashes and telemetry preferences save automatically. Display changes support timed Keep/Revert.
- All systems, perks and weapon mods have runtime effects. Failed purchase saves roll back credits/rank. Corrupt profile JSON is preserved; bonuses apply once to fresh aircraft.
- Run IDs prevent duplicate payouts/history. Ties are not new records. Leaderboards rerank every entry. Scorecards scroll and copy actual text.
- Missing/stale upgrade cards cannot dismiss a choice. Queued choices precede a pending boss decision. Deferred offers check scene lifetime.

## Verification

Tests used isolated profiles below `artifacts/menu-repair-tests/`. Credits in screenshots are test data. The real profile was not used as a fixture.

| Suite | Result | Evidence |
|---|---|---|
| Complete flow, headless | 182 passed; five full loops | [log](../artifacts/menu-repair-tests/headless.log) |
| Complete flow, rendered | 183 passed; five full loops | [log](../artifacts/menu-repair-tests/rendered.log) |
| Rendered navigation and sizes | 37 passed | [log](../artifacts/menu-repair-tests/test_menu_navigation_edges-rendered.log) |
| Gameplay effects and failed saves | 19 passed | [log](../artifacts/menu-repair-tests/test_menu_effects.log) |
| Loading and error recovery | 7 passed | [log](../artifacts/menu-repair-tests/test_loading_animation_transition.log) |
| Stale cards, records, confirmations and defaults | 13 passed | [log](../artifacts/menu-repair-tests/test_menu_guards.log) |
| Fresh-process persistence | Passed | [log](../artifacts/menu-repair-tests/verify_menu_persistence.log) |
| Score/leaderboard regression | 24 passed | [log](../artifacts/menu-repair-tests/test_score_and_high_score_system.log) |
| Death/results regression | 12 passed | [log](../artifacts/menu-repair-tests/test_death_animation_and_flow.log) |
| Aircraft selection regression | 16 passed | [log](../artifacts/menu-repair-tests/verify_vehicle_selection.log) |
| Confirmed application exit | Passed in a rendered process | [log](../artifacts/menu-repair-tests/test_menu_exit-rendered.log) |
| Script compilation | Zero parse failures | [log](../artifacts/menu-repair-tests/parse.log) |

## Per-control checklist

Shared builders connect each data-driven row to the same validated handler. Evidence distinguishes GUI events, backend checks and source inspection.

| Screen | Controls | Behavior | Verification |
|---|---|---|---|
| Main menu | Select Airframe | Open selection and retain aircraft | GUI events and return-context checks |
| Main menu | Hangar & Armory | Refresh wallet/equipment; return to main menu | Route and GUI checks |
| Main menu | Pilot Settings | Open preferences; Done restores focus | GUI and persistence checks |
| Main menu | Flight Manual / OK / close | Scrollable help from actual bindings | GUI and rendered capture |
| Main menu | Exit / Confirm / Cancel | Confirm quits; Cancel restores focus | GUI cancellation and actual child-process exit |
| Aircraft selection | Previous / Next / 3 cards | Select exactly one aircraft and update stats | All aircraft verified; arrows and representative card GUI-tested |
| Aircraft selection | Back | Return to main menu | GUI and controller A confirm routing |
| Aircraft selection | Upgrade Hangar | Return to the same selected aircraft | GUI return-context checks |
| Aircraft selection | Launch Sortie | One protected loading transition | GUI, duplicate-request and input-release checks |
| Hangar | Systems / Perks / Mods / Dossier tabs | Display and refresh the matching section | All four tabs GUI-tested |
| Hangar | Return / Back | Respect main-menu or aircraft-selection caller | GUI return-context checks |
| Settings | Preferences / Flight Controls | Switch scrollable sections | GUI and rendered checks |
| Settings | Window mode / Keep / Revert | Preview, retain or automatically undo display change | Rendered Keep and timeout checks |
| Settings | FPS / VSync | Synchronize engine and saved settings | Runtime owner and disk-reload checks |
| Settings | Master / Effects / Music | Change real audio category levels and save | Runtime mute and disk-reload checks |
| Settings | Shake / Reduced flashes / Telemetry | Apply actual camera/effects/HUD preferences | Runtime consumers and explosion-light assertion |
| Settings | Restore defaults / Confirm / Cancel | Reset preferences only | GUI confirmation; progression preservation checked |
| Settings | Done / Back | Save and restore caller; remain paused when appropriate | GUI and pause-state checks |
| Pause | Resume | Restore the active run | State and input-release checks |
| Pause | Restart / Confirm / Cancel | Load one fresh same-aircraft run | GUI confirmation and fresh run-ID checks |
| Pause | Settings | Back returns to paused run | GUI and state checks |
| Pause | Main Menu / Confirm / Cancel | Protect run progress; Cancel stays paused | GUI confirmation/cancellation and shared destination checks |
| Pause | Quit / Confirm / Cancel | Protect run progress and restore focus on Cancel | GUI guards; shared confirmed-quit action |
| Pause developer section | Expand / Outlines / Toon / Screen blocks | Editor-only experiments with accurate setting labels | Handlers/backend inspected; full shader visual acceptance is outside this repair |
| Upgrade | Up to 3 offer buttons | Hide missing cards; reject stale/invalid/repeated offers | 1/2/3-card, stale-card and queued-offer checks |
| Boss choice | Extract | Settle victory once and show results | GUI and settlement checks |
| Boss choice | Continue | Activate Overdrive once and resume pending choices | State and queue checks |
| Results | Retry | Use shared loader for a new run | GUI and transition checks |
| Results | Return to Hangar | Open actual Hangar | GUI destination checks |
| Results | Main Menu | Open main menu without another overlay | GUI destination check |
| Results | Copy Scorecard | Copy actual report and give verified feedback | Rendered clipboard assertion |
| Loading failure | Retry / Back | Clean retry or safe return; discard obsolete loader | Missing-resource and unready-scene recovery checks |
| Hangar system | Engine purchase | Validate price/rank, save and apply: Cruise speed and thrust acceleration | Transaction and consumer checked; engine purchase also GUI-tested |
| Hangar system | Rotor purchase | Validate price/rank, save and apply: Yaw and collective lift | Transaction and consumer checked; engine purchase also GUI-tested |
| Hangar system | Armor purchase | Validate price/rank, save and apply: Maximum hull | Transaction and consumer checked; engine purchase also GUI-tested |
| Hangar system | Airframe purchase | Validate price/rank, save and apply: Damage mitigation | Transaction and consumer checked; engine purchase also GUI-tested |
| Hangar system | Fuel purchase | Validate price/rank, save and apply: Fuel capacity | Transaction and consumer checked; engine purchase also GUI-tested |
| Hangar system | Targeting purchase | Validate price/rank, save and apply: Turret tracking and salvo painting | Transaction and consumer checked; engine purchase also GUI-tested |
| Hangar system | Weapon system purchase | Validate price/rank, save and apply: Weapon, salvo and Super damage | Transaction and consumer checked; engine purchase also GUI-tested |
| Hangar system | Countermeasures purchase | Validate price/rank, save and apply: Flare capacity and cooldown | Transaction and consumer checked; engine purchase also GUI-tested |
| Hangar perk | Magnet radius purchase | Validate price/rank, save and apply: Pickup attraction radius | Transaction and consumer checked; magnet purchase also GUI-tested |
| Hangar perk | Vector thrusters purchase | Validate price/rank, save and apply: Dash speed and cooldown | Transaction and consumer checked; magnet purchase also GUI-tested |
| Hangar perk | Scavenger rig purchase | Validate price/rank, save and apply: Coin/salvage reward amounts | Transaction and consumer checked; magnet purchase also GUI-tested |
| Hangar perk | Rotor armor purchase | Validate price/rank, save and apply: Impact/scrape resistance | Transaction and consumer checked; magnet purchase also GUI-tested |
| Hangar perk | Combat computer purchase | Validate price/rank, save and apply: Salvo search radius and missile speed | Transaction and consumer checked; magnet purchase also GUI-tested |
| Hangar perk | Lean burn purchase | Validate price/rank, save and apply: Fuel consumption | Transaction and consumer checked; magnet purchase also GUI-tested |
| Hangar perk | Devastator core purchase | Validate price/rank, save and apply: Super charge gain | Transaction and consumer checked; magnet purchase also GUI-tested |
| Hangar perk | EMP rounds purchase | Validate price/rank, save and apply: Machine-gun EMP chance | Transaction and consumer checked; magnet purchase also GUI-tested |
| Hangar weapon mods | Incendiary equip | Save a valid weapon/mod pair and apply its effect | Every mod ID and effect checked; representative Equip GUI-tested |
| Hangar weapon mods | Armor piercing equip | Save a valid weapon/mod pair and apply its effect | Every mod ID and effect checked; representative Equip GUI-tested |
| Hangar weapon mods | Missile EMP equip | Save a valid weapon/mod pair and apply its effect | Every mod ID and effect checked; representative Equip GUI-tested |
| Hangar weapon mods | Cluster bomblets equip | Save a valid weapon/mod pair and apply its effect | Every mod ID and effect checked; representative Equip GUI-tested |
| Hangar weapon mods | Napalm equip | Save a valid weapon/mod pair and apply its effect | Every mod ID and effect checked; representative Equip GUI-tested |
| Hangar weapon mods | Shaped charge equip | Save a valid weapon/mod pair and apply its effect | Every mod ID and effect checked; representative Equip GUI-tested |
| Hangar weapon mods | Shock equip | Save a valid weapon/mod pair and apply its effect | Every mod ID and effect checked; representative Equip GUI-tested |
| Hangar weapon mods | Slug equip | Save a valid weapon/mod pair and apply its effect | Every mod ID and effect checked; representative Equip GUI-tested |
| Hangar weapon mods | 4 standard choices | Unequip special mod for the matching weapon | All four standard IDs checked |

## Measurements and remaining limits

First scene load in the rendered process: 6.02s. Later loads: 4.78–4.97s. World preparation advanced through 214 animation frames per load. The slowest individual frames per load ranged from 166 to 458ms.

Brief main-thread/graphics initialization stalls remain. These timings used existing import/shader caches and overlapping verification work; they are not a clean-cache benchmark or gameplay FPS claim. Physical controller hardware was not tested; controller events were injected through Godot’s actual GUI routing. Godot still reports RefCounted cleanup warnings at the end of some test processes. The warning remains unresolved. Final listed runs have no script/resource errors.

Visual checks covered 1280x720, 960x540, 1920x1080 and 2560x1080. Minimum window size is 960x540. Both full-flow suites repeated the complete menu/run/results journey five times.

## Files and reproduction

[Architecture, permanent effects and commands](../MENU_FLOW_NOTES.md). [Changed-file list](../artifacts/menu-repair-tests/changed-files.json). [Review patch](../artifacts/menu-repair-tests/changes.patch). Original source backup: `.codex-backups/menu-repair-20261019.zip`.

- `autoload/audio_manager.gd`
- `autoload/combat_director.gd`
- `autoload/game_manager.gd`
- `autoload/input_manager.gd`
- `autoload/profile_manager.gd`
- `autoload/settings_store.gd`
- `autoload/ui_flow.gd`
- `data/aircraft_specs.gd`
- `project.godot`
- `scenes/main_game.gd`
- `src/combat/damage_data.gd`
- `src/combat/damage_receiver.gd`
- `src/combat/lingering_fire.gd`
- `src/combat/projectile.gd`
- `src/effects/fx_manager.gd`
- `src/loot/pickup.gd`
- `src/player/devastation_super.gd`
- `src/player/player_camera.gd`
- `src/player/player_countermeasures.gd`
- `src/player/player_helicopter.gd`
- `src/player/player_salvo.gd`
- `src/player/player_weapons.gd`
- `src/player/run_progression.gd`
- `src/ui/boss_decision_dialog.gd`
- `src/ui/menus/debrief_screen.gd`
- `src/ui/menus/game_storage.gd`
- `src/ui/menus/hangar_menu.gd`
- `src/ui/menus/loading_screen.gd`
- `src/ui/menus/main_menu.gd`
- `src/ui/menus/menu_theme.gd`
- `src/ui/menus/pause_menu.gd`
- `src/ui/menus/settings_menu.gd`
- `src/ui/menus/vehicle_selection_menu.gd`
- `src/ui/upgrade_dialog.gd`
- `src/world/city_generator.gd`
- `src/world/field_dressing.gd`
- `tests/fixtures/menu_unready.tscn`
- `tests/parse_menu_repair.gd`
- `tests/render_menu_verification.gd`
- `tests/test_death_animation_and_flow.gd`
- `tests/test_loading_animation_transition.gd`
- `tests/test_menu_effects.gd`
- `tests/test_menu_exit.gd`
- `tests/test_menu_guards.gd`
- `tests/test_menu_navigation_edges.gd`
- `tests/test_menu_repair.gd`
- `tests/test_score_and_high_score_system.gd`
- `tests/verify_menu_persistence.gd`
- `tools/build_menu_repair_report.py`
- `tools/run_menu_checks.py`
