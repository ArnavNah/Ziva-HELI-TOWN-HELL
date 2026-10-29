# Regular wave roster — 30 October 2026

The five placeholder drone types are excluded from ordinary waves:

- `hunter_drone`
- `scout_drone`
- `kamikaze_drone`
- `shield_drone`
- `repair_drone`

`EnemyData.is_regular_wave_variant()` is the shared selection policy. Both credit-director streams, composition pools, the legacy wave sampler, normal public spawning, and manual ordinary-card purchases enforce it. Rejected purchases do not spend credits or retain reservations.

The seven active ground vehicles and nine modeled non-boss aircraft roles remain available. Existing unlock gates and per-variant caps are retained: Skyrunner starts at wave 2; Iron Viper and Crimson Desert gunships still start at waves 6 and 7.

Wave 1 now has only Scout Buggy available. Its ground-share restriction is suspended until a modeled aircraft is unlocked, allowing the existing five-unit cap to fill the opening population. Population targets are bounded by the unlocked roster's total capacity, including on higher difficulty. This avoids reserving population for aircraft that cannot be selected.

Source controllers, procedural visuals, and drone source cards are preserved. Explicit fixture spawning can still instantiate them. The modular Titan's living launch-bay route retains its budgeted, alternating kamikaze/interceptor escorts; that path is separate from ordinary replenishment. Boss health, phases, components, rewards, and encounter transactions are unchanged.

## Verification

| Check | Result |
|---|---|
| `tests/test_regular_wave_roster.gd` | **39/39 passed** |
| `tests/test_director_regressions.gd` | **46/46 passed** |
| `tests/test_seven_ground_vehicles_integration.gd`, rendered | **64/64 passed** |
| `tests/test_air_enemy_integration.gd` | **174/174 passed** |
| Actual opening wave in the generated town | Five Scout Buggies, each with eight imported mesh instances; no placeholder drones |

The roster suite checks all themes and both streams across waves 1–25, repeated legacy selection, direct admission rejection, untouched wallets on failed purchases, source availability, full opening population, replenishment after a loss, higher-difficulty capacity, wave-2 aircraft eligibility, and actual Titan escort launches. Runtime error logs for these runs are clean.

Before this update, an ordinary opening-wave capture produced four procedural Hunter Drones and one Scout Buggy. After this update, the same main-scene audit produced five Scout Buggies. The city audit uses normal automatic wave spawning rather than a test spawn bypass.

Logs and the updated opening-wave capture are under the Git-ignored `artifacts/regular-wave-roster/` directory. Start a new run to apply the roster change to a fresh enemy population; already-spawned entities in an older running session are not forcibly deleted.
