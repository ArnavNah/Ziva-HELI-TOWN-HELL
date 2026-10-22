extends SceneTree

func _init() -> void:
	var game_scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game_scene)
	var capturer = FlightCapturer.new()
	root.add_child(capturer)

class FlightCapturer extends Node:
	var frame: int = 0
	var heli: PlayerHelicopter

	func _process(delta: float) -> void:
		frame += 1
		if frame == 5:
			heli = get_tree().get_first_node_in_group("player") as PlayerHelicopter
		if heli and frame >= 5 and frame < 45:
			# Simulate active forward flight with rotor thrust and motion blur
			heli.velocity.z = -24.0
			heli.last_thrust_input = 1.0
			heli.pitch_angle = deg_to_rad(-14.0)
			heli.bank_angle = deg_to_rad(12.0)
		elif frame == 50:
			var img = get_viewport().get_texture().get_image()
			if img:
				var path = "C:/Users/Prime 3/.gemini/antigravity/brain/246bfbd5-df79-41ad-b1db-2ff3804610f7/helicopter_flight_physics_rotor.png"
				img.save_png(path)
				print("Saved screenshot to ", path)
			get_tree().quit(0)
