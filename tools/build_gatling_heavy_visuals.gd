extends SceneTree

func _init() -> void:
	print("--- Building Gatling Heavy 3D Visuals & Scene ---")
	var root := Node3D.new()
	root.name = "GatlingHeavyRig"

	# -------------------------------------------------------------
	# MATERIALS
	# -------------------------------------------------------------
	var mat_armor := StandardMaterial3D.new()
	mat_armor.resource_name = "mat_slate_purple"
	mat_armor.albedo_color = Color(0.35, 0.31, 0.42) # Muted slate-purple armor
	mat_armor.roughness = 0.92
	mat_armor.metallic = 0.0
	mat_armor.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	var mat_mustard := StandardMaterial3D.new()
	mat_mustard.resource_name = "mat_mustard_yellow"
	mat_mustard.albedo_color = Color(0.85, 0.64, 0.22) # Restrained mustard-yellow recognition panel
	mat_mustard.roughness = 0.90
	mat_mustard.metallic = 0.0

	var mat_charcoal := StandardMaterial3D.new()
	mat_charcoal.resource_name = "mat_charcoal"
	mat_charcoal.albedo_color = Color(0.18, 0.20, 0.24) # Charcoal weapon mechanics
	mat_charcoal.roughness = 0.88
	mat_charcoal.metallic = 0.05

	var mat_track := StandardMaterial3D.new()
	mat_track.resource_name = "mat_track_black"
	mat_track.albedo_color = Color(0.12, 0.13, 0.16) # Continuous track bands
	mat_track.roughness = 0.95
	mat_track.metallic = 0.0

	var mat_dark_muzzle := StandardMaterial3D.new()
	mat_dark_muzzle.resource_name = "mat_muzzle"
	mat_dark_muzzle.albedo_color = Color(0.05, 0.06, 0.07) # Dark bore holes
	mat_dark_muzzle.roughness = 0.98

	# -------------------------------------------------------------
	# 1. HULL & RUNNING GEAR (Length ~ 7.0m, Width ~ 4.2m, Height ~ 1.8m)
	# -------------------------------------------------------------
	var visuals := Node3D.new()
	visuals.name = "Visuals"
	root.add_child(visuals)
	visuals.owner = root

	var hull := Node3D.new()
	hull.name = "HullModel"
	visuals.add_child(hull)
	hull.owner = root

	# Main Armored Chassis Core
	_add_box(hull, root, Vector3(3.4, 0.95, 6.8), Vector3(0, 0.95, 0), mat_armor, "ChassisCore")

	# Upper Sloped Glacis Plate (Front sloped armor)
	_add_box(hull, root, Vector3(3.2, 0.45, 2.2), Vector3(0, 1.45, -1.8), mat_armor, "GlacisSlope", Vector3(-16, 0, 0))

	# Rear Engine Deck / Radiator Housing
	_add_box(hull, root, Vector3(3.0, 0.55, 2.4), Vector3(0, 1.40, 1.9), mat_armor, "EngineDeck")
	# Engine vents (charcoal slats)
	_add_box(hull, root, Vector3(2.4, 0.08, 1.6), Vector3(0, 1.70, 1.9), mat_charcoal, "EngineVents")

	# Mustard-Yellow Recognition Stripe across Glacis & Nose
	_add_box(hull, root, Vector3(3.24, 0.15, 0.8), Vector3(0, 1.55, -2.1), mat_mustard, "GlacisRecognitionPanel", Vector3(-16, 0, 0))
	_add_box(hull, root, Vector3(3.44, 0.4, 0.1), Vector3(0, 0.9, -3.41), mat_mustard, "NoseAccentStripe")

	# Enclosed Deep Track Skirts (Left & Right)
	for side in [-1.0, 1.0]:
		var s_name = "Left" if side > 0 else "Right"
		# Deep Armor Skirt (concealing road wheels)
		_add_box(hull, root, Vector3(0.55, 1.15, 7.0), Vector3(side * 1.9, 0.85, 0), mat_armor, "TrackSkirt_" + s_name)
		# Skirt Upper Chamfer / Bevel Ridge
		_add_box(hull, root, Vector3(0.6, 0.22, 6.8), Vector3(side * 1.9, 1.45, 0), mat_charcoal, "SkirtRidge_" + s_name)
		# Continuous Dark Track Band (lower visible portion)
		_add_box(hull, root, Vector3(0.52, 0.45, 6.6), Vector3(side * 1.88, 0.25, 0), mat_track, "TrackBand_" + s_name)
		# Track Sprocket & Idler End Caps
		_add_cylinder(hull, root, 0.42, 0.54, Vector3(side * 1.88, 0.42, -3.1), mat_charcoal, 8, "FrontSprocket_" + s_name, Vector3(0, 0, 90))
		_add_cylinder(hull, root, 0.42, 0.54, Vector3(side * 1.88, 0.42, 3.1), mat_charcoal, 8, "RearIdler_" + s_name, Vector3(0, 0, 90))

	# -------------------------------------------------------------
	# 2. TURRET (Compact, Angular with Substantial Rear Ammo Housing)
	# -------------------------------------------------------------
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 1.70, -0.2)
	root.add_child(turret)
	turret.owner = root

	# Turret Ring / Bearing Collar
	_add_cylinder(turret, root, 1.4, 0.25, Vector3(0, 0.12, 0), mat_charcoal, 10, "TurretRing")

	# Main Angular Turret Body
	_add_box(turret, root, Vector3(2.5, 0.85, 2.4), Vector3(0, 0.65, -0.2), mat_armor, "TurretCore")

	# Angular Sloped Turret Cheeks
	_add_box(turret, root, Vector3(2.52, 0.4, 1.2), Vector3(0, 0.95, -0.6), mat_armor, "TurretRoofSlope", Vector3(-18, 0, 0))

	# Restrained Mustard Recognition Roof Panel (for top-down camera identification)
	_add_box(turret, root, Vector3(1.6, 0.08, 1.2), Vector3(0, 1.10, -0.1), mat_mustard, "TurretRoofMarker")

	# Dark Vision Ports / Commander Hatch
	_add_cylinder(turret, root, 0.45, 0.18, Vector3(0.6, 1.15, 0.2), mat_charcoal, 8, "CommanderCupola")
	_add_box(turret, root, Vector3(0.8, 0.16, 0.12), Vector3(0, 0.75, -1.41), mat_charcoal, "DriverVisorSlot")

	# Substantial Rear Ammunition Housing (Bustle extending behind turret)
	_add_box(turret, root, Vector3(2.3, 0.95, 1.8), Vector3(0, 0.68, 1.75), mat_armor, "RearAmmoHousing")
	# Ammo Housing Top Latches & Pressure Vents
	_add_box(turret, root, Vector3(1.8, 0.15, 1.4), Vector3(0, 1.20, 1.75), mat_charcoal, "AmmoHousingLid")

	# Solid Ammunition Feed Enclosure (Connects rear housing to receiver)
	# Heavy solid conduit / trunking (avoiding individual bullet chains)
	_add_box(turret, root, Vector3(0.65, 0.55, 1.8), Vector3(0.95, 0.65, 0.2), mat_charcoal, "SolidAmmoFeedConduit", Vector3(0, -12, 0))
	_add_box(turret, root, Vector3(0.68, 0.12, 0.8), Vector3(0.95, 0.95, 0.2), mat_mustard, "AmmoFeedStripe")

	# -------------------------------------------------------------
	# 3. OVERSIZED ROTARY GATLING ASSEMBLY
	# -------------------------------------------------------------
	# Stationary Weapon Cradle / Trunnion Mount
	var gun_mount := Node3D.new()
	gun_mount.name = "GunMount"
	gun_mount.position = Vector3(0, 0.65, -1.4)
	turret.add_child(gun_mount)
	gun_mount.owner = root

	# Heavy Stationary Receiver Box
	_add_box(gun_mount, root, Vector3(1.5, 1.1, 1.4), Vector3(0, 0, 0), mat_charcoal, "StationaryReceiver")
	# Receiver Side Trunnion Brackets
	_add_cylinder(gun_mount, root, 0.45, 1.65, Vector3(0, 0, 0), mat_charcoal, 8, "TrunnionBearing", Vector3(0, 0, 90))

	# Heavy Mechanical Rear Drum / Rotor Housing
	_add_cylinder(gun_mount, root, 0.75, 0.8, Vector3(0, 0, -1.0), mat_charcoal, 10, "RotaryReceiverDrum", Vector3(90, 0, 0))

	# --- ROTATING BARREL ASSEMBLY (Separated with clear longitudinal spin axis) ---
	var rotary_barrels := Node3D.new()
	rotary_barrels.name = "RotaryBarrels"
	rotary_barrels.position = Vector3(0, 0, -1.4)
	gun_mount.add_child(rotary_barrels)
	rotary_barrels.owner = root

	# Central Rotation Drive Core / Shaft
	_add_cylinder(rotary_barrels, root, 0.28, 2.8, Vector3(0, 0, -1.4), mat_charcoal, 8, "CentralRotorShaft", Vector3(90, 0, 0))

	# Supporting Muzzle Collar near front
	_add_cylinder(rotary_barrels, root, 0.72, 0.35, Vector3(0, 0, -2.4), mat_charcoal, 10, "FrontSupportingCollar", Vector3(90, 0, 0))
	# Accent Ring on Collar
	_add_cylinder(rotary_barrels, root, 0.74, 0.12, Vector3(0, 0, -2.4), mat_mustard, 10, "CollarAccentRing", Vector3(90, 0, 0))

	# Rear Barrel Clamp Plate
	_add_cylinder(rotary_barrels, root, 0.72, 0.25, Vector3(0, 0, -0.4), mat_charcoal, 10, "RearClampPlate", Vector3(90, 0, 0))

	# EXACTLY SIX FACETED BARRELS (Arranged symmetrically in circle, 60 deg increments)
	var barrel_radius := 0.44
	var barrel_length := 2.7
	for i in 6:
		var angle := float(i) * TAU / 6.0
		var bx := cos(angle) * barrel_radius
		var by := sin(angle) * barrel_radius

		# Faceted 8-sided barrel cylinder
		_add_cylinder(rotary_barrels, root, 0.12, barrel_length, Vector3(bx, by, -1.4), mat_charcoal, 8, "GatlingBarrel_" + str(i + 1), Vector3(90, 0, 0))

		# Visible Dark Muzzle Opening (slightly recessed cap at front tip)
		_add_cylinder(rotary_barrels, root, 0.08, 0.06, Vector3(bx, by, -2.76), mat_dark_muzzle, 8, "MuzzleOpening_" + str(i + 1), Vector3(90, 0, 0))

	# Save packed scene
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err == OK:
		var scene_path := "res://scenes/enemies/gatling_heavy_visuals.tscn"
		var save_err := ResourceSaver.save(scene, scene_path)
		print("Successfully saved scene to: ", scene_path, " (err: ", save_err, ")")
	else:
		print("Error packing scene: ", err)

	quit(0)

func _add_box(parent: Node3D, owner_node: Node3D, size: Vector3, pos: Vector3, mat: Material, node_name: String, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	inst.mesh = box
	inst.position = pos
	inst.rotation_degrees = rot_deg
	parent.add_child(inst)
	inst.owner = owner_node
	return inst

func _add_cylinder(parent: Node3D, owner_node: Node3D, radius: float, height: float, pos: Vector3, mat: Material, segments: int, node_name: String, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = segments
	cyl.rings = 1
	cyl.material = mat
	inst.mesh = cyl
	inst.position = pos
	inst.rotation_degrees = rot_deg
	parent.add_child(inst)
	inst.owner = owner_node
	return inst
