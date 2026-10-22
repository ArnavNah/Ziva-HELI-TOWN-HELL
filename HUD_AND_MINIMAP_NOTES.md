# Pixel survival HUD and minimap

The HUD follows the supplied reference layout and uses the same Press Start 2P font as the main menu.

- Upper left: elapsed run time, actual collected coins, and hostile unit kills, with clock/coin/skull icons.
- Top center: wave countdown and wave/theme caption.
- Upper right: current player level, with a thin XP progress stripe across the top.
- Compact red hull bar, fuel gauge, weapon ammunition, flares, super charge and objective text remain visible.
- Both clocks freeze during pauses and upgrade selection. Collected coins and kill/time counters reset for a new run.

Hostiles now drop collectible gold coins worth five credits. Collection updates `GameManager.coins_collected` and banked credits exactly once. The displayed coin count measures collection during the run, separate from mission and cargo payments. Destroying buildings awards its existing score without inflating the enemy kill counter. Ground kills use the enemy's declared family, including new procedural vehicles.

The minimap is positioned below the level in the upper right. It rotates with the chase camera, keeps the player centered, and shows the actual player heading and compass directions. Roads and perimeter lines are clipped to its circular face. Markers distinguish ground threats, aerial threats, bosses, gold coins, other pickups, installations and cargo destinations. Far cargo destinations clamp to the map edge. SAM sites, radar towers and ammo depots now register in the marker group; dead enemies are excluded.

HUD readings refresh at 10 Hz and the minimap at 20 Hz. Static pixel icons avoid image dependencies or continuous animation. Ziva MCP was used to create/edit the project scripts, register the scene layout and run GDScript diagnostics.

Validation: 25/25 dedicated checks passed, covering real collection, duplicate-collection prevention, hostile-only kill counts, XP leveling, paused clocks, compact layout, camera orientation, marker centering, circle clipping and SAM marker registration. The existing rendered integration suite passed 287/287; acceptance (12/12), roster/district (5/5) and boundary (5/5) suites passed.

```powershell
python tools/run_godot_check.py tests/verify_survival_hud.gd
```

The actual renderer screenshot is saved to `artifacts/survival_hud.png`. Source backup: `.codex-backups/before-hud-minimap.zip`.
