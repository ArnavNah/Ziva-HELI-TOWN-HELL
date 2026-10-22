"""Run menu acceptance checks without touching the player's profile/settings."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--rendered', action='store_true')
parser.add_argument('--parse', action='store_true')
parser.add_argument('--script')
parser.add_argument('--profile-source')
args = parser.parse_args()
out = ROOT / 'artifacts' / 'menu-repair-tests'
out.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()

script = args.script or ('tests/parse_menu_repair.gd' if args.parse else 'tests/test_menu_repair.gd')
env['ZIVA_TEST_DATA_DIR'] = str(out / ('profile-' + ('rendered-' if args.rendered else 'headless-') + Path(script).stem))
if args.profile_source:
    if Path(args.profile_source).name != args.profile_source or not args.profile_source.startswith('profile-'):
        parser.error('profile-source must name an isolated profile directory under artifacts/menu-repair-tests')
    env['ZIVA_TEST_DATA_DIR'] = str(out / args.profile_source)
command = [r'C:\Users\Prime 3\Desktop\Godot.exe', '--path', str(ROOT), '--script', script]
if not args.rendered:
    command.append('--headless')
else:
    command.extend(['--resolution', '1280x720', '--position', '-32000,-32000'])
label = 'parse' if args.parse else ('rendered' if args.rendered else 'headless')
if args.script:
    label = Path(args.script).stem + ('-rendered' if args.rendered else '')
log = out / (label + '.log')
startup = subprocess.STARTUPINFO() if os.name == 'nt' else None
if startup:
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
with log.open('w', encoding='utf-8') as stream:
    process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT,
                               startupinfo=startup, creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
    deadline = time.monotonic() + 180
    while process.poll() is None:
        if 'SCRIPT ERROR:' in log.read_text(encoding='utf-8', errors='replace'):
            process.kill()
            process.wait()
            break
        if time.monotonic() > deadline:
            process.kill()
            process.wait()
            stream.write('\nERROR: Menu acceptance exceeded 180 seconds.\n')
            break
        time.sleep(0.1)
    code = process.returncode
text = log.read_text(encoding='utf-8', errors='replace')
print(text[-14000:])
if 'SCRIPT ERROR:' in text or 'ERROR:' in text or '\nFAIL ' in text:
    code = 1
print('Log:', log)
sys.exit(code)
