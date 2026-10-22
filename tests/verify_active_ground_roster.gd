extends SceneTree

const Specs = preload("res://src/enemies/enemy_data.gd")
const Spawner = preload("res://src/enemies/enemy_spawner.gd")
const KEPT = [
	"scout_buggy", "assault_apc", "rail_crawler", "siege_tank", "gatling_heavy",
	"raptor_raider", "desert_barrage_rover"
]
const DISABLED = ["rocket_buggy", "flame_tank", "mortar_crawler", "sam_launcher",
	"technical_truck", "flak_tank", "missile_carrier", "infantry_squad"]
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func run() -> void:
	root.get_node("CombatDirector").stop_wave_director()
	var arena := Node3D.new()
	root.add_child(arena)
	var spawner = Spawner.new()
	arena.add_child(spawner)
	spawner.set_process(false)
	spawner.encounter_rng.seed = 1947
	var enabled_ground: Array[String] = []
	var other_enabled := 0
	for key in Specs.VARIANTS:
		if Specs.is_variant_enabled(key):
			if Specs.VARIANTS[key].family == "ground":
				enabled_ground.append(key)
			else:
				other_enabled += 1
	enabled_ground.sort()
	var expected := KEPT.duplicate()
	expected.sort()
	check(enabled_ground == expected, "Exactly the seven confirmed ground slots are enabled")
	check(other_enabled == 14, "All twelve air and two support variants remain enabled")
	check(not Specs.is_variant_enabled("unknown_vehicle"), "Unknown and future vehicles are not enabled")
	for key in DISABLED:
		check(spawner.spawn_enemy_type(key, Vector3.ZERO) == null,
			"Direct spawning rejects disabled ground type: " + key)

	var selections_ok := true
	var seen: Dictionary = {}
	for wave in range(1, 31):
		for theme in ["Normal", "Swarm Tide", "Armored Column", "Storm Surge", "Night Surge"]:
			for sample in range(64):
				var key: String = spawner._choose_wave_variant(wave, theme)
				if key.is_empty() or not Specs.is_variant_enabled(key):
					selections_ok = false
				elif int(Specs.VARIANTS[key].gate_wave) > wave:
					selections_ok = false
				seen[key] = true
	check(selections_ok, "9600 wave/theme selections respect the roster and unlock gates")
	for key in KEPT:
		check(seen.has(key), "Retained ground role remains selectable: " + key)

	# Fill each retained ground role to its cap through the real spawning API.
	var spawn_ok := true
	var slot := 0
	for key in KEPT:
		for index in range(int(Specs.VARIANTS[key].max_cap)):
			# This isolated visual-roster fixture deliberately ignores live wave/population gates.
			var unit = spawner.spawn_enemy_type(key, Vector3(slot * 20.0, 0, 0), true)
			slot += 1
			if unit == null:
				spawn_ok = false
			else:
				unit.set_process(false)
				unit.set_physics_process(false)
	check(spawn_ok, "All seven retained ground roles instantiate through gameplay spawning")
	var caps_ok := true
	for theme in ["Normal", "Swarm Tide", "Armored Column", "Storm Surge", "Night Surge"]:
		for sample in range(128):
			var key: String = spawner._choose_wave_variant(30, theme)
			if key.is_empty() or key in KEPT or key in DISABLED:
				caps_ok = false
	check(caps_ok, "Full ground caps fall back to air/support without re-enabling removed types")
	arena.free()
	await process_frame
	print("ACTIVE_GROUND_ROSTER_FAILURES=", failures)
	quit(0 if failures == 0 else 1)
