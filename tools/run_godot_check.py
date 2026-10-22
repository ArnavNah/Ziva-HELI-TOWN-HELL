import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
script = sys.argv[1] if len(sys.argv) > 1 else "tests/verify_polish.gd"
command = ["C:/Program Files/Godot/Godot.exe", "--path", str(root), "--script", "res://" + script]
if "--headless" in sys.argv:
    command.append("--headless")
else:
    command += ["--resolution", "1280x720", "--position", "40,80"]
extra = [arg for arg in sys.argv[2:] if arg != "--headless"]
if extra:
    command += ["--"] + extra
result = subprocess.run(command, capture_output=True, text=True, timeout=120, creationflags=subprocess.CREATE_NO_WINDOW)
output = result.stdout + result.stderr
(root / "artifacts").mkdir(exist_ok=True)
(root / "artifacts" / (pathlib.Path(script).stem + ".log")).write_text(output, encoding="utf-8")
print(output[-16000:])
raise SystemExit(result.returncode)
