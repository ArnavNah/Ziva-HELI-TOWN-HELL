# Controller, gameplay scale, HUD and flight-motion implementation review

Follow-up implementation and verification: [completed fixes, 4 November](PRESENTATION_AND_CONTROLLER_FIX_RESULTS_2026-11-04.md). The findings below describe the pre-fix state.

Reviewed 4 November 2026 at commit `f535799f46ead1a20e5fc113e2e554b965a8979b`, against the two implementation prompts prepared on 3 November. This was an audit. Production gameplay files and supplied tests were not changed.

**Verdict: partially implemented.** The main 360-degree movement changes and the original score/timer overlap repair are present and pass their focused checks. A runtime deadzone bypass remains, target envelopes mishandle collider transforms, aiming is calculated before its mount is moved, and the larger scale/camera/animation work is unfinished.

## Actionable findings

### P1 — Raw fallback bypasses the movement deadzone and device isolation

Source: `autoload/input_manager.gd:417–428`; shared movement actions are configured with zero axial deadzones near line 113.

When the selected pad's filtered stick is zero, `get_flight_input()` falls through to variables called `kb_thrust` and `kb_strafe`. They read `Input.get_action_raw_strength()` from actions that still contain joypad bindings. Consequently, the values are not keyboard-only: the code restores the raw movement the radial filter just rejected.

Reproduction with synthetic device 7, movement deadzone 0.18, and raw stick `(0.10,0)`:

- `left_stick()` correctly returns `(0,0)`.
- `get_flight_input()` nevertheless returns `strafe=0.10`, `move_world=(0.10,0,0)`, `direct_move=true`.
- A manually stepped one-second flight sequence reaches 3.546 m/s.
- A separate sequence with normal player physics, render processing and InputManager processing enabled reaches 3.542 m/s and travels 2.726 units over approximately one second, while the filtered stick remains zero.
- With device 7 neutral and selected, device 1's sub-deadzone `(0.10,0)` also supplies movement through the shared fallback without becoming the selected device.

This can cause visible drift on a noisy real stick and defeats the new deadzone preference precisely around neutral. Separate keyboard movement state/actions from pad bindings; when the owned controller vector is neutral, retain zero pad movement. Test the final flight command and actual displacement, not only the radial helper or `active_joypad` field.

### P2 — Target envelope ignores collision-node transforms and compound geometry

Source: `src/ui/hud.gd:456–466` and the projection/cache code following it.

For a BoxShape3D or SphereShape3D, the envelope takes the shape dimensions around `(0,0,0)` and later applies only the target's root transform. It omits the CollisionShape3D position, rotation and scale. It also stops at the first named collider, leaving additional compound hull/wing shapes out. Mesh bounds are used only if this first shape is unsupported or absent.

A controlled offset-collider fixture produces about 175 logical pixels of bracket-center error. This fixture deliberately places the collider eight units off the root to expose the coordinate error; it is not a measurement of every production enemy's bracket error. The rendered production gunship also demonstrates the new bracket behavior, but all production compound/offset cases have not been exhaustively captured.

Transform each relevant shape into target-local coordinates, or use an explicit targeting envelope/cached hull mesh bounds. Define cache invalidation for visual/configuration changes. Check all active roles, elites, partial visibility and near-camera cases.

### P2 — Mount synchronization happens after aiming/impact calculation

Source: `src/player/player_helicopter.gd:538–544` and `:1076–1079`; `src/player/player_turret.gd:177–178`.

Player render processing calls `turret.update_aim()` first. That solves gimbal angles, caches `actual_aim_direction`, and raycasts the impact point. `_update_helicopter_visuals()` then changes the turret mount's position and basis. Weapon firing subsequently queries the new muzzle/gimbal transform, so the impact cache can describe a different pose from the one used to fire.

A staged attitude-change probe measured a 15.40-degree difference between cached direction and current muzzle direction after applying the visual pose. This is a deliberately stepped attitude transition, not a measured normal-frame or human-played miss angle. It establishes the stale-cache/update-order problem. Apply the presentation/mount pose before solving aim and impact, with a clear interpolation policy; verify actual shots and impact markers through animated turns and braking.

### P2 — Deliberate mouse aim remains coupled to pad movement ownership

Source: `autoload/input_manager.gd:203–220`, plus use of `controller_active` by turret targeting.

The new mouse-jitter protection preserves movement, but suppresses every mouse-motion mode change while either stick is held. A deliberate `(40,20)` mouse event during left-stick movement still leaves controller aiming selected. The test suite verifies switching only after sticks return to neutral. If mixed pad movement plus deliberate mouse aiming is to satisfy the prompt, movement ownership and aim ownership need separate state; simply increasing the mouse threshold does not supply that behavior.

## Implementation status

| Requested area | Status | Current evidence |
|---|---|---|
| Radial analog direction/magnitude | Implemented for active input | 16-direction, four-radius helper sweep passes; the neutral fallback defect above remains |
| Camera-yaw world-space movement | Implemented | Stable horizontal frame and world intent are used; direction/acceleration checks pass |
| Direction-independent pad response | Implemented for commanded movement | Common vector response, full-speed diagonals, reversal and stopping checks pass |
| Separate movement deadzone setting | Implemented, effectiveness incomplete | Setting is present and applied; raw fallback defeats it around neutral |
| Pad noise and multiple devices | Partial | State is tracked per pad, but final fallback still admits another pad's raw actions |
| Original stats/timer overlap | Fixed | Long-value stats moved into a two-row grid; no intersection in five rendered window sizes |
| Complete responsive HUD system | Partial | Main layout remains mostly fixed positions/sizes; no saved HUD/text scale control; full simultaneous-warning/layout matrix not demonstrated |
| Enemy-fitted target brackets | Partial | Projection and cached bounds added, but collider transform/compound handling is wrong |
| Model/world/camera proportions | Not completed by this commit | Camera, aircraft-spec/scale configuration, enemy rigs and collider configuration were unchanged; no new normalized scale policy or comprehensive scale audit delivered |
| Dynamic flight attitude | Partial | Stronger bank, braking flare, vertical-speed pitch cue and landed hover blend added |
| Imported wing/gear animation | Unfinished | Live `side_wings`, `skid_left`, and `skid_right` still resolve to null |
| Rest-transform rig and airframe-specific attitude profiles | Unfinished | Existing absolute visual transforms/common spring constants remain; original sine-wave hover remains with landed blending |
| Rotor behavior | Existing animation retained | Main and tail rotor bindings work; no new comprehensive shaft/RPM/blur validation delivered |
| Turret follows visible hull | Added, update order flawed | Mount is synchronized, but after aiming/impact calculation |
| End-to-end acceptance evidence | Partial | Broad supplied checks pass; additional probes still reproduce defects |

Unchanged scale values are not proof that existing model sizes are wrong. They mean the requested systematic calibration has not been established. Sampled rotor-inclusive AABBs vary with blade phase; body length and rotor span need separate canonical measurements before deciding what to resize. Preserve class differences and perspective.

## Verification actually run

Godot 4.7.1, isolated `ZIVA_TEST_DATA_DIR` save directories. The following nine supplied suites completed with **364/364 checks passed**:

| Suite | Result |
|---|---:|
| `test_controller_360_movement.gd` | 56/56 |
| `test_controller_handling.gd` | 21/21 |
| `test_controller_ready.gd` | 71/71 |
| `test_flight_frame_rates.gd` | 87/87 |
| `test_helicopter_lateral_handling.gd` | 16/16 |
| `test_flight_altitude_collision_and_blood_fx.gd` | 8/8 |
| `verify_playability_game_loop.gd` | 20/20 |
| `test_gameplay_stability_and_upgrades.gd` | 20/20 |
| `test_xp_upgrade_effects.gd` | 65/65 |

The passing count is separate from the supplemental reproductions above. The new suite checks deadzone helper output, but never asserts that `get_flight_input()` stays zero for sub-deadzone noise. Its multiple-device check mainly asserts selection state. Its live circle assertion at lines 529–531 counts requests with world-intent magnitude over 0.9; it does not check the real trajectory's direction/speed error or smoothness.

The untracked `tools/render_controller_360_gameplay.gd` is a staged showcase with hard-coded speed, distortion, symmetry and hardware strings. It does not measure those values. It should not be used as quantitative gameplay or hardware proof.

New rendered main-scene captures used 960x540, 1280x720, 1920x1080, 1024x768 and 2560x1080 windows with the project's logical-canvas behavior. With score/high-score values of 1,234,567, coins 999,999 and kills 9,999, the stats grid measured `(18,16)` with size `(370,46)`. The 1280-wide logical timer starts at x=500; their rectangles no longer overlap. The same check passed all five sizes. This verifies that specific repair, not every alert combination or accessibility setting.

The new rendered pose diagnostic observed roughly -18 degrees forward pitch and -11.2 degrees sideways bank after one second, compared with the earlier approximately -7.1-degree sideways bank. Main/tail rotors resolve correctly; the three optional component hooks remain null. These are staged poses rather than a full human control-feel assessment.

The rendered process detected `XInput Controller`, device 0, with a recognized mapping. Headless suites reported no connected pads and used synthetic events. No hands-on hardware feel or rumble-strength test was performed, so a blank headless pad list is not used to claim that the machine has no connected controller.

Two supplied suites retain their known five-ObjectDB-instance exit warnings. The stability suite intentionally emits its invalid-upgrade-choice rejection warning. Completed gameplay suites and final diagnostic logs contain no script errors. Earlier diagnostic authoring had a type-inference parse error; it was corrected before the final probe runs. Boss dimensions were not verified: the scale diagnostic's ordinary boss spawn request is rejected, so actual biome boss routing still needs separate review.

## Evidence and recommended next work

All fresh logs, probe scripts and captures are under `artifacts/implementation-review-2026-11-04/` (Git-ignored). `targeted-probe.log` records the additional failures. `render.log` records layout, mesh bounds, bindings and poses. The five `hud-*.png` images show the long-value HUD.

Fix the final movement-command deadzone/device leak first. Then correct envelope coordinate transforms and aiming update order, and add regressions at those authoritative boundaries. Complete the camera/model proportion audit and imported-model flight presentation separately, using measured normal gameplay evidence rather than declaring the broader prompts complete from the existing green suites.
