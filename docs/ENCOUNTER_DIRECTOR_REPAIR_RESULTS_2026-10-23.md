# Encounter director repair results — 23 October 2026

The confirmed director defects from the preceding audit have been repaired in production code. No enemy source models, shared wheels, ground roster enablement, environment or player camera were replaced. XpManager and LevelUpUi remain the production progression path.

## Changes

| Area | Repair |
| --- | --- |
| Wave transitions | Intermission time advances independently from active-wave purchasing. Clearing a wave stops purchases in the same frame; the normal three-second transition reaches the next wave. |
| Shielded/elite cards | Purchased modifiers are assigned before adding the enemy to the tree, so BaseEnemy initializes real shields, health, rewards and collider adjustments once. Removed assignments to nonexistent receiver fields. |
| Spending and refunds | Purchases reserve credits, total population and variant population under a unique token. Each group member has its own once-only settlement identity. Failures refund the reserved member cost; stale/repeated callbacks cannot spend/refund twice. New runs invalidate old tokens. |
| Public spawn safeguards | Ordinary calls enforce enabled roster, wave gates, total/variant limits, reservations and eligible combat state even when a custom position is supplied. Custom positions also respect the exclusion radius and visible bounds guard. Fixture bypass remains explicit and cannot enable disabled vehicles. |
| Warnings | Off-screen heavy/long-range preparation extends the actual telegraph timer to at least 1.5 seconds. The HUD warning uses that same timer rather than promising more time than the attack provides. |
| Hidden placement | Every candidate attempt respects conservative model bounds against the camera frustum; there is no late-attempt visible-pop-in escape. Failed searches defer/refund. Rail cannon overhang gets a larger bound. |
| Ground/air placement | Ground candidates raycast the actual floor, reject absent/steep/roof surfaces, check street corridors and clearance, and use surface height. Air altitude uses the encounter RNG and verifies roof clearance/altitude bounds. |
| Reproducibility | Spawner RNG and cohort state reset from the encounter seed each run. Air altitude no longer consumes global randomness. This reproduces spawn decisions for the same world, inputs and simulation steps, not arbitrary complete combat runs. |
| Composition | Category-first weighted selection and a small refreshed eligible variant pool provide directional variety while retaining basic pressure and newly unlocked variants. Ground share/support caps complement total and variant caps. |
| Retirement | Distant units require eight seconds of eligible encounter time before retirement. Visible bounds, engagement reach, windup/fire, bosses and mission-target groups protect units from disappearance. Retirement remains administrative, with no death rewards. |
| Stall behavior | Director simulation delta is capped at 0.1 seconds; a stalled frame cannot pay a full backlog of credits or evaluations. |
| Catalog validation/costs | Added gate/cap/group, stream, modifier, finite-weight and duplicate-ID validation. Duo card prices are explicitly per member, avoiding accidental double group pricing. |
| Boss | Director-created boss now has visible gunship geometry, rotor animation and a physical enemy collider. It acquires attack leases and telegraphs its attacks. Repeated director evaluation cannot duplicate the milestone boss; a living boss prevents timer-only completion. |
| Boss settlement | Destruction settles bounty/salvage/repair once. Showing the decision modal no longer pays them a second time. Duplicate destruction callbacks are ignored. |
| Telemetry | Bounded purchase/refund decision history includes seed, wave, time, wallets and reservations. Enemy-shot telemetry now excludes player projectiles. |

## Automated validation

| Suite | Result |
| --- | --- |
| `tests/test_director_regressions.gd` | **46 passed, 0 failed** |
| `tests/test_autonomous_encounter_director.gd` | **48 passed, 0 failed** |
| `tests/verify_active_ground_roster.gd` | **0 failures**, including 9,600 wave/theme selections and all five retained rigs instantiating |
| `tests/test_xp_upgrade_effects.gd` | **62/62 passed**, including real physical XP collection, card effects and reset |
| `tests/test_gameplay_stability_and_upgrades.gd` | **20/20 passed** |

New regressions exercise real purchased shield/elite initialization, natural intermission, non-combat public-call rejection, frame-stall income, custom-position caps, member-level duplicate refunds, stale tokens, all-attempt hidden placement, model-bounds visibility, seeded altitude, surface placement, real windup gates, retirement dwell/deletion, boss physical registration, defeat → paused decision → endless button, and once-only boss rewards.

The existing roster fixture now explicitly opts into fixture bypass when filling all rigs regardless of live wave/population gates. Its disabled-roster assertions remain strict. The basic director suite now steps ordinary frames for income and uses real reservation/refund APIs instead of manually changing a counter. Its summary no longer claims complete acceptance of every original prompt category.

## Rendered game verification

Used the real main scene, generated city, player aircraft/controllers, held primary fire, camera, enemy AI and normal hull. Test profiles live under `artifacts/director-repair-20261023/`; no real player profile was used for these gameplay runs.

- An uninterrupted moving/firing patrol naturally reached **wave 2**, made 724 firing actions and two kills, then died at approximately **53.84 seconds**. It did not meet the uninterrupted 60-second survival target. Its observations are preserved in `continuous-patrol.json`.
- The final retry scenario completed **62.01 seconds of active gameplay across two sorties**, including an actual death/results/loading/retry path. It made **764 firing actions**, respected the early population target of five, ended with **zero reserved population**, and the runner returned **exit 0 with no script errors**. The second aircraft ended at **85 hull**. These are aggregate active seconds across a retry, not 62 seconds of uninterrupted survival. Neither shorter sortie reached wave two in that particular run.
- No health inflation, direct XP injection, forced wave setup or invulnerability was used in these rendered patrols. The fixture supplies flight controls and virtual cursor input through the real aiming solver. Later versions release held fire for the real retry input-arming contract.
- Final rendered sample: OpenGL Compatibility, Intel Iris Xe, median process frame **26.94 ms**, p95 **119.07 ms**. This is an absolute sample with the editor/other activity present, not a controlled before/after performance improvement claim.

Evidence:

- `artifacts/director-repair-20261023/gameplay.json`
- `artifacts/director-repair-20261023/gameplay.png`
- `artifacts/director-repair-20261023/continuous-patrol.json`
- `artifacts/director-repair-20261023/untargeted-patrol.json`
- `artifacts/strike-verify_director_gameplay.log`
- `artifacts/strike-test_director_regressions.log`
- Other suite logs use their script stem under `artifacts/strike-*.log`.

Reproduce the rendered retry case:

```powershell
$env:ZIVA_TEST_DATA_DIR = Join-Path (Get-Location) 'artifacts/director-repair-20261023/retry-test-profile'
python tools/run_strike_checks.py render tests/verify_director_gameplay.gd --audio-driver Dummy --disable-vsync --max-fps 60 -- --retry-cycle
```

Omit `-- --retry-cycle` to request the separate uninterrupted-survival probe, which requires sixty active seconds and natural wave advancement. That stronger probe has not passed; automated patrol deaths remain part of the evidence rather than being hidden by enlarged health or changed assertions. Retry mode checks a different scenario and does not require either short sortie to individually last a full wave.

## Limits

The code repairs and regressions are verified. A complete advanced-wave rendered battle, exhaustive all-seed balance assessment, controlled performance baseline and final difficulty tuning remain unverified. The automated pilot can still die; this work does not guarantee survival from all encounters. Some headless suites continue to report ObjectDB shutdown leaks, so teardown is not certified completely clean.

An editor-wide import scan also encountered malformed textures in the inactive future-car asset folders. Active-roster tests and the rendered main scene ran without those assets; they were left untouched in this director repair.
