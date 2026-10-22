import subprocess

cmd = ["C:/Users/Prime 3/Desktop/Godot.exe", "--headless", "-s", "tools/inspect_ground_glbs.gd"]
res = subprocess.run(cmd, capture_output=True, text=True)
print("STDOUT:\n", res.stdout)
print("STDERR:\n", res.stderr)
