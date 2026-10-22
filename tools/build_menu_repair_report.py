"""Build the offline review report from actual menu verification artifacts."""
from pathlib import Path
import base64
import difflib
import html
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/menu-repair-tests'
DOCS = ROOT / 'docs'

SUITES = [
    ('Complete flow, headless', '182 passed; five full loops', 'headless.log'),
    ('Complete flow, rendered', '183 passed; five full loops', 'rendered.log'),
    ('Rendered navigation and sizes', '37 passed', 'test_menu_navigation_edges-rendered.log'),
    ('Gameplay effects and failed saves', '19 passed', 'test_menu_effects.log'),
    ('Loading and error recovery', '7 passed', 'test_loading_animation_transition.log'),
    ('Stale cards, records, confirmations and defaults', '13 passed', 'test_menu_guards.log'),
    ('Fresh-process persistence', 'Passed', 'verify_menu_persistence.log'),
    ('Score/leaderboard regression', '24 passed', 'test_score_and_high_score_system.log'),
    ('Death/results regression', '12 passed', 'test_death_animation_and_flow.log'),
    ('Aircraft selection regression', '16 passed', 'verify_vehicle_selection.log'),
    ('Confirmed application exit', 'Passed in a rendered process', 'test_menu_exit-rendered.log'),
    ('Script compilation', 'Zero parse failures', 'parse.log'),
]

CONTROLS = [
    ('Main menu', 'Select Airframe', 'Open selection and retain aircraft', 'GUI events and return-context checks'),
    ('Main menu', 'Hangar & Armory', 'Refresh wallet/equipment; return to main menu', 'Route and GUI checks'),
    ('Main menu', 'Pilot Settings', 'Open preferences; Done restores focus', 'GUI and persistence checks'),
    ('Main menu', 'Flight Manual / OK / close', 'Scrollable help from actual bindings', 'GUI and rendered capture'),
    ('Main menu', 'Exit / Confirm / Cancel', 'Confirm quits; Cancel restores focus', 'GUI cancellation and actual child-process exit'),
    ('Aircraft selection', 'Previous / Next / 3 cards', 'Select exactly one aircraft and update stats', 'All aircraft verified; arrows and representative card GUI-tested'),
    ('Aircraft selection', 'Back', 'Return to main menu', 'GUI and controller A confirm routing'),
    ('Aircraft selection', 'Upgrade Hangar', 'Return to the same selected aircraft', 'GUI return-context checks'),
    ('Aircraft selection', 'Launch Sortie', 'One protected loading transition', 'GUI, duplicate-request and input-release checks'),
    ('Hangar', 'Systems / Perks / Mods / Dossier tabs', 'Display and refresh the matching section', 'All four tabs GUI-tested'),
    ('Hangar', 'Return / Back', 'Respect main-menu or aircraft-selection caller', 'GUI return-context checks'),
    ('Settings', 'Preferences / Flight Controls', 'Switch scrollable sections', 'GUI and rendered checks'),
    ('Settings', 'Window mode / Keep / Revert', 'Preview, retain or automatically undo display change', 'Rendered Keep and timeout checks'),
    ('Settings', 'FPS / VSync', 'Synchronize engine and saved settings', 'Runtime owner and disk-reload checks'),
    ('Settings', 'Master / Effects / Music', 'Change real audio category levels and save', 'Runtime mute and disk-reload checks'),
    ('Settings', 'Shake / Reduced flashes / Telemetry', 'Apply actual camera/effects/HUD preferences', 'Runtime consumers and explosion-light assertion'),
    ('Settings', 'Restore defaults / Confirm / Cancel', 'Reset preferences only', 'GUI confirmation; progression preservation checked'),
    ('Settings', 'Done / Back', 'Save and restore caller; remain paused when appropriate', 'GUI and pause-state checks'),
    ('Pause', 'Resume', 'Restore the active run', 'State and input-release checks'),
    ('Pause', 'Restart / Confirm / Cancel', 'Load one fresh same-aircraft run', 'GUI confirmation and fresh run-ID checks'),
    ('Pause', 'Settings', 'Back returns to paused run', 'GUI and state checks'),
    ('Pause', 'Main Menu / Confirm / Cancel', 'Protect run progress; Cancel stays paused', 'GUI confirmation/cancellation and shared destination checks'),
    ('Pause', 'Quit / Confirm / Cancel', 'Protect run progress and restore focus on Cancel', 'GUI guards; shared confirmed-quit action'),
    ('Pause developer section', 'Expand / Outlines / Toon / Screen blocks', 'Editor-only experiments with accurate setting labels', 'Handlers/backend inspected; full shader visual acceptance is outside this repair'),
    ('Upgrade', 'Up to 3 offer buttons', 'Hide missing cards; reject stale/invalid/repeated offers', '1/2/3-card, stale-card and queued-offer checks'),
    ('Boss choice', 'Extract', 'Settle victory once and show results', 'GUI and settlement checks'),
    ('Boss choice', 'Continue', 'Activate Overdrive once and resume pending choices', 'State and queue checks'),
    ('Results', 'Retry', 'Use shared loader for a new run', 'GUI and transition checks'),
    ('Results', 'Return to Hangar', 'Open actual Hangar', 'GUI destination checks'),
    ('Results', 'Main Menu', 'Open main menu without another overlay', 'GUI destination check'),
    ('Results', 'Copy Scorecard', 'Copy actual report and give verified feedback', 'Rendered clipboard assertion'),
    ('Loading failure', 'Retry / Back', 'Clean retry or safe return; discard obsolete loader', 'Missing-resource and unready-scene recovery checks'),
]
SYSTEMS = {
    'Engine': 'Cruise speed and thrust acceleration', 'Rotor': 'Yaw and collective lift',
    'Armor': 'Maximum hull', 'Airframe': 'Damage mitigation', 'Fuel': 'Fuel capacity',
    'Targeting': 'Turret tracking and salvo painting', 'Weapon system': 'Weapon, salvo and Super damage',
    'Countermeasures': 'Flare capacity and cooldown',
}
PERKS = {
    'Magnet radius': 'Pickup attraction radius', 'Vector thrusters': 'Dash speed and cooldown',
    'Scavenger rig': 'Coin/salvage reward amounts', 'Rotor armor': 'Impact/scrape resistance',
    'Combat computer': 'Salvo search radius and missile speed', 'Lean burn': 'Fuel consumption',
    'Devastator core': 'Super charge gain', 'EMP rounds': 'Machine-gun EMP chance',
}
MODS = ['Incendiary', 'Armor piercing', 'Missile EMP', 'Cluster bomblets', 'Napalm', 'Shaped charge', 'Shock', 'Slug']
for name, effect in SYSTEMS.items():
    CONTROLS.append(('Hangar system', name + ' purchase', 'Validate price/rank, save and apply: ' + effect,
                     'Transaction and consumer checked; engine purchase also GUI-tested'))
for name, effect in PERKS.items():
    CONTROLS.append(('Hangar perk', name + ' purchase', 'Validate price/rank, save and apply: ' + effect,
                     'Transaction and consumer checked; magnet purchase also GUI-tested'))
for name in MODS:
    CONTROLS.append(('Hangar weapon mods', name + ' equip', 'Save a valid weapon/mod pair and apply its effect',
                     'Every mod ID and effect checked; representative Equip GUI-tested'))
CONTROLS.append(('Hangar weapon mods', '4 standard choices', 'Unequip special mod for the matching weapon', 'All four standard IDs checked'))


def changed_files():
    with zipfile.ZipFile(ROOT / '.codex-backups/menu-repair-20261019.zip') as archive:
        originals = {name: archive.read(name) for name in archive.namelist()}
    # Other project work can change concurrently. Report only files touched by this repair.
    touched = """
    autoload/audio_manager.gd autoload/combat_director.gd autoload/game_manager.gd
    autoload/input_manager.gd autoload/profile_manager.gd autoload/settings_store.gd autoload/ui_flow.gd
    data/aircraft_specs.gd project.godot scenes/main_game.gd
    src/combat/damage_data.gd src/combat/damage_receiver.gd src/combat/lingering_fire.gd src/combat/projectile.gd
    src/effects/fx_manager.gd src/loot/pickup.gd
    src/player/devastation_super.gd src/player/player_camera.gd src/player/player_countermeasures.gd
    src/player/player_helicopter.gd src/player/player_salvo.gd src/player/player_weapons.gd src/player/run_progression.gd
    src/ui/boss_decision_dialog.gd src/ui/upgrade_dialog.gd
    src/ui/menus/debrief_screen.gd src/ui/menus/game_storage.gd src/ui/menus/hangar_menu.gd
    src/ui/menus/loading_screen.gd src/ui/menus/main_menu.gd src/ui/menus/menu_theme.gd
    src/ui/menus/pause_menu.gd src/ui/menus/settings_menu.gd src/ui/menus/vehicle_selection_menu.gd
    src/world/city_generator.gd src/world/field_dressing.gd
    tests/fixtures/menu_unready.tscn tests/parse_menu_repair.gd tests/render_menu_verification.gd
    tests/test_death_animation_and_flow.gd tests/test_loading_animation_transition.gd
    tests/test_menu_effects.gd tests/test_menu_exit.gd tests/test_menu_guards.gd tests/test_menu_navigation_edges.gd
    tests/test_menu_repair.gd tests/test_score_and_high_score_system.gd tests/verify_menu_persistence.gd
    tools/build_menu_repair_report.py tools/run_menu_checks.py
    """
    files = [ROOT / name for name in touched.split()]
    changed, patch = [], []
    for path in sorted(set(files)):
        name = path.relative_to(ROOT).as_posix()
        before, after = originals.get(name, b''), path.read_bytes()
        if before == after:
            continue
        changed.append(name)
        patch.extend(difflib.unified_diff(before.decode('utf-8-sig').splitlines(True), after.decode('utf-8-sig').splitlines(True),
                                        fromfile='before/' + name if before else '/dev/null', tofile='after/' + name))
    (OUT / 'changes.patch').write_text(''.join(patch), encoding='utf-8')
    (OUT / 'changed-files.json').write_text(json.dumps(changed, indent=2), encoding='utf-8')
    return changed


def table(headers, rows):
    return '<div class="scroll"><table><thead><tr>' + ''.join('<th>' + html.escape(x) + '</th>' for x in headers) + '</tr></thead><tbody>' + ''.join('<tr>' + ''.join('<td>' + html.escape(x) + '</td>' for x in row) + '</tr>' for row in rows) + '</tbody></table></div>'


def main():
    for _, _, logfile in SUITES:
        text = (OUT / logfile).read_text(encoding='utf-8')
        assert 'SCRIPT ERROR:' not in text and '\nERROR:' not in text and '\nFAIL ' not in text, logfile
    head = json.loads((OUT / 'results-headless.json').read_text(encoding='utf-8'))
    rendered = json.loads((OUT / 'results-rendered.json').read_text(encoding='utf-8'))
    assert not head['failures'] and not rendered['failures']
    files = changed_files()
    loads = [row['load_ms'] / 1000 for row in rendered['transitions']]
    peaks = [row['animation']['max_frame_ms'] for row in rendered['transitions']]
    measurements = (f'First scene load in the rendered process: {loads[0]:.2f}s. Later loads: {min(loads[1:]):.2f}–{max(loads[1:]):.2f}s. '
                    f'World preparation advanced through {rendered["transitions"][0]["animation"]["world_frames"]} animation frames per load. '
                    f'The slowest individual frames per load ranged from {min(peaks):.0f} to {max(peaks):.0f}ms.')
    limits = ('Brief main-thread/graphics initialization stalls remain. These timings used existing import/shader caches and overlapping verification work; '
              'they are not a clean-cache benchmark or gameplay FPS claim. Physical controller hardware was not tested; controller events were injected through Godot’s actual GUI routing. '
              'Godot still reports RefCounted cleanup warnings at the end of some test processes. The warning remains unresolved. Final listed runs have no script/resource errors.')
    changes = [
        'Deploy, Retry and Restart share one guarded loader with resource, world-preparation, readiness and reveal phases. Loading errors offer Retry/Back.',
        'Roads, blocks and vegetation prepare in frame batches. Gameplay starts after reveal, and held launch input must be released before gameplay input arms.',
        'Pause respects upgrade, boss, loading and results states. Settings Back returns to pause. Confirmations protect Restart, return-to-menu and Quit.',
        'Selection is remembered. Hangar remembers its caller. Return to Hangar opens the actual Hangar. Stats and controls help use current runtime data.',
        'Audio, FPS, VSync, camera shake, reduced flashes and telemetry preferences save automatically. Display changes support timed Keep/Revert.',
        'All systems, perks and weapon mods have runtime effects. Failed purchase saves roll back credits/rank. Corrupt profile JSON is preserved; bonuses apply once to fresh aircraft.',
        'Run IDs prevent duplicate payouts/history. Ties are not new records. Leaderboards rerank every entry. Scorecards scroll and copy actual text.',
        'Missing/stale upgrade cards cannot dismiss a choice. Queued choices precede a pending boss decision. Deferred offers check scene lifetime.',
    ]
    md = '# Menu repair implementation report\n\nImplemented 19 October 2026.\n\n'
    md += '\n'.join('- ' + x for x in changes)
    md += '\n\n## Verification\n\nTests used isolated profiles below `artifacts/menu-repair-tests/`. Credits in screenshots are test data. The real profile was not used as a fixture.\n\n| Suite | Result | Evidence |\n|---|---|---|\n'
    for title, result, logfile in SUITES:
        md += f'| {title} | {result} | [log](../artifacts/menu-repair-tests/{logfile}) |\n'
    md += '\n## Per-control checklist\n\nShared builders connect each data-driven row to the same validated handler. Evidence distinguishes GUI events, backend checks and source inspection.\n\n| Screen | Controls | Behavior | Verification |\n|---|---|---|---|\n'
    md += '\n'.join('| ' + ' | '.join(row) + ' |' for row in CONTROLS)
    md += '\n\n## Measurements and remaining limits\n\n' + measurements + '\n\n' + limits
    md += '\n\nVisual checks covered 1280x720, 960x540, 1920x1080 and 2560x1080. Minimum window size is 960x540. Both full-flow suites repeated the complete menu/run/results journey five times.\n'
    md += '\n## Files and reproduction\n\n[Architecture, permanent effects and commands](../MENU_FLOW_NOTES.md). [Changed-file list](../artifacts/menu-repair-tests/changed-files.json). [Review patch](../artifacts/menu-repair-tests/changes.patch). Original source backup: `.codex-backups/menu-repair-20261019.zip`.\n\n'
    md += '\n'.join('- `' + name + '`' for name in files) + '\n'
    (DOCS / 'MENU_REPAIR_RESULTS.md').write_text(md, encoding='utf-8')
    screenshots = [('01-main-menu.png', 'Main menu'), ('05-aircraft.png', 'Aircraft selection'), ('06-loading.png', 'Animated deployment'),
                   ('02-settings.png', 'Saved preferences'), ('03b-flight-manual.png', 'Flight manual'), ('04-hangar-0.png', 'Hangar systems'),
                   ('07-pause.png', 'Pause'), ('10-results.png', 'Results')]
    gallery = ''
    for name, title in screenshots:
        data = base64.b64encode((OUT / name).read_bytes()).decode()
        gallery += f'<figure><img loading="lazy" src="data:image/png;base64,{data}" alt="{title}"><figcaption>{title}</figcaption></figure>'
    css = ':root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#10181c;color:#e8efea;font:17px/1.65 system-ui,sans-serif}main{max-width:1200px;margin:auto;padding:40px 24px 80px}h1{font-size:clamp(32px,5vw,52px);line-height:1.15}h2{margin-top:36px}.tag{color:#ffd275;letter-spacing:.1em;font-size:13px}p{max-width:950px}a{color:#8de5d4}.flow,.note{padding:22px;background:#1b3337;border-radius:10px}.flow{font-size:21px}.note{border-left:4px solid #ffd275}figure{margin:22px 0;padding:12px;background:#1a292f;border-radius:10px}img{display:block;width:100%;height:auto}figcaption{padding:10px 4px;font-weight:600}.scroll{overflow:auto}table{border-collapse:collapse;width:100%;font-size:15px}td,th{text-align:left;padding:12px;border-bottom:1px solid #3d535a;vertical-align:top}th{color:#ffd275}details summary{cursor:pointer;font-size:22px;font-weight:600;padding:20px 0}footer{margin-top:32px;color:#adc1c0}'
    page = f'<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Menus implemented — repair report</title><style>{css}</style></head><body><main><div class="tag">IMPLEMENTED · 19 OCTOBER 2026</div><h1>The menus now follow one clear flow.</h1><div class="flow">Main menu → Choose aircraft → Loading → Play → Results<br>Results → Retry · Hangar · Main menu</div><h2>What changed</h2><ul>'
    page += ''.join('<li>' + html.escape(change) + '</li>' for change in changes) + '</ul><h2>Verification</h2><p>Tests used isolated profiles. The complete journey passed five times in both logic and rendered suites.</p>'
    page += table(['Suite', 'Result'], [(title, result) for title, result, _ in SUITES])
    page += '<h2>Remaining limits</h2><div class="note"><p>' + html.escape(limits) + '</p></div><p>' + html.escape(measurements) + '</p>'
    page += '<p><a href="MENU_REPAIR_RESULTS.md">Full report, logs, files and reproduction commands</a></p><details><summary>Per-control implementation and verification</summary>'
    page += table(['Screen', 'Controls', 'Behavior', 'Verification'], CONTROLS) + '</details><h2>Screenshots</h2><p>Credits and records shown belong to isolated test profiles.</p>'
    page += gallery + '<footer>Maintenance notes: <a href="../MENU_FLOW_NOTES.md">MENU_FLOW_NOTES.md</a>. Original source snapshot: .codex-backups/menu-repair-20261019.zip.</footer></main></body></html>'
    (DOCS / 'menu-repair-results.html').write_text(page, encoding='utf-8')
    old_page = DOCS / 'menu-flow-fix.html'
    old_text = old_page.read_text(encoding='utf-8-sig').replace('The code review is complete; the game has not been changed by this document.',
        'Implementation completed on 19 October 2026. <a href="menu-repair-results.html">Open the implementation report and screenshots.</a> The original prompt is retained below as a checklist.')
    old_page.write_text(old_text, encoding='utf-8')
    print(f'Created offline report, {len(CONTROLS)} checklist rows, screenshots and patch for {len(files)} changed files.')


if __name__ == '__main__':
    main()
