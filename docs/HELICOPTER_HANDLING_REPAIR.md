# Helicopter left/right handling — 2026-10-23

The user confirmed both A/D turning and Q/E sideways movement needed improvement. Existing controls remain in place.

Changes in `src/player/player_helicopter.gd`:

- Turning now has bounded acceleration and stronger release/reversal braking, rather than an exponential response with a large first-frame angular acceleration. Hover turns have slightly more yaw authority than forward-flight turns.
- Forward and sideways velocities are controlled independently in the helicopter's horizontal frame. Releasing a strafe command now uses the same braking behavior with or without forward thrust.
- Sideways thrust has bounded acceleration, a short rotor-response ramp, and proportional corrections near the target velocity. This avoids sharp reversal spikes and full-strength corrections around cruising speed.
- Roll leans into sideways acceleration, counter-banks during lateral braking, and uses a faster damped response. Turn banking scales with airspeed, so rotating in place does not lean like a fast flying turn.
- Idle visual sway blends down during active flight inputs. Lateral acceleration resets during a dash to prevent stale steering forces afterward.
- Existing aircraft/cargo/engine/handling modifiers, collision handling, vertical flight, dash behavior, and speed limits remain connected.

Measured on the Apache with a healthy engine and no cargo/modifiers:

| Measurement | Before | After |
| --- | ---: | ---: |
| Sideways stopping distance, no forward input | 4.10 m | 4.05 m |
| Sideways stopping distance, forward input held | 5.43 m | 4.05 m |
| Peak lateral acceleration during reversal | 202.49 m/s² | 89.70 m/s² |
| Initial yaw acceleration | 690.98°/s² | 260.00°/s² |
| Bank during a sustained hover turn | 16.15° | 3.05° |
| Time to reverse lateral velocity from 24 m/s | 0.17 s | 0.32 s |
| Sideways speed after one second | 25.53 m/s | 25.92 m/s |

The longer direction reversal deliberately removes the instantaneous snap while still reversing within roughly a third of a second. Yaw release settles in approximately 0.16 seconds from the Apache's full hover turn rate.

Verification:

- `tests/test_helicopter_lateral_handling.gd`: **16/16 passed**. Covers left/right symmetry, braking with/without forward input, reversal acceleration, hover banking, yaw release, diagonal speed limits, response at 30/60/120 physics ticks, and turning behavior for Apache, Nighthawk, and Warlock.
- `tests/verify_playability_game_loop.gd`: **20/20 passed**, including unchanged forward acceleration/braking, camera yaw lag below 5°, aiming, weapons, and XP pickups.
- `tests/test_gameplay_stability_and_upgrades.gd`: **20/20 passed**, including dash/shield protection, damage handling, and speed/drag upgrades.

No script/runtime errors were reported in these final runs. The existing headless shutdown ObjectDB warnings can still occur in the broader suites.

Evidence: `artifacts/helicopter-lateral-handling-before.json`, `artifacts/helicopter-lateral-handling-results.json`, and the corresponding logs in `artifacts/menu-repair-tests/`.

Source snapshots are saved under `.codex-backups/flight-handling-20261023/`.
