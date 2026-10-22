@tool
extends SceneTree

const MultiAxleWheelController = preload("res://src/enemies/ground/multi_axle_wheel_controller.gd")
const RaptorCannonTurret = preload("res://src/enemies/ground/raptor_cannon_turret.gd")
const DesertBarrageLauncher = preload("res://src/enemies/ground/desert_barrage_launcher.gd")

func _init() -> void:
	print("--- VERIFYING GROUND RIG SCENES ---")

	var wheel_mesh = load("res://assets/Enemy/tank_game_ready/universal_wheel_mesh.res")
	assert(wheel_mesh != null)

	for s_info in [
		{"path": "res://scenes/enemies/raptor_raider_visuals.tscn", "name": "Raptor Raider", "wheels": 4, "tubes": 1},
		{"path": "res://scenes/enemies/desert_barrage_rover_visuals.tscn", "name": "Desert Barrage Rover", "wheels": 6, "tubes": 8}
	]:
		var scene = load(s_info["path"]) as PackedScene
		assert(scene != null, "Failed to load " + s_info["path"])
		var rig = scene.instantiate() as Node3D
		assert(rig != null)

		var vis = rig.get_node_or_null("Visuals")
		assert(vis != null, "Visuals missing in " + s_info["name"])
		assert(vis.get_script() == MultiAxleWheelController, "Visuals should be MultiAxleWheelController")

		var turret = rig.get_node_or_null("Turret")
		assert(turret != null, "Turret missing in " + s_info["name"])

		# Count wheels and verify shared mesh identity
		var found_wheels = 0
		var meshes = rig.find_children("*", "MeshInstance3D", true, false)
		for m in meshes:
			if m.name == "WheelModel":
				found_wheels += 1
				assert(m.mesh == wheel_mesh, "Wheel must use EXACT universal_wheel_mesh.res")
		assert(found_wheels == s_info["wheels"], "Expected %d wheels, found %d" % [s_info["wheels"], found_wheels])

		# Check turret methods
		assert(turret.has_method("track_aim"), "Turret must have track_aim")
		assert(turret.has_method("get_muzzle_position"), "Turret must have get_muzzle_position")
		assert(turret.has_method("get_muzzle_transform"), "Turret must have get_muzzle_transform")
		assert(turret.has_method("play_recoil"), "Turret must have play_recoil")

		# Check Desert tube sequencing
		if s_info["name"] == "Desert Barrage Rover":
			var d_turret: DesertBarrageLauncher = turret as DesertBarrageLauncher
			var tube0 = d_turret.get_active_tube()
			assert(tube0 != null, "Desert must have active tube")
			var p0 = d_turret.get_muzzle_position()
			var p0_repeat = d_turret.get_muzzle_position()
			assert(p0 == p0_repeat, "Querying muzzle position must not advance tube!")
			d_turret.play_recoil()
			var p1 = d_turret.get_muzzle_position()
			assert(p0 != p1, "play_recoil must advance to next tube!")

		print("PASS: ", s_info["name"], " verified successfully! Wheels=", found_wheels)
		rig.free()

	print("--- ALL SCENE STRUCTURE CHECKS PASSED ---")
	quit(0)
