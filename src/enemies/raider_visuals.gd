extends RefCounted
## Procedural 3D visuals for ground and air raider enemies with authentic Nuclear Strike military styling.
const Materials = preload("res://src/world/stylized_materials.gd")

const AssaultAPCScene: PackedScene = preload("res://scenes/enemies/assault_apc_visuals.tscn")
const ScoutBuggyScene: PackedScene = preload("res://scenes/enemies/scout_buggy_visuals.tscn")
const GatlingHeavyScene: PackedScene = preload("res://scenes/enemies/gatling_heavy_visuals.tscn")
const InterceptorScene: PackedScene = preload("res://scenes/enemies/interceptor_visuals.tscn")
const RaptorRaiderScene: PackedScene = preload("res://scenes/enemies/raptor_raider_visuals.tscn")
const DesertBarrageRoverScene: PackedScene = preload("res://scenes/enemies/desert_barrage_rover_visuals.tscn")

static func build(enemy: Node3D, role: String) -> void:
	var visual := Node3D.new()
	visual.name = "Visuals"
	enemy.add_child(visual)

	var armor := Materials.surface(Color("7d8850")) # Tactical military olive
	var steel := Materials.surface(Color("4a5866")) # Armored gunmetal steel
	var dark := Materials.surface(Color("222b35"))  # Deep tire/chassis black
	var accent := Materials.surface(Color("f4b653"))# Golden alert yellow
	var red := Materials.surface(Color("d94336"))   # Hazard red
	var desert := Materials.surface(Color("c29653"))# Desert tan camo

	match role:
		"attack_gunship", "rocket_gunship", "minelayer":
			# Dedicated authentic hostile military attack helicopter (Nuclear Strike style)
			var gunship_camo := Materials.surface(Color("3a4b44")) # Dark hostile olive drab
			var hostile_dark := Materials.surface(Color("1e262c")) # Shadow charcoal armor
			var visor_crimson := Materials.surface(Color("c43828")) # Hostile tinted red canopy
			
			# 1. Aerodynamic Chisel-Nose & Armored Cockpit
			box(visual, Vector3(1.6, 0.85, 2.4), Vector3(0, 1.0, -2.4), gunship_camo)
			box(visual, Vector3(1.1, 0.65, 2.0), Vector3(0, 1.55, -1.8), visor_crimson)
			box(visual, Vector3(0.9, 0.2, 1.6), Vector3(0, 1.9, -1.8), hostile_dark)
			
			# 2. Main Fuselage & Engine Nacelles
			box(visual, Vector3(2.2, 1.35, 4.2), Vector3(0, 1.15, 0.4), gunship_camo)
			for side in [-1.0, 1.0]:
				box(visual, Vector3(0.65, 0.55, 2.6), Vector3(side * 0.85, 1.7, 0.5), steel)
				cylinder(visual, 0.24, 0.5, Vector3(side * 0.85, 1.7, 1.9), dark, 8)
			
			# 3. Weapons Wings & Ordnance
			box(visual, Vector3(5.4, 0.18, 1.1), Vector3(0, 0.95, -0.1), gunship_camo)
			for side in [-1.0, 1.0]:
				box(visual, Vector3(0.18, 0.28, 1.1), Vector3(side * 2.7, 0.95, -0.1), dark)
				box(visual, Vector3(0.12, 0.12, 1.4), Vector3(side * 2.7, 0.95, -0.1), red)
				cylinder(visual, 0.32, 1.5, Vector3(side * 1.8, 0.65, 0.0), steel, 8)
				box(visual, Vector3(0.48, 0.48, 0.1), Vector3(side * 1.8, 0.65, -0.75), accent)
				if role == "rocket_gunship":
					cylinder(visual, 0.28, 1.3, Vector3(side * 1.0, 0.65, 0.1), steel, 8)
					box(visual, Vector3(0.42, 0.42, 0.1), Vector3(side * 1.0, 0.65, -0.55), red)
				elif role == "minelayer":
					box(visual, Vector3(0.55, 0.6, 1.8), Vector3(side * 1.3, 0.55, 1.2), hostile_dark)
			
			# 4. Tail Boom & Stabilizers
			box(visual, Vector3(0.55, 0.65, 4.8), Vector3(0, 1.3, 4.2), gunship_camo)
			box(visual, Vector3(0.14, 1.6, 1.2), Vector3(0, 2.0, 6.3), hostile_dark)
			box(visual, Vector3(2.4, 0.12, 0.7), Vector3(0, 1.45, 5.8), gunship_camo)
			box(visual, Vector3(0.2, 0.15, 0.6), Vector3(0, 2.75, 6.3), accent)
			cylinder(visual, 0.65, 0.04, Vector3(0.15, 2.1, 6.3), dark, 8)
			
			# 5. Rotor Mast, Hub & Animated Main Rotor
			cylinder(visual, 0.18, 0.5, Vector3(0, 1.95, -0.1), steel, 8)
			var disc_mat := StandardMaterial3D.new()
			disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			disc_mat.albedo_color = Color(0.12, 0.16, 0.18, 0.28)
			var disc_inst := MeshInstance3D.new()
			var disc_cyl := CylinderMesh.new()
			disc_cyl.top_radius = 4.8
			disc_cyl.bottom_radius = 4.8
			disc_cyl.height = 0.02
			disc_cyl.material = disc_mat
			disc_inst.mesh = disc_cyl
			disc_inst.position = Vector3(0, 2.2, -0.1)
			visual.add_child(disc_inst)
			
			var rotor := Node3D.new()
			rotor.name = "AnimatedRotor"
			rotor.position = Vector3(0, 2.22, -0.1)
			visual.add_child(rotor)
			box(rotor, Vector3(9.4, 0.05, 0.35), Vector3.ZERO, dark)
			box(rotor, Vector3(0.35, 0.05, 9.4), Vector3.ZERO, dark)
			box(rotor, Vector3(0.5, 0.06, 0.36), Vector3(-4.45, 0, 0), accent)
			box(rotor, Vector3(0.5, 0.06, 0.36), Vector3(4.45, 0, 0), accent)
			box(rotor, Vector3(0.36, 0.06, 0.5), Vector3(0, 0, -4.45), accent)
			box(rotor, Vector3(0.36, 0.06, 0.5), Vector3(0, 0, 4.45), accent)
			
			# 6. Articulated Chin Autocannon Turret (Tracks player)
			var turret := Node3D.new()
			turret.name = "Turret"
			turret.position = Vector3(0, 0.5, -2.4)
			enemy.add_child(turret)
			box(turret, Vector3(0.55, 0.45, 0.65), Vector3.ZERO, steel)
			cylinder(turret, 0.08, 2.2, Vector3(0, -0.05, -1.1), dark, 8)
			box(turret, Vector3(0.18, 0.16, 0.3), Vector3(0, -0.05, -2.2), red)
			box(turret, Vector3(0.35, 0.3, 0.4), Vector3(0.32, 0.05, -0.15), accent)

		"interceptor":
			var modular_scene: PackedScene = InterceptorScene
			if modular_scene:
				enemy.remove_child(visual)
				visual.queue_free()
				
				var rig = modular_scene.instantiate()
				var airframe = rig.get_node_or_null("Airframe")
				if airframe:
					rig.remove_child(airframe)
					airframe.owner = null
					enemy.add_child(airframe)
					rig.queue_free()
				else:
					enemy.add_child(rig)
			else:
				push_warning("Interceptor modular visuals unavailable, falling back to procedural model")
				box(visual, Vector3(1.3, 0.8, 4.0), Vector3(0, 0.8, 0), dark)
				box(visual, Vector3(6.5, 0.18, 1.6), Vector3(0, 0.9, 0.2), armor)

		"attack_wing":
			# High-speed delta-wing strike fighter
			box(visual, Vector3(1.3, 0.8, 4.0), Vector3(0, 0.8, 0), dark)
			box(visual, Vector3(6.5, 0.18, 1.6), Vector3(0, 0.9, 0.2), armor)
			box(visual, Vector3(2.4, 0.15, 0.8), Vector3(0, 1.0, 1.7), dark)
			box(visual, Vector3(0.7, 0.5, 1.1), Vector3(0, 1.2, -1.0), accent)
			for side in [-1.0, 1.0]:
				box(visual, Vector3(0.35, 0.35, 1.3), Vector3(side * 2.0, 0.6, 0.2), dark)
				box(visual, Vector3(0.6, 0.2, 1.6), Vector3(side * 2.6, 1.02, 0.2), accent)

		"stealth_vtol":
			# Dual tilt-rotor agile VTOL gunship
			var vtol_camo := Materials.surface(Color("2d3748"))
			box(visual, Vector3(1.8, 1.1, 4.8), Vector3(0, 1.0, 0), vtol_camo)
			box(visual, Vector3(1.2, 0.7, 1.6), Vector3(0, 1.1, -1.8), dark) # Canopy
			box(visual, Vector3(7.2, 0.22, 1.2), Vector3(0, 1.2, -0.2), vtol_camo) # High-mounted wing
			# Twin wingtip tilt-rotor nacelles & blur discs
			for side in [-1.0, 1.0]:
				box(visual, Vector3(0.7, 0.8, 1.4), Vector3(side * 3.6, 1.3, -0.2), steel)
				cylinder(visual, 1.6, 0.04, Vector3(side * 3.6, 1.8, -0.2), dark, 8)
				box(visual, Vector3(0.4, 0.3, 0.9), Vector3(side * 1.6, 0.6, 0.4), accent) # Missile rails
			# Chin turret
			var turret := Node3D.new()
			turret.name = "Turret"
			turret.position = Vector3(0, 0.5, -2.0)
			enemy.add_child(turret)
			box(turret, Vector3(0.5, 0.4, 0.6), Vector3.ZERO, steel)
			box(turret, Vector3(0.12, 0.12, 1.2), Vector3(-0.16, 0, -0.6), red)
			box(turret, Vector3(0.12, 0.12, 1.2), Vector3(0.16, 0, -0.6), red)

		"heavy_bomber":
			# Tactical heavy swept-wing dreadnought aircraft
			box(visual, Vector3(2.4, 1.5, 7.8), Vector3(0, 1.2, 0), steel)
			box(visual, Vector3(10.8, 0.25, 2.4), Vector3(0, 1.4, 0.4), armor) # Wide wings
			box(visual, Vector3(4.2, 0.20, 1.2), Vector3(0, 1.5, 3.4), steel) # Tail elevators
			box(visual, Vector3(0.25, 1.8, 1.4), Vector3(0, 2.2, 3.2), accent) # Tail fin
			for side in [-1.0, 1.0]:
				cylinder(visual, 0.6, 2.2, Vector3(side * 2.8, 0.8, 0.6), dark, 8) # Jet nacelles
				box(visual, Vector3(0.5, 0.3, 1.4), Vector3(side * 4.4, 1.1, 0.8), red) # Ordnance bays
			var turret := Node3D.new()
			turret.name = "Turret"
			turret.position = Vector3(0, 0.4, 0)
			enemy.add_child(turret)
			box(turret, Vector3(1.2, 0.3, 2.4), Vector3(0, 0, 0), dark)

		"assault_apc":
			var modular_scene: PackedScene = AssaultAPCScene
			if modular_scene:
				# Remove placeholder visual created at start of build()
				enemy.remove_child(visual)
				visual.queue_free()
				
				var rig = modular_scene.instantiate()
				var new_visuals = rig.get_node_or_null("Visuals")
				var turret = rig.get_node_or_null("Turret")
				if new_visuals and turret:
					rig.remove_child(new_visuals)
					rig.remove_child(turret)
					new_visuals.owner = null
					turret.owner = null
					enemy.add_child(new_visuals)
					enemy.add_child(turret)
					rig.queue_free()
				else:
					push_warning("Assault APC modular visuals hierarchy incomplete, falling back to procedural model")
					_build_procedural_assault_apc(enemy, visual)
			else:
				push_warning("Assault APC modular visuals unavailable, falling back to procedural model")
				_build_procedural_assault_apc(enemy, visual)

		"sam_launcher":
			# Heavy tracked surface-to-air missile platform
			box(visual, Vector3(3.4, 1.2, 6.4), Vector3(0, 1.0, 0), steel)
			box(visual, Vector3(3.6, 0.9, 5.8), Vector3(0, 0.6, 0), dark) # Lower hull & tracks
			# Caterpillar tread sides
			for side in [-1.0, 1.0]:
				box(visual, Vector3(0.6, 0.9, 6.0), Vector3(side * 1.7, 0.6, 0), dark)
				box(visual, Vector3(0.7, 0.2, 5.8), Vector3(side * 1.7, 1.1, 0), armor) # Skirts
			# SAM Launch Turret with 4 missile tubes
			var turret := Node3D.new()
			turret.name = "Turret"
			turret.position = Vector3(0, 1.8, -0.4)
			enemy.add_child(turret)
			box(turret, Vector3(2.2, 0.8, 2.2), Vector3.ZERO, armor)
			# 4 angled missile canisters
			for sx in [-0.65, 0.65]:
				for sy in [0.4, 1.0]:
					cylinder(turret, 0.24, 2.6, Vector3(sx, sy, -0.4), Materials.surface(Color("e8ecef")), 8)
					box(turret, Vector3(0.28, 0.28, 0.4), Vector3(sx, sy, -1.6), red) # Warhead tip
			# Radar tracking dish
			cylinder(turret, 0.6, 0.1, Vector3(0, 1.4, 0.6), accent, 8)

		"technical_truck":
			# Agile desert raider pickup with heavy machine gun pintle
			box(visual, Vector3(2.2, 0.9, 2.2), Vector3(0, 1.1, -1.0), desert) # Cab
			box(visual, Vector3(1.9, 0.6, 1.4), Vector3(0, 1.6, -0.8), dark) # Windshield/roof
			box(visual, Vector3(2.2, 0.7, 2.6), Vector3(0, 0.9, 1.2), desert) # Truck bed
			box(visual, Vector3(0.12, 0.8, 2.4), Vector3(-1.0, 1.3, 1.2), steel) # Bed side rail L
			box(visual, Vector3(0.12, 0.8, 2.4), Vector3(1.0, 1.3, 1.2), steel) # Bed side rail R
			# 4 off-road tires
			for side in [-1.0, 1.0]:
				for axle in [-1.4, 1.4]:
					wheel_mesh(visual, 0.58, 0.4, Vector3(side * 1.2, 0.58, axle), dark)
			# Rear pintle gun
			var turret := Node3D.new()
			turret.name = "Turret"
			turret.position = Vector3(0, 1.6, 1.2)
			enemy.add_child(turret)
			box(turret, Vector3(0.4, 0.8, 0.4), Vector3(0, 0, 0), steel) # Mount
			box(turret, Vector3(0.3, 0.3, 1.6), Vector3(0, 0.4, -0.6), dark) # Heavy barrel
			box(turret, Vector3(0.4, 0.3, 0.4), Vector3(0.3, 0.4, -0.2), accent) # Ammo box

		"scout_buggy":
			var modular_scene: PackedScene = ScoutBuggyScene
			if modular_scene:
				# Remove placeholder visual created at start of build()
				enemy.remove_child(visual)
				visual.queue_free()
				
				var rig = modular_scene.instantiate()
				var new_visuals = rig.get_node_or_null("Visuals")
				var turret = rig.get_node_or_null("Turret")
				if new_visuals and turret:
					rig.remove_child(new_visuals)
					rig.remove_child(turret)
					new_visuals.owner = null
					turret.owner = null
					enemy.add_child(new_visuals)
					enemy.add_child(turret)
					rig.queue_free()
				else:
					push_warning("Scout Buggy modular visuals hierarchy incomplete, falling back to procedural model")
					_build_procedural_scout_buggy(enemy, visual)
			else:
				push_warning("Scout Buggy modular visuals unavailable, falling back to procedural model")
				_build_procedural_scout_buggy(enemy, visual)

		"gatling_heavy":
			var modular_scene: PackedScene = GatlingHeavyScene
			if modular_scene:
				# Remove placeholder visual created at start of build()
				enemy.remove_child(visual)
				visual.queue_free()
				
				var rig = modular_scene.instantiate()
				var new_visuals = rig.get_node_or_null("Visuals")
				var turret = rig.get_node_or_null("Turret")
				if new_visuals and turret:
					rig.remove_child(new_visuals)
					rig.remove_child(turret)
					new_visuals.owner = null
					turret.owner = null
					enemy.add_child(new_visuals)
					enemy.add_child(turret)
					rig.queue_free()
				else:
					push_warning("Gatling Heavy modular visuals hierarchy incomplete, falling back to procedural model")
					_build_procedural_gatling_heavy(enemy, visual)
			else:
				push_warning("Gatling Heavy modular visuals unavailable, falling back to procedural model")
				_build_procedural_gatling_heavy(enemy, visual)

		"raptor_raider":
			var modular_scene: PackedScene = RaptorRaiderScene
			if modular_scene:
				enemy.remove_child(visual)
				visual.queue_free()
				var rig = modular_scene.instantiate()
				var new_visuals = rig.get_node_or_null("Visuals")
				var turret = rig.get_node_or_null("Turret")
				if new_visuals and turret:
					rig.remove_child(new_visuals)
					rig.remove_child(turret)
					new_visuals.owner = null
					turret.owner = null
					enemy.add_child(new_visuals)
					enemy.add_child(turret)
					rig.queue_free()
				else:
					push_warning("Raptor Raider visuals hierarchy incomplete")
			else:
				push_warning("Raptor Raider scene unavailable")

		"desert_barrage_rover":
			var modular_scene: PackedScene = DesertBarrageRoverScene
			if modular_scene:
				enemy.remove_child(visual)
				visual.queue_free()
				var rig = modular_scene.instantiate()
				var new_visuals = rig.get_node_or_null("Visuals")
				var turret = rig.get_node_or_null("Turret")
				if new_visuals and turret:
					rig.remove_child(new_visuals)
					rig.remove_child(turret)
					new_visuals.owner = null
					turret.owner = null
					enemy.add_child(new_visuals)
					enemy.add_child(turret)
					rig.queue_free()
				else:
					push_warning("Desert Barrage Rover visuals hierarchy incomplete")
			else:
				push_warning("Desert Barrage Rover scene unavailable")

		"mortar_crawler", _:
			box(visual, Vector3(2.8, 0.85, 5.0), Vector3(0, 0.9, 0), armor)
			box(visual, Vector3(2.0, 0.9, 2.0), Vector3(0, 1.65, 0.4), dark)
			for side in [-1.0, 1.0]:
				for axle in [-1.4, 0.0, 1.4]:
					wheel_mesh(visual, 0.6, 0.45, Vector3(side * 1.4, 0.6, axle), dark)
			var turret := Node3D.new()
			turret.name = "Turret"
			turret.position = Vector3(0, 2.0, 0)
			enemy.add_child(turret)
			box(turret, Vector3(1.2, 0.5, 1.2), Vector3.ZERO, armor)
			for side in [-0.4, 0.4]:
				box(turret, Vector3(0.5, 0.5, 2.2), Vector3(side, 0.3, -0.8), accent)
			box(visual, Vector3(2.2, 0.16, 0.3), Vector3(0, 1.3, -2.0), accent)

static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)

static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, segments: int = 8) -> void:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.material = mat
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)

static func wheel_mesh(parent: Node3D, radius: float, width: float, pos: Vector3, mat: Material) -> void:
	var wheel := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = width
	mesh.radial_segments = 8
	mesh.material = mat
	wheel.mesh = mesh
	wheel.rotation.z = PI * 0.5
	wheel.position = pos
	parent.add_child(wheel)

static func _build_procedural_scout_buggy(enemy: Node3D, visual: Node3D) -> void:
	var buggy_color := Materials.surface(Color("af6546"))
	var dark := Materials.surface(Color("222b35"))
	var accent := Materials.surface(Color("f4b653"))
	box(visual, Vector3(2.6, 0.75, 4.0), Vector3(0, 0.9, 0), buggy_color)
	box(visual, Vector3(1.8, 0.9, 1.8), Vector3(0, 1.65, 0.4), dark)
	for side in [-1.0, 1.0]:
		for axle in [-1.25, 1.25]:
			wheel_mesh(visual, 0.6, 0.45, Vector3(side * 1.4, 0.6, axle), dark)
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 2.0, 0)
	enemy.add_child(turret)
	box(turret, Vector3(1.0, 0.4, 1.0), Vector3.ZERO, buggy_color)
	box(turret, Vector3(0.18, 0.18, 1.6), Vector3(0, 0.3, -0.8), dark)
	box(visual, Vector3(2.2, 0.16, 0.3), Vector3(0, 1.3, -1.6), accent)

static func _build_procedural_assault_apc(enemy: Node3D, visual: Node3D) -> void:
	var armor := Materials.surface(Color("7d8850"))
	var steel := Materials.surface(Color("4a5866"))
	var dark := Materials.surface(Color("222b35"))
	var accent := Materials.surface(Color("f4b653"))
	box(visual, Vector3(3.2, 1.4, 6.2), Vector3(0, 1.2, 0), armor)
	box(visual, Vector3(2.8, 0.6, 2.2), Vector3(0, 1.8, 0.8), steel)
	box(visual, Vector3(3.0, 0.4, 1.8), Vector3(0, 1.1, -2.4), steel)
	for side in [-1.0, 1.0]:
		for axle in [-1.8, 0.0, 1.8]:
			wheel_mesh(visual, 0.65, 0.45, Vector3(side * 1.7, 0.65, axle), dark)
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 2.1, 0.4)
	enemy.add_child(turret)
	box(turret, Vector3(1.4, 0.6, 1.6), Vector3.ZERO, steel)
	box(turret, Vector3(0.14, 0.14, 2.4), Vector3(-0.25, 0.1, -1.2), dark)
	box(turret, Vector3(0.14, 0.14, 2.4), Vector3(0.25, 0.1, -1.2), dark)
	box(turret, Vector3(0.4, 0.5, 0.7), Vector3(0.8, 0.1, 0), accent)

static func _build_procedural_gatling_heavy(enemy: Node3D, visual: Node3D) -> void:
	var slate_purple := Materials.surface(Color("594f6b"))
	var charcoal := Materials.surface(Color("2e333d"))
	var mustard := Materials.surface(Color("d9a338"))
	var dark := Materials.surface(Color("1f2129"))
	# Hull
	box(visual, Vector3(3.4, 0.95, 6.8), Vector3(0, 0.95, 0), slate_purple)
	box(visual, Vector3(3.24, 0.15, 0.8), Vector3(0, 1.55, -2.1), mustard)
	for side in [-1.0, 1.0]:
		box(visual, Vector3(0.55, 1.15, 7.0), Vector3(side * 1.9, 0.85, 0), slate_purple)
		box(visual, Vector3(0.52, 0.45, 6.6), Vector3(side * 1.88, 0.25, 0), dark)
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 1.7, -0.2)
	enemy.add_child(turret)
	box(turret, Vector3(2.5, 0.9, 2.8), Vector3(0, 0.65, -0.2), slate_purple)
	cylinder(turret, 0.5, 3.4, Vector3(0, 0.65, -2.5), charcoal, 8)
	box(turret, Vector3(1.8, 0.9, 1.6), Vector3(0, 0.68, 1.75), charcoal)

