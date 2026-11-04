# Fix true 360-degree left-stick helicopter movement

Follow-up implementation and verification: [completed fixes, 4 November](PRESENTATION_AND_CONTROLLER_FIX_RESULTS_2026-11-04.md). The findings below describe the pre-fix state.

Prepared from source inspection and a Godot 4.7.1 runtime diagnostic on 3 November 2026. This is an implementation prompt; the movement repair has not been applied.

## Copy-ready implementation request

Fix controller movement in the existing Godot project at `C:\Users\Prime 3\Documents\ziva-heli-town-helll`. The left analog stick must provide smooth, continuous 360-degree horizontal movement: left means screen-left, right means screen-right, up means away from the camera, and down means toward the camera. Every intermediate angle must work, with proportional analog speed and predictable acceleration, stopping, and reversal. The player must not need to rotate the helicopter first to move sideways or backward.

Implement and verify the repair in the actual game. Preserve keyboard/mouse flight, right-stick directional aim assistance, salvo targeting, damage rumble, altitude controls, and existing combat/progression. Read `AGENTS.md` first. Preserve unrelated working-tree edits, including the existing main-menu scene change. Do not treat a green old controller suite as proof that analog movement is correct.

### Verified problems to reproduce before changing code

The current `autoload/input_manager.gd` uses `Input.get_axis` separately for thrust and strafe, with a 0.20 deadzone on each action. It then limits the combined vector's maximum length. This distorts its direction and magnitude; clamping the maximum cannot recover components already removed by axial deadzones.

A new diagnostic using actual synthetic `InputEventJoypadMotion` events from device 7 reproduced the following through the production InputManager:

- Half stick at 22.5 degrees from forward becomes straight forward: raw `(0.191342, -0.461940)` becomes `(0, -0.327425)`.
- Half stick at 45 degrees has magnitude 0.271447, compared with 0.375 at a cardinal direction of the same raw radius.
- Full circular stick at 45 degrees has output magnitude 0.896447, compared with 1.0 forward or right.
- Full stick at 22.5 degrees becomes approximately 14.16 degrees.
- Quarter stick at 45 degrees produces zero, while quarter stick forward produces nonzero movement.

Input-mode switching adds a separate failure. Any mouse motion greater than two pixels calls `_set_controller_mode(false)`. A held left stick still contributes through the shared InputMap, but `direct_move` becomes false, camera-relative conversion stops, and reduced legacy lateral/reverse handling is selected. The diagnostic reproduced a held 0.8 right stick returning `strafe=0.75` with `direct_move=false` immediately after a three-pixel mouse event. Slow diagonal `(0.24,-0.24)` also fails to acquire controller mode from mouse mode because activation checks each axis against 0.25 rather than using the radial movement signal.

The flight controller also remains direction-dependent: forward/backward speed uses an exponential response, whereas strafe uses a bounded, filtered acceleration controller. Starting from rest with equal full-radius input, the diagnostic measured approximately 23.40 m/s forward versus 30.23 m/s sideways after 0.25 seconds. Camera-relative intent is converted to hull-local components before the flight controller applies yaw, then reconstructed afterward, adding another place for heading-dependent discrepancies.

The existing `tests/test_controller_handling.gd` still passes 21/21. It disables normal player and camera processing, manually steps flight, and mostly uses full-axis values. Its diagonal test checks only an upper speed bound. It does not establish analog circular coverage, equal speed, low-stick acquisition, or correctness with the normal moving camera.

### Required implementation

1. **Read the left stick as one vector.** Separate controller movement from keyboard action aggregation. Use device-scoped stick state from the active controller, with an explicit, testable device-switch policy. A second controller or keyboard key must not silently contaminate that vector. Support nonzero device IDs, disconnect/reconnect, and synthetic-input verification. Inspect the actual connected controller's mapping when hardware is available; report its name and whether its mapping is recognized.

2. **Apply one radial deadzone.** Read un-deadzoned X/Y first. With raw vector `v`, radius `r=length(v)`, and movement deadzone `d`, return zero for `r <= d`; otherwise use `normalize(v) * clamp((r-d)/(1-d), 0, 1)`. Preserve direction and partial-stick speed. Avoid applying axial deadzones before or after this operation, and avoid normalizing every nonzero movement to full speed. Add a saved, separately labeled left-stick movement deadzone; preserve the existing right-stick preference and old settings compatibility. Use a clear initial value around 0.18–0.20 and verify noise rejection.

3. **Carry stable world-space planar intent into physics.** Build an orthonormal horizontal movement frame from the camera's stable yaw, excluding cosmetic roll and shake. Handle degenerate near-vertical camera orientation safely. Compute `move_world = right * stick.x + forward * -stick.y`. Keep movement magnitude. Pass the world-space movement intent to the controller branch instead of projecting it into the hull and reconstructing it after yaw. Keep the keyboard path compatible. Left-stick movement must not implicitly steer hull yaw or make the camera orbit; preserve D-pad yaw and existing right-stick weapon aiming. Continuous D-pad turns must not change the meaning of stick-left relative to the visible camera.

4. **Use a direction-independent planar velocity controller for gamepad movement.** Compute the target horizontal velocity from world-space intent and effective cruise speed. Use common vector acceleration/braking rules for all angles, including reversals. Preserve readable helicopter pitch/bank as cosmetic responses; they must not distort the physics vector. Respect effective aircraft speed caps, engine/rotor condition where applicable, cargo, hangar/card modifiers, thrust/handling effects and drag-related upgrade tradeoffs. Keep collision response, battlefield boundaries, altitude, damage and fuel behavior connected. Do not bypass `move_and_slide`, collision handling, or teleport the aircraft. Dash must use the same requested movement direction and recover cleanly afterward.

5. **Separate movement ownership from aim/UI hints.** Small incidental mouse motion must not change a held pad's movement coordinate frame, speed, or physics branch. Preserve deliberate mouse aiming and keyboard fallback. Use the movement vector's radial activation threshold consistently, with an explicit arbitration policy that prevents mode flicker. Test pause, card selection, menu transitions, retry, focus loss, and disconnect. Retain input guards and held-trigger safety.

6. **Preserve the rest of the project.** Do not redesign weapons, remove turret limits, change XP ownership, enable disabled enemies, alter wave budgets, or replace models. XpManager remains authoritative and LevelUpUi remains the production overlay. Existing right-stick assist, obstruction checks, projectile origins, target switching, salvo painting and rumble must continue working.

### Acceptance tests and evidence

Add meaningful tests that fail on the current implementation and pass after the fix. Inject genuine joypad events through the production input path, rather than only supplying `override_flight_input`.

- Sweep a complete circle in at least 16 directions at radii 0.25, 0.50, 0.75 and 1.0, plus zero and samples immediately below/above the configured deadzone. For accepted input, requested direction error must be below one degree, and magnitude must match the documented radial curve within 0.01. Equal-radius directions must have equal magnitude. Test a circular full-radius diagonal rather than only the square-gate corner `(1,-1)`.
- Measure actual velocity, displacement, acceleration, stop distance and reversal time across directions, rather than just checking a maximum speed. On a healthy baseline aircraft in unobstructed space, settled same-radius speeds should agree within 5%, settled direction error should be below 3 degrees, and full-stick movement should reach at least 95% of effective cruise speed after one second. Target reversal through zero within 250 ms and speed below 0.5 m/s within 0.5 seconds after release; document any justified aircraft/modifier exceptions rather than silently weakening assertions.
- Test Apache, Nighthawk and Warlock, several hull/camera headings, simultaneous D-pad turning, partial stick, diagonals and continuous circular sweeps. Exercise upgraded speed/drag and cargo/damage modifiers without removing their intended effects. Check render rates 30/60/120 with normal fixed physics, and any existing physics-rate coverage relevant to the controller.
- Include a real scene-tree integration run with player physics, InputManager and camera processing enabled. Stage open air away from obstacles and boundaries, then perform an additional normal-town gameplay check. Do not freeze the camera or manually step the controller as the only acceptance evidence. Compare requested yaw-frame movement and actual planar movement; separately inspect how it reads on screen.
- Hold the left stick while sending mouse jitter, deliberate mouse aim, right-stick aim, fire, salvo, dash, yaw and altitude inputs. Test low-stick activation from mouse mode, devices 0 and 7, a second pad, disconnect/reconnect, pause/resume, death/retry and menu-to-game deployment. Releasing or disconnecting must clear the relevant device state safely.
- Rerun `test_controller_handling.gd`, `test_controller_ready.gd`, `test_helicopter_lateral_handling.gd`, `test_flight_frame_rates.gd`, `verify_playability_game_loop.gd`, `test_gameplay_stability_and_upgrades.gd`, and `test_xp_upgrade_effects.gd`, adapting only assumptions intentionally changed by the repair. Use isolated `ZIVA_TEST_DATA_DIR` saves. Report individual failures and runtime errors; do not hide them behind an aggregate pass count.

Provide a short rendered demonstration of forward, backward, sideways, diagonal and continuous circular movement with independent aiming. Record expected versus actual movement metrics. If no physical controller is attached, state that synthetic input was used and leave controller mapping, real stick feel and motor feedback explicitly unverified. Do not claim a hardware test occurred.

Deliver the implemented fix, focused regressions, updated controls/settings documentation, and a report of root causes, changed behavior, measurements and remaining limitations. Do not push or publish as part of this prompt unless the current session explicitly authorizes it.

## Review evidence

- Source: `autoload/input_manager.gd` action setup (around 107), mode selection (170–190), and `get_flight_input` (282–317).
- Physics: `src/player/player_helicopter.gd` input acquisition/yaw (581–645) and planar response (715–765).
- Camera: `src/player/player_camera.gd` yaw follow, cosmetic roll and shake.
- Settings: `autoload/settings_store.gd` and `src/ui/menus/settings_menu.gd`; current deadzone preference only configures right-stick aiming.
- Existing test gap: `tests/test_controller_handling.gd` disables normal player/camera/input processing around lines 65–74.
- Local diagnostic: `artifacts/controller-review-2026-11-03/probe.gd`, `probe.log`, `errors.log`.
- Existing suite rerun: `artifacts/controller-review-2026-11-03/existing-suite.log` reports 21/21, with an empty error log.

The diagnostic used an isolated player scene with a fixed camera to separate input/response defects from world collisions. It is not a completed live-camera gameplay acceptance test. `Input.get_connected_joypads()` returned an empty list, and no Godot MCP editor session was connected. No physical controller test was performed. Production gameplay code was not modified during this review.
