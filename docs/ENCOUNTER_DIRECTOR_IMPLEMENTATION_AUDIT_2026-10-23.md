# Autonomous encounter director — implementation audit

**Repair follow-up:** production fixes and fresh verification are recorded in [the repair results](ENCOUNTER_DIRECTOR_REPAIR_RESULTS_2026-10-23.md). The findings below describe the pre-repair snapshot.

23 October 2026. Compared current source with the user's supplied implementation prompt. **Verdict: substantial partial implementation, with release-blocking defects. It is not implemented properly end to end.** Gameplay source was not changed during this audit.

## Confirmed failures, in priority order

### P1 — Normal wave progression stalls after the first clear

`autoload/combat_director.gd:235` makes combat ineligible when `is_wave_active` is false. `_process` returns immediately on that condition, before processing the intermission timer. `_complete_current_wave` sets `is_wave_active = false` and starts a three-second transition.

Runtime: clear wave 1, then manually step four seconds at 60 Hz. The director remains on wave 1, inactive, with transition timer still exactly 3.0 seconds. This blocks normal advancement into subsequent waves. The new suite misses it because its progression check calls `_setup_wave(10)` and `_setup_wave(11)` directly.

Required repair: process eligible intermission time separately from active-wave purchasing. Keep non-combat states frozen while allowing normal wave transitions, and stop the current frame's purchases once a wave completes.

### P1 — Shielded spawn cards throw a script error and leak reservations

`src/enemies/enemy_spawner.gd:266` assigns `DamageReceiver.has_shield`, followed by `shield_points` and `max_shield_points`. The actual receiver uses `shield_health`; those assigned fields do not exist.

Runtime: spawning `scout_buggy_shielded` produces `Invalid assignment of property or key 'has_shield'`. The enemy has zero shield health and the reserved population remains 1 instead of being released. This card becomes eligible at wave 4. The gunship shield card uses the same broken branch.

Modifiers are assigned after the enemy is added to the tree, so BaseEnemy's `_ready()` modifier application has already happened. The manual elite branch then implements different health/reward behavior from the existing modifier path. Initialize the purchased modifier before ready, or provide one explicit initialization API; apply it once and finish/refund reservations reliably on failure.

### P1 — Off-screen warning duration does not enforce a preparation window

`src/enemies/base_enemy.gd:417` sets the real telegraph timer to the requested duration. At `:449`, the warning advertises at least 1.5 seconds without extending that timer.

Runtime: an off-screen threat requests a 0.4-second telegraph. The emitted warning duration is 1.5 seconds, while the actual telegraph timer remains 0.4. Heavy controllers use this telegraph path for their windup. The warning therefore does not provide the promised preparation time.

Required repair: compute an effective off-screen preparation duration before starting both the warning and attack state machine. Test the earliest possible damaging shot, not only signal existence.

### P1 — Public spawning bypasses population safeguards

`src/enemies/enemy_spawner.gd:350` checks a variant cap only when no custom position is supplied. It does not enforce the director's total population limit, reservations or wave gates through this public API. `spawn_director_card` also trusts its caller instead of enforcing the shared public contract.

Runtime: with target population 1 and Scout Buggy cap 5, eight calls using custom positions create eight living buggies with `allow_test_bypass = false`. This contradicts the prompt's requirement for explicit fixture bypasses and shared production validation.

Required repair: shared eligibility/cap validation for production calls, with a clearly restricted fixture path. Treat boss/scripted exceptions explicitly rather than implicitly trusting positions.

## Additional missing or partial requirements

| Requirement | Current finding |
| --- | --- |
| Hidden spawning | Ground skips frustum rejection after attempt 19; air after attempt 27 (`enemy_spawner.gd:463`, `:517`). Both check a point rather than model bounds. Visible instant spawning remains possible. |
| Ground surface validation | Returns fixed Y=0.1 (`:489`), without a terrain-height/route-connectivity contract. Street distance and overlap checks provide partial protection only. |
| Reproducible encounters | Card selection uses a dedicated seeded RNG, but spawner `_ready()` calls `encounter_rng.randomize()` (`:45`) and air altitude uses global `randf_range` (`:493`). New-run director initialization does not reseed placement or explicitly reset its cohort state. Full placement is not reproducible from the recorded director seed. |
| No stall catch-up | A five-second `_process` delta awards about 35.23 fast / 22.65 slow credits and five seconds of active time. Income is capped by wallet size, but no frame-stall catch-up prevention is present. |
| Category-first selection | `_select_weighted_card` selects directly across cards. There is no weighted category draw before the card draw. |
| Wave-group composition pools | No small selected composition pool/refresh on gates is implemented; the full eligible catalog is used. |
| Family/category caps | Total and variant limits exist in catalog filtering; separate family/category population caps and reservations are absent. |
| Data validation | SpawnCard validates basic ID/variant/cost/weight/group/category fields. It does not fully validate stream names, supported modifiers, conflicting gates/caps or duplicate catalog IDs. Group costs also deserve clarification: duo cards are priced 24/16 and multiplied by group size again, producing 48/32 total. |
| Retirement dwell/hysteresis | Family thresholds exist, but there is no per-enemy dwell/hysteresis. Visible-center protection is overridden beyond 260 m; mission-target exclusion is absent. Only WINDUP/FIRE are protected as engagement states. |
| Transaction identity | Reservations/refunds use counts and caller-supplied costs without once-only transaction IDs. Current synchronous normal calls limit exposure, but duplicate callbacks are not guarded. The real shield error already leaves a reservation stuck. |
| Bounded telemetry | Counters and last sector/distance exist. The requested bounded decision history with eligibility/rejection reasons, wallets and lease context is incomplete. |
| Boss flow | One boss is created by direct wave setup and living-boss timer checks exist. Natural progression, actual rendered boss operation, defeat → decision → extraction/endless flow are not proved by these checks. |

## What is implemented

- Typed SpawnCard and catalog derived from EnemyData specifications.
- Separate fast/slow wallets, income rates, evaluation cadences, wallet caps and bounded purchases.
- Credit-mode spawner disables legacy opening/replenishment, avoiding two simultaneous automatic purchase loops.
- Income tied to active time, wave, selected difficulty and theme.
- Pause gating and no income at the population target.
- Automatic catalog gates, variant caps and total-cap filtering.
- Five active ground variants, twelve air variants and two support variants retained; disabled ground roster rejected by the ordinary enabled check.
- Explicit costed elite/shield cards replace the old random modifier roll, although their application is faulty as described above.
- Combined attack-slot API and lease cleanup, plus directional warning UI integration.
- Family-specific retirement and direct queue-free behavior without invoking normal kill rewards.

These foundations are useful, but do not outweigh the progression and runtime failures.

## Fresh verification

1. `tests/test_autonomous_encounter_director.gd`: **48 passed, 0 failed**. This is not full acceptance despite the printed “all 11 categories” message. It does not exercise a natural intermission, purchased shield cards, actual hidden placement bounds, a damaging shot after warning, or physical XP collection into a draft. Its XP case only proves that a lethal receiver hit does not immediately grant XP. Its retirement assertions run before processing queued deletion.
2. `tests/verify_active_ground_roster.gd`: **0 failures**, including 9,600 wave/theme selections and retained ground instantiation. This supports roster preservation, not the new director's complete behavior.
3. Added observational fixture `artifacts/director-audit-20261023/recheck.gd`: **runner exit 1**, due to the reproduced production shield script error. Other observed failures are recorded in its JSON/log; exit status is not their individual assertion result.

Reproduce:

```powershell
python tools/run_strike_checks.py headless tests/test_autonomous_encounter_director.gd
python tools/run_strike_checks.py headless tests/verify_active_ground_roster.gd
python tools/run_strike_checks.py headless artifacts/director-audit-20261023/recheck.gd
```

Evidence:
- `artifacts/director-audit-20261023/observations.json`
- `artifacts/strike-recheck.log`
- `artifacts/strike-test_autonomous_encounter_director.log`
- `artifacts/strike-verify_active_ground_roster.log`

Tests also report ObjectDB leaks at exit.

## Acceptance evidence is still insufficient

The supplied simulation script increases player hull/max hull to 9,999, directly injects XP with `add_xp(25)` and manually jumps to waves 6/10. Its 3,600 physics frames are not proof of 60 seconds of active Normal combat or natural wave progression, and its flight-input overrides do not demonstrate active firing. Render scripts manually arrange enemies and start telegraphs; these can illustrate rigs but cannot prove autonomous director behavior.

This audit did not run a complete rendered moving/firing encounter or certify frame-time comparisons, all five rigs' combat animation, minelayer behavior, full reward collection, or boss/extraction acceptance. Existing demonstration scripts cannot substitute for those requirements. Resolve the confirmed blockers first, add meaningful regressions, then capture the actual unmodified encounter loop and comparable performance evidence.
