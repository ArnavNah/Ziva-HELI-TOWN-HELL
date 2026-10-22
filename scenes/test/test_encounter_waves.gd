extends Node3D

@onready var label: Label = $UI/Label
@onready var spawner: EnemySpawner = $EnemySpawner

func _ready() -> void:
	if has_node("/root/CombatDirector"):
		get_node("/root/CombatDirector").start_wave_director()

func _process(_delta: float) -> void:
	if not label:
		return
	var text = "=== PHASE 4: ENCOUNTER & DIRECTOR TEST ===\n"
	if has_node("/root/CombatDirector"):
		var cd = get_node("/root/CombatDirector")
		text += "WAVE: %d | THEME: %s | TIME: %.1f / %.1fs\n" % [
			cd.current_wave, cd.active_theme, cd.wave_timer, cd.wave_max_duration
		]
		text += "POPULATION: %d / %d | AIR SLOTS: %d / %d | HEAVY SLOTS: %d / %d\n" % [
			get_tree().get_nodes_in_group("enemies").size(),
			cd.target_population,
			cd.current_air_attackers.size(),
			cd.max_air_slots,
			cd.current_heavy_attackers.size(),
			cd.max_heavy_slots
		]
	label.text = text
