@tool
extends SceneTree

func _init() -> void:
	print("--- BUILDING FINAL GROUND RIG SCENES ---")

	var wheel_mesh = load("res://assets/Enemy/tank_game_ready/universal_wheel_mesh.res") as ArrayMesh
	assert(wheel_mesh != null, "Missing shared universal_wheel_mesh.res")

	# ========================================================
	# 1. RAPTOR RAIDER RIG
	# ========================================================
	var raptor_chassis_mesh = load("res://assets/Enemy/new ground/Raptor_Raider/raptor_chassis_mesh.res") as ArrayMesh
	var raptor_base_mesh = load("res://assets/Enemy/new ground/Raptor_Raider/raptor_turret_base_mesh.res") as ArrayMesh
	var raptor_gun_mesh = load("res://assets/Enemy/new ground/Raptor_Raider/raptor_turret_gun_mesh.res") as ArrayMesh
	var multi_axle_script = load("res://src/enemies/ground/multi_axle_wheel_controller.gd") as Script
	var raptor_turret_script = load("res://src/enemies/ground/raptor_cannon_turret.gd") as Script

	var raptor_rig = Node3D.new()
	raptor_rig.name = "RaptorRaiderRig"

	# Visuals
	var r_vis = Node3D.new()
	r_vis.name = "Visuals"
	r_vis.set_script(multi_axle_script)
	raptor_rig.add_child(r_vis)

	# HullModel
	var r_hull = Node3D.new()
	r_hull.name = "HullModel"
	r_vis.add_child(r_hull)

	var r_chassis_inst = MeshInstance3D.new()
	r_chassis_inst.name = "Raptor_Chassis"
	r_chassis_inst.mesh = raptor_chassis_mesh
	# Rotation -90 around Y, scale 6.0: Basis(Vector3(0,0,6), Vector3(0,6,0), Vector3(-6,0,0))
	r_chassis_inst.transform = Transform3D(Vector3(0, 0, 6.0), Vector3(0, 6.0, 0), Vector3(-6.0, 0, 0), Vector3(0, 1.02, 0))
	r_hull.add_child(r_chassis_inst)

	# Wheels
	var r_wheels = Node3D.new()
	r_wheels.name = "Wheels"
	r_vis.add_child(r_wheels)

	var create_wheel = func(parent_node: Node3D, is_left: bool, scale_val: float) -> MeshInstance3D:
		var wm = MeshInstance3D.new()
		wm.name = "WheelModel"
		wm.mesh = wheel_mesh
		if is_left:
			# Left wheel (+Z facing outward along -X):
			wm.transform = Transform3D(Vector3(0, 0, -scale_val), Vector3(0, scale_val, 0), Vector3(scale_val, 0, 0), Vector3.ZERO)
		else:
			# Right wheel (+Z facing outward along +X):
			wm.transform = Transform3D(Vector3(0, 0, scale_val), Vector3(0, scale_val, 0), Vector3(-scale_val, 0, 0), Vector3.ZERO)
		parent_node.add_child(wm)
		return wm

	# Front Left Steer + Spin
	var r_fl_steer = Node3D.new()
	r_fl_steer.name = "FrontLeftSteer"
	r_fl_steer.position = Vector3(-1.71, 0.74, -1.57)
	r_wheels.add_child(r_fl_steer)
	var r_fl_spin = Node3D.new()
	r_fl_spin.name = "FrontLeftSpin"
	r_fl_steer.add_child(r_fl_spin)
	create_wheel.call(r_fl_spin, true, 1.35)

	# Front Right Steer + Spin
	var r_fr_steer = Node3D.new()
	r_fr_steer.name = "FrontRightSteer"
	r_fr_steer.position = Vector3(1.71, 0.74, -1.57)
	r_wheels.add_child(r_fr_steer)
	var r_fr_spin = Node3D.new()
	r_fr_spin.name = "FrontRightSpin"
	r_fr_steer.add_child(r_fr_spin)
	create_wheel.call(r_fr_spin, false, 1.35)

	# Rear Left Spin
	var r_rl_spin = Node3D.new()
	r_rl_spin.name = "RearLeftSpin"
	r_rl_spin.position = Vector3(-1.64, 0.76, 1.68)
	r_wheels.add_child(r_rl_spin)
	create_wheel.call(r_rl_spin, true, 1.35)

	# Rear Right Spin
	var r_rr_spin = Node3D.new()
	r_rr_spin.name = "RearRightSpin"
	r_rr_spin.position = Vector3(1.64, 0.76, 1.68)
	r_wheels.add_child(r_rr_spin)
	create_wheel.call(r_rr_spin, false, 1.35)

	# Turret
	var r_turret = Node3D.new()
	r_turret.name = "Turret"
	r_turret.set_script(raptor_turret_script)
	r_turret.position = Vector3(0, 1.33, 1.29)
	raptor_rig.add_child(r_turret)

	var r_mount = Node3D.new()
	r_mount.name = "MountModel"
	r_turret.add_child(r_mount)

	var r_base_inst = MeshInstance3D.new()
	r_base_inst.name = "Raptor_Turret_Base"
	r_base_inst.mesh = raptor_base_mesh
	r_base_inst.transform = Transform3D(Vector3(0, 0, 6.0), Vector3(0, 6.0, 0), Vector3(-6.0, 0, 0), Vector3.ZERO)
	r_mount.add_child(r_base_inst)

	var r_pitch = Node3D.new()
	r_pitch.name = "GunPitch"
	r_pitch.position = Vector3(0, 0.91, 0.126)
	r_turret.add_child(r_pitch)

	var r_recoil = Node3D.new()
	r_recoil.name = "Recoil"
	r_pitch.add_child(r_recoil)

	var r_gun_inst = MeshInstance3D.new()
	r_gun_inst.name = "GunModel"
	r_gun_inst.mesh = raptor_gun_mesh
	r_gun_inst.transform = Transform3D(Vector3(0, 0, 6.0), Vector3(0, 6.0, 0), Vector3(-6.0, 0, 0), Vector3(0, -0.91, -0.126))
	r_recoil.add_child(r_gun_inst)

	var r_muzzle = Marker3D.new()
	r_muzzle.name = "Muzzle"
	r_muzzle.position = Vector3(0, 0.05, -1.38)
	r_recoil.add_child(r_muzzle)

	_set_owner_recursive(raptor_rig, raptor_rig)
	var raptor_packed = PackedScene.new()
	raptor_packed.pack(raptor_rig)
	ResourceSaver.save(raptor_packed, "res://scenes/enemies/raptor_raider_visuals.tscn")
	print("Saved scenes/enemies/raptor_raider_visuals.tscn")
	raptor_rig.free()

	# ========================================================
	# 2. DESERT BARRAGE ROVER RIG
	# ========================================================
	var desert_chassis_mesh = load("res://assets/Enemy/new ground/Desert_Barrage_Rover/desert_chassis_mesh.res") as ArrayMesh
	var desert_base_mesh = load("res://assets/Enemy/new ground/Desert_Barrage_Rover/desert_launcher_base_mesh.res") as ArrayMesh
	var desert_pods_mesh = load("res://assets/Enemy/new ground/Desert_Barrage_Rover/desert_launcher_pods_mesh.res") as ArrayMesh
	var desert_launcher_script = load("res://src/enemies/ground/desert_barrage_launcher.gd") as Script

	var desert_rig = Node3D.new()
	desert_rig.name = "DesertBarrageRoverRig"

	# Visuals
	var d_vis = Node3D.new()
	d_vis.name = "Visuals"
	d_vis.set_script(multi_axle_script)
	desert_rig.add_child(d_vis)

	# HullModel
	var d_hull = Node3D.new()
	d_hull.name = "HullModel"
	d_vis.add_child(d_hull)

	var d_chassis_inst = MeshInstance3D.new()
	d_chassis_inst.name = "Desert_Chassis"
	d_chassis_inst.mesh = desert_chassis_mesh
	d_chassis_inst.transform = Transform3D(Vector3(0, 0, 6.2), Vector3(0, 6.2, 0), Vector3(-6.2, 0, 0), Vector3(0, 1.18, 0))
	d_hull.add_child(d_chassis_inst)

	# Wheels (6 wheels, 3 axles)
	var d_wheels = Node3D.new()
	d_wheels.name = "Wheels"
	d_vis.add_child(d_wheels)

	# Front Axle
	var d_fl_steer = Node3D.new()
	d_fl_steer.name = "FrontLeftSteer"
	d_fl_steer.position = Vector3(-1.31, 0.70, -1.75)
	d_wheels.add_child(d_fl_steer)
	var d_fl_spin = Node3D.new()
	d_fl_spin.name = "FrontLeftSpin"
	d_fl_steer.add_child(d_fl_spin)
	create_wheel.call(d_fl_spin, true, 1.25)

	var d_fr_steer = Node3D.new()
	d_fr_steer.name = "FrontRightSteer"
	d_fr_steer.position = Vector3(1.29, 0.70, -1.75)
	d_wheels.add_child(d_fr_steer)
	var d_fr_spin = Node3D.new()
	d_fr_spin.name = "FrontRightSpin"
	d_fr_steer.add_child(d_fr_spin)
	create_wheel.call(d_fr_spin, false, 1.25)

	# Middle Axle
	var d_ml_spin = Node3D.new()
	d_ml_spin.name = "MidLeftSpin"
	d_ml_spin.position = Vector3(-1.31, 0.68, 0.78)
	d_wheels.add_child(d_ml_spin)
	create_wheel.call(d_ml_spin, true, 1.25)

	var d_mr_spin = Node3D.new()
	d_mr_spin.name = "MidRightSpin"
	d_mr_spin.position = Vector3(1.31, 0.68, 0.78)
	d_wheels.add_child(d_mr_spin)
	create_wheel.call(d_mr_spin, false, 1.25)

	# Rear Axle
	var d_rl_spin = Node3D.new()
	d_rl_spin.name = "RearLeftSpin"
	d_rl_spin.position = Vector3(-1.29, 0.64, 2.35)
	d_wheels.add_child(d_rl_spin)
	create_wheel.call(d_rl_spin, true, 1.25)

	var d_rr_spin = Node3D.new()
	d_rr_spin.name = "RearRightSpin"
	d_rr_spin.position = Vector3(1.29, 0.64, 2.35)
	d_wheels.add_child(d_rr_spin)
	create_wheel.call(d_rr_spin, false, 1.25)

	# Turret / Launcher
	var d_turret = Node3D.new()
	d_turret.name = "Turret"
	d_turret.set_script(desert_launcher_script)
	d_turret.position = Vector3(0, 1.39, 1.98)
	desert_rig.add_child(d_turret)

	var d_mount = Node3D.new()
	d_mount.name = "MountModel"
	d_turret.add_child(d_mount)

	var d_base_inst = MeshInstance3D.new()
	d_base_inst.name = "Desert_Launcher_Base"
	d_base_inst.mesh = desert_base_mesh
	d_base_inst.transform = Transform3D(Vector3(0, 0, 6.2), Vector3(0, 6.2, 0), Vector3(-6.2, 0, 0), Vector3.ZERO)
	d_mount.add_child(d_base_inst)

	var d_pitch = Node3D.new()
	d_pitch.name = "LauncherPitch"
	d_pitch.position = Vector3(0, 0.43, 0.0)
	d_turret.add_child(d_pitch)

	var d_pod_inst = MeshInstance3D.new()
	d_pod_inst.name = "PodModel"
	d_pod_inst.mesh = desert_pods_mesh
	d_pod_inst.transform = Transform3D(Vector3(0, 0, 6.2), Vector3(0, 6.2, 0), Vector3(-6.2, 0, 0), Vector3(0, -0.43, 0))
	d_pitch.add_child(d_pod_inst)

	# 8 Alternating Launch Tubes
	var d_tubes = Node3D.new()
	d_tubes.name = "Tubes"
	d_pitch.add_child(d_tubes)

	var add_tube = func(t_name: String, pos: Vector3):
		var m = Marker3D.new()
		m.name = t_name
		m.position = pos
		d_tubes.add_child(m)

	# Alternating Left/Right order
	add_tube.call("Tube_01_Left_Top_Outer", Vector3(-0.88, 0.36, -0.84))
	add_tube.call("Tube_02_Right_Top_Outer", Vector3(0.88, 0.36, -0.84))
	add_tube.call("Tube_03_Left_Top_Inner", Vector3(-0.56, 0.36, -0.84))
	add_tube.call("Tube_04_Right_Top_Inner", Vector3(0.55, 0.36, -0.84))
	add_tube.call("Tube_05_Left_Bottom_Outer", Vector3(-1.08, 0.29, -0.87))
	add_tube.call("Tube_06_Right_Bottom_Outer", Vector3(1.08, 0.29, -0.87))
	add_tube.call("Tube_07_Left_Bottom_Inner", Vector3(-0.35, 0.29, -0.87))
	add_tube.call("Tube_08_Right_Bottom_Inner", Vector3(0.35, 0.29, -0.87))

	_set_owner_recursive(desert_rig, desert_rig)
	var desert_packed = PackedScene.new()
	desert_packed.pack(desert_rig)
	ResourceSaver.save(desert_packed, "res://scenes/enemies/desert_barrage_rover_visuals.tscn")
	print("Saved scenes/enemies/desert_barrage_rover_visuals.tscn")
	desert_rig.free()

	print("--- SCENES BUILD COMPLETE ---")
	quit(0)

func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		_set_owner_recursive(child, scene_root)
