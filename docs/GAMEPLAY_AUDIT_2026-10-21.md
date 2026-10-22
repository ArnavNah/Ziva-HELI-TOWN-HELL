# Gameplay and progression audit — 21 October 2026

Request: investigate rapid death with apparent remaining health, overall playability, XP collection, level-up card design, and whether upgrades affect gameplay. This document records inspection and diagnostic results; it does not certify that the game is fixed.

## Confirmed by current-code runtime diagnostics

1. **Collision scraping bypasses protection.** In a controlled real-player/floor fixture, 12 contact steps at 60 Hz reduced hull from 100 to 95.6 even with `is_invulnerable=true` and armor mitigation 0.24. `_process_collision_damage()` subtracts scraping damage directly instead of going through the protected damage path. Static source rates are 22 hull/s for ground contact and 25 hull/s for wall contact, before collision resistance. The initial fixture had no contacts because Player._ready reset the supplied altitude; it was corrected to set position after ready, then reproduced the loss with 12 actual contacts.
2. **Enemy explosion scaling is applied twice.** A base-10 hit with enemy multiplier 1.25 becomes a 12.5 payload. Actual Projectile._explode at the player's center then dealt 15.625, rather than 12.5. The explosion constructs new DamageData with an already-scaled amount and the same attacker, causing the constructor to apply the multiplier again.
3. **The HUD can briefly show 35 while authoritative hull is already zero.** A controlled real-game test refreshed the HUD to 35/100, applied a 40-damage hit, and immediately observed `is_dying=true`, actual hull 0, but the old label still read 35/100. After 0.15 s it read 0/100. HUD survival polling is about 0.1 s and its damage handler currently updates hit flash rather than immediately refreshing health. This demonstrates transient stale display, not proof that death is triggered while authoritative hull remains positive. A hit larger than 35 legitimately kills a 35-hull aircraft.
4. **Extended Mag is transient and ineffective on an empty magazine.** On the current 300-round machine gun, selection changed current ammo to 390; a subsequent reload restored 300. Selecting it with zero ammo left zero. Its current implementation multiplies remaining rounds rather than defining an upgraded capacity; the UI describes a refill, which is also misleading when empty. A persistent-capacity redesign is proposed in the repair prompt, not a claim that the existing UI promises permanence.
5. **Invalid upgrade applications consume a choice.** Calling `apply_upgrade_choice("NOT_AN_OFFERED_UPGRADE")` with a legitimate queued offer cleared the offer list and consumed its queued selection. The UI has a membership check, but the progression method itself lacks transaction/state validation.
6. **Not every upgrade is broken.** Vector Jets changed cruise speed 36 → 41.4, and Overclock Rounds changed a damage multiplier 1.0 → 1.15 in the fixture. These are verified stat changes; actual measured flight speed and damage to a target still require end-to-end tests.

Diagnostic source: `artifacts/gameplay-audit-20261021/audit_current.gd`.
Results: `artifacts/gameplay-audit-20261021/observations.json` and `artifacts/strike-audit_current.log`.

## Confirmed source behavior and important risks

- Hard impacts use a 0.22 s cooldown and can deal 15–50 ground or 20–60 wall damage. A single impact can exceed 35 hull; repeated contact can combine large impact packets with continuous scraping. Enemy bodies and other colliders are classified by contact normals without first confirming the collider is a building or terrain. Repeated-contact classification and cooldown design need explicit investigation.
- Dash termination unconditionally clears `is_invulnerable`, while shields also own that flag. A dash finishing during an active shield can create an ordering-dependent protection gap. Scraping bypasses that flag entirely.
- The damage API emits its damaged event before `_die()` clamps health to zero; a lethal event can contain a negative hull value. Healing and terminal death-state transitions also need centralized guards.
- Volatile hazards query damage in a large area without the projectile explosion path's equivalent falloff/cover rules. Player-fired projectile explosions query both player and enemy collision layers. Owner/self-damage and chain-explosion policies need explicit, consistent validation; presence of these paths alone does not prove a specific user death came from them.
- The observed 35% low-health vignette is visual feedback. No explicit “die at 35%” threshold was found in the inspected death path. Capture the actual source, hit history, true hull and displayed hull before assigning the user's particular incident to a cause.
- Normal enemy death emits zero direct XP so LootManager gems govern progression. GameManager still supports positive direct kill-XP grants, which can duplicate an award if a future/current special emitter also spawns a normal gem. This is a conditional risk, not a demonstrated default-kill double-award.
- XP pickup collection updates RunProgression directly; GameManager.run_xp is not updated on that path. The main XP HUD reads RunProgression. This is a split ledger, not proof that the visible XP bar is currently using the wrong value.
- XP merges can combine values while pickups are moving; expiry, target validity, maximum level, interrupted pickup tweens and scene transitions need real event-path tests. Current magnet envelopes are generous: XP/coin minimum radius 85 m and immediate attraction for kill drops within a 140 m horizontal / 50 m vertical combat envelope. Do not enlarge them further without checking feel and conservation of XP.
- RunProgression does not currently validate all GameManager states in its offer routine: MENU/PAUSED/EXTRACTION deserve review alongside its existing RESULTS/LOADING/BOSS_DECISION guards. Applying any name currently resumes ACTIVE immediately.
- Upgrade data and display copy are separate match/dictionary definitions. Ghost Rotor advertises reduced drag but only multiplies cruise_speed in the inspected effect code. Airstrike copy says “nearby,” but its effect iterates all enemies without a distance filter. Vulcan Storm describes twin rotaries but its inspected effect is a fire-rate change; do not invent unsupported visual/mechanical promises.
- Capped or exhausted benefits can remain in the available pool: armor capped at 24%, fuel drain floored at 0.4, cooldown floors, duplicate evolution/legendary state, speed caps, full-health repair usefulness and invalid component references need preview/eligibility handling.

## Live sample and present UI

Ran the actual main-game scene with seed 21021, zero flight input, weapons input disabled and normal damage enabled for a 15 s observation window. This was intentionally stationary and unarmed, not a skilled-play balance benchmark. The first recorded damage was around run time 5.36 s, with multiple bullet hits and small contact-scrape packets. Hull crossed zero around 8.98 s. It demonstrates damage stacking in a real scene; it does not reproduce death within the first second of a normal moving/firing run.

The player's low position in the final sample is after its death sequence, so it must not be used as evidence that neutral flight itself dropped the live helicopter onto the ground. The death handler's run settlement was disconnected in this fixture so it would not save a real run result. Rendering and modal screenshots reported low FPS during this run; this is not a controlled performance benchmark, but frame-time profiling belongs in the playability investigation.

Captured the actual current upgrade dialog from the real scene with a controlled offer fixture. It uses three short text buttons, colored borders, category text and keyboard hints, not a complete professional card hierarchy. Image: `artifacts/gameplay-audit-20261021/current-upgrade-cards.png`. Live image: `artifacts/gameplay-audit-20261021/live-current.png`. Log: `artifacts/strike-render_current.log`.

## Existing tests and their limitations

`tests/test_xp_pacing_and_level_up_cards.gd` returned **6/6**. Its comments and pass text describe a calibrated enemy drop and no double attribution, but the relevant tests manually spawn a value-1 gem and directly call add_run_xp(2); they do not kill a real enemy then collect its real drop. The actual current hunter-drone spec is 3 XP and LootManager clamps normal variant drops to 2–10 XP. Passing this suite does not prove the real kill/drop/collect path or every card effect works.

The new diagnostic fixture returned eight observed cases and the rendered fixture exited cleanly. The headless fixture reported ObjectDB cleanup leaks at exit; it is diagnostic coverage, not an accepted gameplay regression suite. Production gameplay source was not edited during this audit.

## Recommended repair order

1. Run `docs/IMPLEMENT_GAMEPLAY_STABILITY_PROMPT.md`: death/health truth, one-time damage scaling, contact handling, survivability, telemetry and playability checks.
2. Run `docs/IMPLEMENT_XP_UPGRADE_FUNCTIONALITY_PROMPT.md`: XP conservation, a single progression ledger, transactional upgrades, effective stats and real gameplay effects.
3. Run `docs/IMPLEMENT_XP_CARD_POLISH_PROMPT.md`: collection feedback and accessible professional cards driven by the corrected upgrade data.

The combined HTML guide contains these complete prompts, the audit summary, current UI capture and a proposed card-design preview. The design preview is a browser concept, not an installed Godot UI or proof of fixed upgrade behavior.
