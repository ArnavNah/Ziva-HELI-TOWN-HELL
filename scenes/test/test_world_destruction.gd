extends Node3D

@onready var label: Label = $UI/Label
@onready var city_gen: Node3D = $CityGenerator
@onready var weather: Node3D = $WeatherSystem

func _ready() -> void:
	if city_gen:
		city_gen.generate_district("Industrial", 42)

func _process(_delta: float) -> void:
	if not label or not city_gen:
		return
	var text = "=== PHASE 5: WORLD & DESTRUCTION TEST ===\n"
	text += "Current District: %s | Blocks: %d\n" % [city_gen.current_district, city_gen.spawned_blocks.size()]
	text += "Press 1: Downtown | Press 2: Industrial | Press 3: Storm | Press 4: Night\n"
	label.text = text

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				city_gen.generate_district("Downtown", 101)
			KEY_2:
				city_gen.generate_district("Industrial", 202)
			KEY_3:
				weather.set_storm_mode(!weather.is_storming)
			KEY_4:
				weather.set_night_mode(!weather.is_night)
