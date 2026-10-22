# Implementation check — 22 October 2026

**No: the three prompts in `gameplay-repair-and-upgrade-polish.html` are not fully implemented.** This is a source inspection and targeted runtime audit, not an implementation pass. Production gameplay source was left unchanged. Existing unrelated work was preserved.

| Requested work | Status | Evidence |
| --- | --- | --- |
| Gameplay stability and truthful health | Partially implemented | Gentler collisions, shielded scrape protection and immediate lethal HUD update work. Explosion scaling, shield/dash ownership and scrape armor still fail. Full encounter acceptance remains unverified. |
| XP collection and trustworthy upgrades | Incomplete | Basic XP/level queue and several modifiers work. Invalid choices consume rewards, magazine upgrades disappear on reload, and the requested catalog/transactions/effective-stat previews are absent. |
| Professional cards and XP feedback | Requested redesign not implemented | The game still uses three small text Buttons. Existing borders, backdrop, animation and category text are baseline polish; the professional HTML card concept is not installed Godot UI. |

## Runtime reproductions

Fresh results: `artifacts/implementation-check-20261022/observations-expanded.json`. Reproduce with:

```powershell
python tools/run_strike_checks.py headless artifacts/implementation-check-20261022/audit_recheck.gd
```

The diagnostic observes behavior; its exit code 0 means the fixture ran, **not** that these behaviors satisfy requirements.

| Case | Actual current result | Verdict |
| --- | --- | --- |
| Shielded ground scrape | 12 contact ticks, hull 100 → 100 | Targeted fix verified |
| Explosion scaling | Base 10 × wave multiplier 1.25 produces payload 12.5, but center blast deals 15.625 | Still scaled twice |
| Magazine upgrade then reload | 300 → 390 rounds, then reload restores 300 | Capacity persistence missing |
| Magazine upgrade at zero ammo | Remains zero | Existing refill promise fails |
| Invalid, non-offered choice | Clears offers and consumes the queued choice | Authority validation missing |
| Vector Jets | Cruise-speed field 36 → 41.4 | Modifier changes; not a measured flight-benefit acceptance test |
| Overclock Rounds | Damage multiplier 1 → 1.15 | Modifier changes; not a real projectile-hit acceptance test |
| Dash ends during shield | Shield has 4.984 seconds left, but invulnerability becomes false | Protection ownership still broken |
| Wall scraping with 24% armor | 15 ticks remove 1 hull; armor-respecting result would remove 0.76 | Armor still bypassed |
| Lethal hit with HUD bound | Actual hull 0 and label `0/100` immediately | Targeted HUD fix verified |
| 40 damage at 35 hull | Hull reaches zero and dying begins | Legitimate lethal hit, not proof of death at positive hull |

These checks do not reproduce the user's exact original encounter. There is insufficient evidence to declare the rapid-death complaint resolved.

## Source findings and remaining work

### Gameplay stability

- `src/player/player_helicopter.gd:731`: collision processing now respects invulnerability, skips resting/gentle contact, and uses lower impact damage with a longer cooldown. This is useful progress.
- `src/player/player_helicopter.gd:541`: dash completion still clears the shared invulnerability flag without preserving an active shield.
- `src/player/player_helicopter.gd:829`: sustained scraping directly subtracts hull. It applies collision resistance but bypasses the normal armor path.
- `src/combat/damage_data.gd:36` applies the attacker's combat multiplier; `src/combat/projectile.gd:225` constructs another damage payload from already-scaled damage and the same attacker. The runtime reproduction confirms double scaling.
- `src/ui/hud.gd:164` and `:193` update health/death display immediately. The targeted lethal HUD fixture passes.
- `src/player/player_helicopter.gd:1115`: repair still lacks a terminal/dead-player guard. Health mutations remain spread across paths rather than centralized. `_die()` also emits a synthetic damage event; damage-event accounting needs review.
- Contact classification still relies on collision normals rather than the requested collider identity/type contract. The requested damage history and full protection/contact regression matrix have not been demonstrated.
- A seeded 60-second active combat run, advanced-wave balance check, damage burst measurements, complete retry/death flow and comparable performance captures were not completed in this audit. Passing movement checks is insufficient to establish fair encounters.

### XP and upgrade mechanics

- `src/player/run_progression.gd:138`: selection clears offers/decrements the queue before validating the choice. UI-side membership checks cannot protect this authoritative API. Stable IDs, stale-offer protection and an apply-once transaction are missing.
- `src/player/run_progression.gd:172` and `src/player/player_weapons.gd:294`: Extended Mag multiplies current ammo; reload uses the original constant capacity. Refill paths and the HUD denominator also use base capacity.
- `src/player/run_progression.gd:97`: offer-state guards omit MENU/PAUSED; the fixed base pool is not filtered against effective-stat caps. Applying a choice unconditionally returns the manager to ACTIVE.
- Card effects/copy remain separate name-based matches in progression and the UI. The requested shared catalog, effective-stat resolvers and truthful before/after previews are missing.
- `src/player/run_progression.gd:165`: Airstrike hits every enemy in the group, while UI copy promises nearby targets.
- `src/player/run_progression.gd:233`: Ghost Rotor changes cruise speed without implementing its advertised reduced drag. Vulcan Storm changes fire rate without implementing the advertised twin-rotary pattern.
- `autoload/game_manager.gd:345` and `src/loot/pickup.gd:298`: direct kill XP and physical gem XP still use separate bookkeeping routes. A gem normally updates player RunProgression without updating GameManager.run_xp. This is not a unified ledger. Normal enemy death currently supplies zero direct XP, so this audit does **not** claim default kills award XP twice.
- Existing pickup attraction/animation and queued level timing are present. Exact-once collection, merged-value conservation, wrong-run/dead-player callbacks, cap/empty-pool cases and every card's measured gameplay effect have not received the requested end-to-end proof.

### Professional card and XP polish

- `src/ui/upgrade_dialog.gd:65` still sets three Buttons to 230 × 130. Their text includes shortcuts, category text, an ASCII separator and a manually maintained benefit string.
- The requested reusable card with icon area, distinct child Controls, effective before/after rows and cap/prerequisite context is absent. The browser HTML concept is a design reference only.
- Existing backdrop, queued-level subtitle, category styling and entrance animation are partial baseline features, not evidence the full redesign was implemented.
- Catalog-driven confirmations, XP feedback redesign, responsive final captures at 1280 × 720 and 960 × 540, keyboard/gamepad focus evidence, empty/capped-state captures and pickup-to-upgrade-to-combat demonstration are not delivered as required.

## Existing automated checks

| Check | Result | Scope and limitations |
| --- | --- | --- |
| `tests/verify_playability_game_loop.gd` | 20/20 passed after supplying its required `ZIVA_TEST_DATA_DIR` | Covers loading, movement/braking, camera/aim, muzzle behavior and an altitude pickup. Its final “all 5 audit prompts” message refers to a different earlier audit, not these three prompts. |
| `tests/test_xp_pacing_and_level_up_cards.gd` | 6/6 passed | Covers existing XP/card behavior, but some cases manually create a gem or directly grant XP. Does not prove real enemy death → physical drop → collection → catalog card → measured gameplay effect. |
| Dated audit fixture | 11 observations completed | Reproduces the unresolved defects above and the two targeted fixes. It deliberately does not assert that all observations are correct behavior. |

Logs: `artifacts/strike-verify_playability_game_loop.log`, `artifacts/strike-test_xp_pacing_and_level_up_cards.log`, and `artifacts/strike-audit_recheck.log`. Diagnostic runs report ObjectDB leaks at shutdown, so a completely clean teardown is also not established.

## Recommended completion order

1. Fix explosion math, protection ownership and the shared damage/health path; add regressions and reproduce active-combat survivability.
2. Implement validated upgrade transactions, persistent magazine capacity, cap-aware offers and one source of truth for XP/effective stats. Measure each card's actual effect.
3. Build the Godot card component and XP feedback from those verified APIs, then capture responsive/input states and the full playable reward loop.

Do not mark all three prompts complete based on the existing green suites or the browser mockup.
