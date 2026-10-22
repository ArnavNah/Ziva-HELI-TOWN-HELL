import subprocess
import sys
from ziva_mcp import ROOT, call

if sys.argv[1] == "ziva":
    call("execute_script", {"reasoning": "Verify expanded world behavior through Ziva's headless Godot runner.",
        "code": (ROOT / sys.argv[2]).read_text(encoding="utf-8"), "timeout": 60})
else:
    args = [r"C:\Users\Prime 3\Desktop\Godot.exe", "--path", str(ROOT), "--script", sys.argv[2]]
    args.extend(sys.argv[3:])
    if sys.argv[1] == "headless":
        args.append("--headless")
    log = ROOT / "artifacts" / ("strike-" + __import__('pathlib').Path(sys.argv[2]).stem + ".log")
    with log.open("w", encoding="utf-8") as stream:
        process = subprocess.Popen(args, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
        try:
            code = process.wait(timeout=90)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            code = 1
            stream.write("\nERROR: Verification exceeded 90 seconds.\n")
    out = log.read_text(encoding="utf-8", errors="replace")
    if "SCRIPT ERROR:" in out or "ERROR:" in out:
        code = 1
    print(out[-12000:])
    print("Exit code:", code)
    sys.exit(code)
