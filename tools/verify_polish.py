import json
import pathlib
import sys
from ziva_call import call, ROOT

mode = sys.argv[1] if len(sys.argv) > 1 else "compile"
if mode == "compile":
    arguments = {
        "reasoning": "Compile changed game scripts through Ziva before testing their behavior.",
        "code": 'var paths = ["res://src/ui/menus/main_menu.gd", "res://src/ui/menus/aircraft_preview.gd", "res://src/enemies/enemy_spawner.gd", "res://src/world/city_generator.gd"]\nfor path in paths:\n\tprint(path, " valid=", load(path).can_instantiate())',
        "timeout": 45,
    }
    result = call("execute_script", arguments)
elif mode in ("menu", "game", "launch", "settings", "hangar", "aircraft"):
    inputs = []
    if mode == "launch":
        inputs = [{"type": "target", "target": "DEPLOY", "at_ms": 900, "hold_ms": 100}]
    elif mode in ("settings", "hangar"):
        inputs = [{"type": "target", "target": "SETTINGS" if mode == "settings" else "HANGAR", "at_ms": 800, "hold_ms": 100}]
    elif mode == "aircraft":
        inputs = [{"type": "target", "target": "MainMenu/VBoxContainer/AircraftSelect", "at_ms": 800, "hold_ms": 100}, {"type": "key", "key": "Down", "at_ms": 1100, "hold_ms": 100}, {"type": "key", "key": "Enter", "at_ms": 1400, "hold_ms": 100}]
    result = call("run_scene", {
        "reasoning": "Visually verify the updated menu and real gameplay with Ziva's live game capture.",
        "scene_path": "res://scenes/main_game.tscn" if mode == "game" else "res://scenes/ui/main_menu.tscn",
        "duration_ms": 6500 if mode in ("game", "launch") else 2200,
        "inputs": inputs,
    })
    for item in result.get("result", {}).get("content", []):
        if "saved_image" in item:
            source = pathlib.Path(item["saved_image"])
            dest = source.with_name(mode + ".png")
            dest.write_bytes(source.read_bytes())
            item["saved_image"] = str(dest)
else:
    raise SystemExit("Unknown mode")
(ROOT / "artifacts").mkdir(exist_ok=True)
(ROOT / "artifacts" / (mode + ".json")).write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps(result, ensure_ascii=True))
