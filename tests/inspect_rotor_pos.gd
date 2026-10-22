extends SceneTree

func _initialize() -> void:
	var player_src = load("res://scenes/player/player.tscn").instantiate()
	var visuals = player_src.get_node("Visuals")
	var apache_inner = visuals.find_child("ApacheModel", true, false)
	var main_rotor = visuals.find_child("Main_Rotor", true, false)
	if main_rotor:
		print("Main Rotor position in player.tscn: ", main_rotor.global_position)
		print("Main Rotor parent: ", main_rotor.get_parent().name)
		print("Main Rotor local position: ", main_rotor.position)
	player_src.free()
	quit(0)
