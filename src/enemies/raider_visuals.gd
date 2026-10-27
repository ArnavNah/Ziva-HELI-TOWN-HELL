extends RefCounted
## Procedural 3D visuals for ground and air raider enemies with authentic Nuclear Strike military styling.
const Materials = preload("res://src/world/stylized_materials.gd")

const AssaultAPCScene: PackedScene = preload("res://scenes/enemies/assault_apc_visuals.tscn")
const ScoutBuggyScene: PackedScene = preload("res://scenes/enemies/scout_buggy_visuals.tscn")
const GatlingHeavyScene: PackedScene = preload("res://scenes/enemies/gatling_heavy_visuals.tscn")
const InterceptorScene: PackedScene = preload("res://scenes/enemies/interceptor_visuals.tscn")
const RaptorRaiderScene: PackedScene = preload("res://scenes/enemies/raptor_raider_visuals.tscn")
const DesertBarrageRoverScene: PackedScene = preload("res://scenes/enemies/desert_barrage_rover_visuals.tscn")
const AzureSiegeTankScene: PackedScene = preload("res://scenes/enemies/azure_siege_tank_visuals.tscn")
const DesertIroncladScene: PackedScene = preload("res://scenes/enemies/desert_ironclad_visuals.tscn")

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
			_mount_modular_rig(enemy, visual, AssaultAPCScene, "Assault APC")

		"scout_buggy":
			_mount_modular_rig(enemy, visual, ScoutBuggyScene, "Scout Buggy")

		"gatling_heavy":
			_mount_modular_rig(enemy, visual, GatlingHeavyScene, "Gatling Heavy")

		"raptor_raider":
			_mount_modular_rig(enemy, visual, RaptorRaiderScene, "Raptor Raider")

		"desert_barrage_rover":
			_mount_modular_rig(enemy, visual, DesertBarrageRoverScene, "Desert Barrage Rover")

		"rail_crawler":
			_mount_modular_rig(enemy, visual, AzureSiegeTankScene, "Azure Siege Tank")

		"siege_tank":
			_mount_modular_rig(enemy, visual, DesertIroncladScene, "Desert Ironclad")

		_:
			push_warning("RaiderVisuals: unknown role: %s" % role)

static func _mount_modular_rig(enemy: Node3D, visual: Node3D, scene: PackedScene, vehicle_name: String) -> void:
	if scene:
		enemy.remove_child(visual)
		visual.queue_free()
		var rig = scene.instantiate()
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
			push_error("%s visuals hierarchy incomplete (missing Visuals or Turret)" % vehicle_name)
	else:
		push_error("%s modular scene unavailable" % vehicle_name)

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


