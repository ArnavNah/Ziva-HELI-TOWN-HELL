# Controller-ready implementation — 29 October 2026

The movement/aim mapping below is historical. See [30 October handling and rumble update](CONTROLLER_HANDLING_RESULTS_2026-10-30.md) for the current directional controls and verification.

Player guide: [controller-ready-guide.html](controller-ready-guide.html).

## Changes

- `InputManager` now owns one gamepad virtual cursor. Right-stick input uses a radial deadzone, precision response, adjustable sensitivity/invert-Y, elapsed time and viewport scaling. Mouse aim stays independent and resumes on deliberate mouse/keyboard input. Shared `get_aim_screen_position()` feeds both helicopter/turret and HUD; salvo painting uses the turret's existing authoritative world aim.
- Added L3/R3 weapon cycling, View/Back tactical actions, explicit A/B and directional menu events for any mapped device. Existing flight/combat bindings remain. Input setup is idempotent. Flight stick and trigger deadzones are explicit.
- Aircraft preview supports right-stick rotation and trigger zoom. Focus reaches the biome dropdown, launch, hangar and all other screens. Cards have explicit horizontal focus links and controller instructions.
- Settings → Flight controls exposes saved sensitivity (0.30–2.50x), radial deadzone (8–40%) and vertical aim inversion. The existing settings validator handles missing/old profiles and clamps these new values.
- Tactical actions pause the sortie, show mission status, cycle radar zoom, and require explicit request/end-sortie confirmation. Before wave 3 extraction is disabled. Securing the LZ is still required for the separate end-sortie confirmation. The dialog owns only its own pause and respects results/state transitions. The opening View press cannot immediately close it. B closes native/embedded confirmation dialogs as well as normal menus.
- HUD combat actions cannot acquire GUI focus and consume A intended for firing. UIFlow waits for held trigger/actions to release before combat re-arms, and modal confirmations block gameplay input. Salvo painting cancels on non-combat state transitions so releasing a trigger while paused cannot launch stale locks.
- Disconnecting the active pad clears held actions, cancels painting, pauses an active sortie and shows a notice. Reconnection/another intentional input resumes device ownership without restarting. Disconnecting a previously used pad while already using the mouse does not interrupt keyboard/mouse play.
- Testing Y exposed that `DevastationSuper` only wrote the old boolean while damage used owned protection states. The active super now participates in `has_protection()` and protection reasons; activation/expiry recomputes the aggregate state instead of clearing other shields.

## Test evidence

Use `ZIVA_TEST_DATA_DIR` before Godot starts. All verification used separate profile folders under `artifacts/controller-ready/`.

| Suite | Result |
| --- | --- |
| `tests/test_controller_ready.gd --fixed-fps 60` | 71/71 headless checks passed with actual `InputEventJoypadButton` / `InputEventJoypadMotion`, synthetic device 7 |
| `tests/test_menu_repair.gd --fixed-fps 60` | 182 checks, no failures; existing mouse/keyboard flows, settings persistence, purchases, modal guards, five run/menu cycles and failed-load recovery |
| `tests/test_xp_upgrade_effects.gd --fixed-fps 60` | 65/65 passed |
| `tests/test_gameplay_stability_and_upgrades.gd --fixed-fps 60` | 20/20 passed |
| `tests/test_tactical_missions.gd --fixed-fps 60` | 78 passed, no failures |

The controller suite covers operations-center navigation, aircraft rotation/biome selection, hangar tabs, manual/quit cancel, saved calibration, actual async scene launch, flight axes/collective, shared reticle/turret movement, drift rejection, frame-rate invariance, resize clamping, actual weapon cycling/ammo/reload, flares, charged super and shield ownership, aiming at a physical target, actual painted locks and homing salvo release, pause, held-trigger safety, actual XP card navigation/application, boss overdrive choice, dash, paused mission/radar actions, gated extraction request, disconnect/reconnect and mouse fallback, secured LZ confirmation, real debrief and retry.

Rendered evidence uses the same suite with `--capture`, real 3D rendering and embedded dialog windows. Capture mode exits after the four requested states; the complete input path runs separately in the headless suite. Screenshots: `artifacts/controller-ready/controller-settings.png`, `controller-aim.png`, `controller-cards.png`, `controller-missions.png`. This is a controlled input/visual fixture, not a balance or frame-rate benchmark. Captures explicitly draw the viewport so a modal's paused focus cannot leave the harness waiting on a post-draw signal.

The background loader runs on a real worker thread. The controller harness waits by wall time and yields a millisecond while loading, rather than exhausting thousands of simulated frames and quitting while the worker is still reading resources.

Saved complete controller logs: `artifacts/controller-ready/controller-headless.log` and `artifacts/controller-ready/controller-render.log`. Other suite logs remain at `artifacts/strike-test_menu_repair.log`, `artifacts/strike-test_xp_upgrade_effects.log`, `artifacts/strike-test_gameplay_stability_and_upgrades.log` and `artifacts/strike-test_tactical_missions.log`.

## Limits

- `Input.get_connected_joypads()` returned an empty list during testing. No hardware or driver compatibility claim is made; the final hands-on check must use the user's actual pad.
- Button names in hints are Xbox-style positions; mapped PlayStation controllers use equivalent positions. Custom button-remapping UI and rumble are not part of this pass.
- Some isolated Godot runs still report ObjectDB cleanup warnings at shutdown. Named behavior checks pass; this is not a claim that all unrelated engine/editor lifecycle warnings were repaired.
- The existing authoritative XP queue, one-card-per-level rule, enemy roster, models and shared wheel assets are preserved.
