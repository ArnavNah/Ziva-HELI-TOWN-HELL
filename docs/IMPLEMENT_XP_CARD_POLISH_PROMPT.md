# Polish XP feedback and professional level-up cards

Implement in `C:/Users/Prime 3/Documents/ziva-heli-town-helll` after gameplay stability and XP/upgrade functionality are corrected. Read AGENTS.md, the current audit, both preceding prompts and live UI source. Preserve the game renderer, combat camera, imported enemy models and working menu flow. Use the current actual Godot dialog capture and the proposed card preview in `docs/gameplay-repair-and-upgrade-polish.html` as review references; the browser preview is not installed game UI.

The user wants a professional, readable upgrade choice with real effects, and satisfying XP collection. Build this in Godot using reusable Controls, themes and lightweight icons. Do not deliver only a mockup or make functional promises that the upgrade catalog cannot supply.

## 1. Clear visual direction

Use a restrained tactical aviation style: deep charcoal/olive surfaces, warm ivory readable text, one controlled amber selection accent, small category colors and thin borders. Fit the existing low-poly military identity while improving hierarchy and typography. Avoid giant ASCII separators, emoji-dependent badges, dense paragraphs inside plain Button.text, flashing rainbow rarity borders, costly full-screen effects or illegible condensed pixel text for descriptions.

Replace the current three 230×130-ish text buttons with a reusable card component: icon area, category/rarity label, strong title, short mechanical benefit, precise before → after rows, rank/stack indicator, prerequisite/cap/duration context and a clear select affordance. Use proper child Controls and focus ownership. A card is a single focusable action; decorative labels/icons must not block clicks. Use a unified icon family with original SVG/vector or code-native shapes, not unrelated illustrations. Keep selection state distinct from hover and keyboard/gamepad focus.

At 1280×720 aim for a centered panel around 1,040 px wide with three approximately 300–320 px cards and generous consistent gaps; treat this as a design starting point and test actual text. Fit 960×540 without cropping. Support 16:10, ultrawide and UI scaling; reflow/scroll intentionally where needed. Use safe margins and avoid placing critical stats behind HUD, the mouse pointer or a bright world area. Dim the game behind the modal and clearly state that combat is paused.

Use roughly 24–30 px modal heading, 20–24 px card titles and 15–17 px benefit/stat text at the reference resolution, adjusted to actual font metrics. Keep sufficient contrast and clear labels independent of color. Integrate existing menu typography where readable; do not require a remote font or external web runtime in Godot.

## 2. Show true effects and useful choices

Bind card text and before/after values to the corrected upgrade catalog and effective-stat previews, not a second hand-authored dictionary. Examples should show +15% damage with real affected weapon values, armor 0% → 6%, maximum/current hull changes, and capacity increases that persist after reload. Mark temporary effects with duration, one-time effects with their exact scope and already-maxed effects as unavailable. Show prerequisites and ranks only when meaningful. No fabricated rarity, synergy or stats.

Use a compact build summary or details affordance if needed; do not overload the three main cards. Display the current offered level and additional queued choices unambiguously, including multi-level pickup batches. Offer a helpful empty-state if no eligible cards remain, with a defined progression action rather than trapping the run. A capped/no-effect option must not look selectable as a useful upgrade.

## 3. Input, animation and pause ownership

Preserve mouse selection, 1/2/3 shortcuts, focus arrows/Tab, gamepad navigation and explicit confirm. Give an obvious focus outline and readable shortcut hints. Prevent key-repeat, held-fire click-through, double-click or simultaneous inputs from applying twice. Validate through the progression transaction; UI success appears only after the authoritative apply result. Reject stale choices gracefully without consuming the choice. Handle player death or modal ownership change before commit.

Use a restrained 150–220 ms panel/card entrance, subtle hover/focus lift and a short confirmed-selection transition. Kill or replace old tweens on reopen/scene change. Animate UI while gameplay is paused without advancing fuel, enemies, projectiles or wave clocks. Respect reduced-motion preferences if available, and avoid a long mandatory selection animation. Escape behavior must be explicit; it cannot silently lose a mandatory queued choice or unpause under another modal.

After a valid apply, show a small catalog-driven confirmation with the actual new stat, then safely resume according to the queue/state contract. Make the next card's timing understandable without repeatedly yanking control away from the pilot. Do not block input longer than needed or skip a queued choice.

## 4. XP collection feel

Keep XP distinct from coins, ammo and repairs through silhouette, color and sound: for example a cyan faceted gem against muted ground with modest rim/emission. Preserve altitude-aware attraction and fast-flight collection. Add a brief readable pickup lift/arc and acceleration into the aircraft, a small absorption sparkle, and a throttled collection sound whose volume/count stays comfortable during dense drops. Avoid turning every gem into an expensive transparent effect, light or HUD popup.

Animate the XP bar smoothly toward its authoritative value while showing truthful numeric progress and a clear level label. Preserve overflow, queued levels and max-level display. Coalesce rapid gains into a small '+XP' burst near the bar instead of covering the helicopter with separate floating numbers. Merged gems must keep their total value. The visual count-up must not itself grant XP or decide levels. Define whether pickup cosmetic fades continue during a selection; gameplay reward ownership stays with the XP system.

A level threshold should give a short audiovisual cue, then the existing safe presentation timing. Distinguish a reward cue from an urgent damage/lock warning. No overwhelming screen shake, strobe or occlusion during missile threats. Handle pause, pickup teardown, lost player targets and full-level cap cleanly.

## 5. Verify the real experience

Run the actual enemy kill → XP pickup → threshold → three-card offer → selection → changed gameplay loop. Verify the selected upgrade with actual shooting, damage/armor, reload, speed or fuel as appropriate. Screenshots alone do not prove it works. All card descriptions and before/after numbers must agree with measured effective stats after floors/caps/loadout modifiers.

Capture the current versus final modal at 1280×720 and 960×540, an input-focus state, a capped/locked/empty state, a queued multi-level case and a short pickup-to-selection-to-combat video or repeatable demonstration. Test mouse, keyboard and gamepad where available, pausing, restarting and dying during transitions. Report unsupported input coverage honestly.

Measure UI node counts, texture use, pickup counts and frame-time impact in comparable scenes; pool/share assets where useful and avoid per-card material/texture duplication. Maintain the current GL Compatibility renderer. Deliver reusable card/theme components, catalog bindings, collection/bar feedback, focused tests and the rendered evidence. Do not call the task complete with only browser HTML or with effects that exist solely in card copy.
