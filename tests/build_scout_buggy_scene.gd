@tool
extends SceneTree

func _init() -> void:
	print("--- ASSEMBLING SCOUT BUGGY VISUALS SCENE ---")
	var root_node = Node3D.new()
	root_node.name = "ScoutBuggyVisualRig"
	
	# 1. Visuals Node
	var visuals = Node3D.new()
	visuals.name = "Visuals"
	visuals.set_script(load("res://src/enemies/ground/scout_buggy_wheel_controller.gd"))
	root_node.add_child(visuals)
	visuals.owner = root_node
	
	# Load Body GLB
	var gltf_b = GLTFDocument.new()
	var state_b = GLTFState.new()
	gltf_b.append_from_file("res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Body.glb", state_b)
	var body_scene = gltf_b.generate_scene(state_b)
	
	var body_model = Node3D.new()
	body_model.name = "BodyModel"
	body_model.position = Vector3(0, 1.18, 0)
	body_model.scale = Vector3(4.0, 4.0, 4.0)
	visuals.add_child(body_model)
	body_model.owner = root_node
	
	# Move children of body_scene under body_model
	for child in body_scene.get_children():
		body_scene.remove_child(child)
		body_model.add_child(child)
		child.owner = root_node
		_set_owners(child, root_node)
	body_scene.free()
	
	# 2. Wheels
	var wheels = Node3D.new()
	wheels.name = "Wheels"
	visuals.add_child(wheels)
	wheels.owner = root_node
	
	var tire_mesh = load("res://assets/Enemy/scout_buggy_Game_Asset/tire_mesh_reduced.res")
	var wheel_radius = 0.50
	var tire_norm_scale = (wheel_radius * 2.0) / 0.956 # ~1.046
	
	var wheel_configs = [
		{"name": "FrontLeft",  "pos": Vector3(-0.88, wheel_radius, -1.20), "is_front": true,  "is_left": true},
		{"name": "FrontRight", "pos": Vector3( 0.88, wheel_radius, -1.20), "is_front": true,  "is_left": false},
		{"name": "RearLeft",   "pos": Vector3(-0.88, wheel_radius,  0.89), "is_front": false, "is_left": true},
		{"name": "RearRight",  "pos": Vector3( 0.88, wheel_radius,  0.89), "is_front": false, "is_left": false},
	]
	
	for cfg in wheel_configs:
		var steer_or_spin: Node3D
		if cfg["is_front"]:
			var steer = Node3D.new()
			steer.name = cfg["name"] + "Steer"
			steer.position = cfg["pos"]
			wheels.add_child(steer)
			steer.owner = root_node
			
			var spin = Node3D.new()
			spin.name = cfg["name"] + "Spin"
			steer.add_child(spin)
			spin.owner = root_node
			steer_or_spin = spin
		else:
			var spin = Node3D.new()
			spin.name = cfg["name"] + "Spin"
			spin.position = cfg["pos"]
			wheels.add_child(spin)
			spin.owner = root_node
			steer_or_spin = spin
		
		var wm = MeshInstance3D.new()
		wm.name = "WheelModel"
		wm.mesh = tire_mesh
		wm.scale = Vector3(tire_norm_scale, tire_norm_scale, tire_norm_scale)
		if cfg["is_left"]:
			wm.rotation_degrees.y = -90.0
		else:
			wm.rotation_degrees.y = 90.0
		steer_or_spin.add_child(wm)
		wm.owner = root_node
	
	# 3. Turret
	var turret = Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, 1.764, 0.52)
	turret.scale = Vector3(4.0, 4.0, 4.0)
	turret.set_script(load("res://src/enemies/ground/scout_buggy_turret.gd"))
	root_node.add_child(turret)
	turret.owner = root_node
	
	var mount_mesh = load("res://assets/Enemy/scout_buggy_Game_Asset/turret_mount.res")
	var gun_mesh = load("res://assets/Enemy/scout_buggy_Game_Asset/turret_gun.res")
	
	var mount_mi = MeshInstance3D.new()
	mount_mi.name = "MountModel"
	mount_mi.mesh = mount_mesh
	turret.add_child(mount_mi)
	mount_mi.owner = root_node
	
	var gun_pitch = Node3D.new()
	gun_pitch.name = "GunPitch"
	gun_pitch.position = Vector3(-0.009, 0.0547, -0.0007)
	turret.add_child(gun_pitch)
	gun_pitch.owner = root_node
	
	var recoil = Node3D.new()
	recoil.name = "Recoil"
	gun_pitch.add_child(recoil)
	recoil.owner = root_node
	
	var gun_mi = MeshInstance3D.new()
	gun_mi.name = "GunModel"
	gun_mi.mesh = gun_mesh
	recoil.add_child(gun_mi)
	gun_mi.owner = root_node
	
	var muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0114, 0.0403, -0.2845)
	recoil.add_child(muzzle)
	muzzle.owner = root_node
	
	# Save scene
	DirAccess.make_dir_absolute("res://scenes/enemies")
	var packed_scene = PackedScene.new()
	var pack_err = packed_scene.pack(root_node)
	if pack_err != OK:
		print("ERROR packing scene:", pack_err)
		quit(1)
		return
	
	var save_path = "res://scenes/enemies/scout_buggy_visuals.tscn"
	var save_err = ResourceSaver.save(packed_scene, save_path)
	if save_err != OK:
		print("ERROR saving scene:", save_err)
		quit(1)
		return
	
	print("SUCCESSFULLY saved scene to:", save_path)
	quit(0)

func _set_owners(node: Node, scene_owner: Node) -> void:
	for child in node.get_children():
		child.owner = scene_owner
		_set_owners(child, scene_owner)
