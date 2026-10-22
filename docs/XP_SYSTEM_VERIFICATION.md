# XP system repair and verification

## Repair verified — 2026-10-23

The functional defects in the original audit below have been repaired and verified against the actual gameplay scene.

| Check | Latest result |
| --- | --- |
| XP/magnet/resource acceptance suite | 54/54 assertions passed; test-fixture transform errors fixed. |
| Production-scene integration, including rendered overlay | 16/16 passed, previously 6/16. |
| Actual magazine-capacity card | 300 → 390 rounds, with no invalid function call. |
| All-card and combat-effect suite | 62/62 passed, including all 36 real catalog cards. |
| Existing damage/upgrade stability suite | 20/20 passed. |
| Full game loading/flight/aiming/weapons/pickup loop | 20/20 passed. |
| Legacy XP/card compatibility suite | 6/6 passed; HUD assertion now uses the authoritative queue. |
| Menu/restart/boss/extraction navigation | 35/35 passed. |
| Five-vehicle ground roster | Passed, including 9,600 wave/theme selections. |

Changes:

- `XpManager` owns the XP total, level, threshold curve, pending choices, and XP multiplier. The HUD reads it directly. `RunProgression` mirrors its values for compatibility instead of running a second automatic draft system. Enemy death drops physical XP; it no longer awards separate immediate XP through `GameManager`. Legacy XP pickups also deliver to the new authority.
- Each actual card selection consumes exactly one pending level. A 500 XP burst gains four levels and awards four cards. Menu/loading/results transitions dismiss the overlay while preserving the destination state's pause behavior. Run start clears XP, level, queue, and XP multiplier.
- Boss decisions wait for the new mandatory draft queue instead of checking only the legacy dialog. Deferred choices resume after pause/overdrive transitions. Completing or dismissing a draft cannot unpause another modal owner.
- Card payloads now change real weapon damage/fire/reload rates, per-weapon magazine capacities, projectile counts, blast radius, status/armor/structure effects, missile speed/turning, lock limits, salvo cooldown/painting speed, and extra salvo missiles.
- EMP duration reaches `DamageReceiver`, and EMP/shock effects stop enemy weapon brains while active. Cluster children clear their cluster payload so explosions cannot multiply recursively.
- Global tomes affect real magnet radius, XP multiplier, speed, drag, dash cooldown, armor, hull, regeneration, evasion, and finite-capacity energy shields. Fresh player instances duplicate/reset their sensor shape so magnet upgrades cannot carry across runs.
- All 36 cards have cached subsystem icons. The overlay displays them and sets actual button borders from rarity. Drafts filter level unlocks, locked subsystems, maximum stacks, and required cards. Epic cards unlock at level 4 and legendary cards at level 6; legendary and single-application effects stop appearing once owned.
- Upgrade/collection sounds now use registered audio resources, collection feedback calls the existing sparkle effect, and floating combat text defers initialization until it enters the tree.
- The game has no heat mechanic. The two advertised heat-reduction payloads were replaced with working reload-speed bonuses, with matching descriptions. No new overheating penalty was introduced.

The 62-check suite exercises actual spawned cannon/rocket/salvo projectiles, an EMP status receiver, finite shield damage absorption, physical XP drop events, card eligibility, keyboard input while paused, game-over pause ownership, and restarting. The rendered screenshot was inspected for layout, icons, borders, and HUD level agreement.

Current evidence:

- `tests/test_xp_upgrade_effects.gd` and `artifacts/menu-repair-tests/test_xp_upgrade_effects.log`.
- `tests/verify_xp_spec_integration.gd`, `artifacts/xp-spec-integration-results.json`, and `artifacts/menu-repair-tests/verify_xp_spec_integration-rendered.log`.
- `artifacts/xp-spec-integration-overlay.png`.
- `artifacts/menu-repair-tests/verify_xp_capacity_contract.log`.

Some standalone headless acceptance/playability runs still report shutdown ObjectDB warnings; verbose headless tracing also exposes dummy-renderer/audio teardown warnings. The ordinary final functional runs contain no script/runtime errors. These shutdown warnings are not evidence of a failed XP/card assertion and are separate from the repaired gameplay defects.

## Original audit — 2026-10-22 (historical)

Verified on 2026-10-22 against the attached “Implement XP Collection, Planar Magnet Physics, and Level-Up Card Draft System” requirements.

**Verdict: partially implemented. The component scripts and gameplay overlay exist, but integration defects prevent marking the system complete.**

This was a verification pass. Production game scripts and scenes were not modified. Two regression tests and this report were added. Tests used isolated profile directories through `tools/run_menu_checks.py`.

## Runtime evidence

| Test | Assertion results | Run result |
| --- | --- | --- |
| Existing `tests/test_xp_magnet_and_card_draft.gd` | 54/54 reported passing | Failed the runner's error check: two global-transform errors originate in the test itself, which positions unattached drops through `global_position`. |
| Existing `tests/test_xp_pacing_and_level_up_cards.gd` | 6/6 reported passing | Failed the runner's error check: existing `floating_text.gd` global-transform errors. This suite primarily exercises the older progression system. |
| New `tests/verify_xp_spec_integration.gd`, rendered production scene | 6/16 passed | Ten integration checks failed; no script error was needed to reproduce these failures. |
| New `tests/verify_xp_capacity_contract.gd` | Capacity unchanged | Actual ROTARY OVERDRIVE selection raises an invalid-function-call error. |

The rendered check loaded `scenes/main_game.tscn`, used its real player, XP autoload, loot manager, HUD, card overlay, weapons, and salvo controller, and exercised real card-button signals. Known safe cards were substituted during queue-count tests to isolate queue behavior from unrelated broken payloads. This verifies signal/application flow, rather than physical mouse input. Wave spawning and player movement were stopped during the focused audit.

Artifacts:

- `artifacts/xp-spec-integration-results.json`: individual production-scene assertions and observed values.
- `artifacts/xp-spec-integration-overlay.png`: actual rendered upgrade overlay.
- `artifacts/menu-repair-tests/verify_xp_spec_integration-rendered.log`.
- `artifacts/menu-repair-tests/verify_xp_capacity_contract.log`.
- `artifacts/menu-repair-tests/test_xp_magnet_and_card_draft.log`.
- `artifacts/menu-repair-tests/test_xp_pacing_and_level_up_cards.log`.

## Confirmed implementation

- `XpDrop` is an `Area3D` with a spherical collision shape, low-poly visual, and the requested default attraction parameters.
- Attraction accelerates in 3D while collection uses the XZ distance threshold. Overshoot clamping and extra speed for fast-moving players are implemented. The existing suite exercises a moving 50 m/s target, with the test-fixture errors noted above.
- A production XP drop worth 25 XP increased `XpManager.total_xp_collected` by exactly 25. A repeated collection call did not add XP twice.
- The player has a 12 m spherical `MagnetSensor`, connected to attraction logic. A +40% magnet card changed its actual radius to approximately 16.8 m.
- `XpManager` is an autoload and implements the requested level-one defaults, XP signals, excess-XP carryover, and the `int(25 * level^1.35)` curve.
- The custom `UpgradeCard` Resource has the requested metadata, rarity/subsystem enums, and dictionary payloads. The master deck contains 36 cards.
- The production level-up overlay opens when 25 XP is collected, pauses gameplay, presents three distinct cards, and can receive card-button signals while paused.
- Rarity weights match 60 / 25 / 10 / 4.5 / 0.5. Luck alters the weights, and the selected card is removed from the draft pool to prevent duplicates.
- The overlay includes an entry tween, titles, rarity text colors, subsystem text, descriptions, stat text, and keyboard-shortcut handling.
- Completing the entire current choice sequence hides the overlay and unpauses gameplay.

## Blocking integration defects

### 1. HUD and gameplay progression have separate XP authorities

`src/loot/xp_drop.gd` awards XP to the new `XpManager`, while `src/ui/survival_hud.gd:193` reads the player's older `RunProgression`.

Runtime result: collecting 25 XP made `XpManager.current_level` equal 2 and opened a level-two draft, but the visible HUD still showed **LVL 1**. The legacy progression gained zero XP from that drop.

Code inspection also shows `autoload/game_manager.gd:344` still granting enemy-kill XP directly to the old progression, and `src/loot/pickup.gd:301` awarding legacy XP pickups to it. The older `UpgradeDialog` remains available alongside the new overlay. These paths require reconciliation into one authoritative progression flow; the new system has not fully replaced the old one.

### 2. The draft queue awards one extra upgrade

At `src/ui/level_up_ui.gd:215`, choosing a card consumes a pending level and opens another draft whenever the queue was nonempty before consumption. It also reopens when consumption has just reduced the queue to zero.

Observed through real button signals:

- One gained level required **two** card selections.
- A 500 XP burst gained four levels but required **five** card selections.

The existing suite misses this because it manually opens a draft after resetting the queue, rather than opening it through the XP signal.

### 3. Several upgrades update a ledger without changing combat

`src/player/player_subsystem_manager.gd` checks weapon fields named `weapon_damage_multipliers`, `weapon_interval_multipliers`, and `weapon_reload_multipliers`. The actual `PlayerWeapons` fields are `damage_multipliers`, `fire_rates`, and `reload_multipliers`.

Runtime results:

- A +20% cannon damage card changed the subsystem ledger to 1.2, but the real weapon damage multiplier remained **1.0**.
- A +15% fire-rate card left the real fire-rate multiplier at **1.0**.
- A -25% missile cooldown card left the real salvo cooldown at **5.0 seconds**.
- A +20% XP tome left `XpManager.xp_multiplier` at **1.0**.

Missile lock and damage configuration also targets fields absent from the actual salvo implementation. Rocket blast radius is recorded in the subsystem ledger without a consumer in the firing path. Many advertised payload keys, including heat reduction, burn/shock chances, clusters, XP bonus, and shield/evasion effects, have no handling in the new subsystem manager.

### 4. Capacity cards produce a runtime script error

The subsystem manager calls `upgrade_magazine_capacity` with two arguments at lines 73 and 91. The real method at `src/player/player_weapons.gd:58` accepts one argument and updates all weapon magazines.

Applying the real **ROTARY OVERDRIVE** card reproduced:

`Invalid call to function 'upgrade_magazine_capacity' in base 'Node (PlayerWeapons)'. Expected 1 argument(s).`

Machine-gun capacity remained **300**, rather than the advertised **390**. Fixing argument count alone must also preserve the intended per-weapon targeting.

### 5. Starting a new run does not reset the XP autoload

`XpManager.reset_run()` exists, but production run-start code does not call it.

After gaining 500 XP and invoking `GameManager.start_new_run("apache")`, the manager still held **level 5 and 500 total collected XP**. A fresh run must explicitly reset level, XP, pending drafts, and multipliers.

## Remaining specification gaps

- **Unlock filtering:** `generate_draft_picks` copies the entire new master deck and filters by rarity and duplicate selection. It does not filter by active unlock criteria. The older catalog's eligibility rules do not automatically apply to this deck.
- **Icons:** all 36 cards currently have null icons, and the new card UI does not create an icon control.
- **Rarity borders:** normal card borders use the same fixed color. Formatting tries to find a `BorderRect` child that is never created. Runtime checks confirmed the borders do not reflect card rarity; focus uses a gold border instead.
- **Upgrade audio cues:** the new overlay requests `upgrade_offer` and `upgrade_applied`, which are absent from the audio cache and silently return. Collection still has generic pickup audio through the event bus, plus pickup flash feedback.

## Recommended repair order

1. Reconcile both XP/progression systems, connect HUD state to the authority, and reset it on every new run.
2. Correct queue consumption so each gained level grants exactly one upgrade.
3. Connect card effects to real weapon/salvo fields and repair the magazine API contract.
4. Implement or remove unsupported card payloads so descriptions match actual behavior.
5. Add unlock eligibility, icons, rarity borders, and registered upgrade sounds.
6. Repair the existing test-fixture/floating-text errors and rerun the focused integration checks.

No gameplay fixes were applied during this audit.
