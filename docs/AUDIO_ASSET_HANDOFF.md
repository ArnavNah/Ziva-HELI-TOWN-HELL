# Recorded audio handoff

The current rotor recording is connected. The user will supply recorded weapon sounds and music; synthesized effects/music remain the fallback until then.

Place PCM WAV files at these exact resource paths, then restart the game. The loader reads WAV files directly, so editor import is not required for this path. Use recordings that you have permission to ship.

| Path under assets/audio/ | Content |
| --- | --- |
| sfx/helicopter_rotor_loop.wav | Existing seamless rotor loop; pitch already follows flight load |
| sfx/mg_fire.wav | Short mechanical cannon report, clean transient, no long tail |
| sfx/rocket_fire.wav | Rocket-pod ignition and hollow launch thump |
| sfx/missile_fire.wav | Guided-missile launch |
| sfx/hit.wav | Short hit confirmation |
| sfx/crit_hit.wav | Distinct critical hit confirmation |
| sfx/explosion.wav | Vehicle destruction |
| sfx/explosion_heavy.wav | Heavy vehicle/boss destruction |
| sfx/lock_beep.wav | Short radar receiver warning; repeats faster near a missile |
| sfx/alarm.wav | Emergency hull warning |
| sfx/flare.wav | Countermeasure deployment |
| music/bgm_calm.wav | Patrol bed: bass pulse, sparse muted percussion |
| music/bgm_combat.wav | Additive combat stem: percussion and distorted arpeggios |
| music/bgm_boss.wav | Additive boss stem: industrial/orchestral accents |

SFX: 16-bit PCM WAV, 44.1 or 48 kHz, mono preferred for short effects. Avoid clipped peaks and long leading silence. Effects play through the existing 16-channel pool and respect SFX/master settings.

Music: all three stems must have identical tempo, sample rate, exact frame length, and musical loop boundaries. Suggested arrangement: 128 BPM, 4/4, 16 bars = 30 seconds. Export all stems from the same timeline start, retaining intentional silence. Loops must be seamless. These are additive stems, not three already-mastered full mixes. Leave mixing headroom.

When all three music files exist, the mixer keeps the patrol bed underneath combat and adds the boss layer during boss pressure. Playback pitch stays fixed to preserve stem alignment. With fewer than three files, available replacements work with the existing exclusive crossfade fallback. No recorded weapon library or finished military score is bundled by this change.

Additional cached effects can also be replaced with their AudioManager cache key as the WAV filename in sfx/ (for example pickup_xp.wav, upgrade_applied.wav, ui_click.wav). Avoid replacing shipped files while the game is running; restart to reload.
