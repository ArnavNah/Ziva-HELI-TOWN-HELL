extends RefCounted
## Procedural 3D visuals for ground and air raider enemies with authentic Nuclear Strike military styling.
const Materials = preload("res://src/world/stylized_materials.gd")

const AssaultAPCScene: PackedScene = preload("res://scenes/enemies/assault_apc_visuals.tscn")
const ScoutBuggyScene: PackedScene = preload("res://scenes/enemies/scout_buggy_visuals.tscn")
const GatlingHeavyScene: PackedScene = preload("res://scenes/enemies/gatling_heavy_visuals.tscn")
const InterceptorScene: PackedScene = preload("res://scenes/enemies/air/crimson_skyblade_visuals.tscn")
const RaptorRaiderScene: PackedScene = preload("res://scenes/enemies/raptor_raider_visuals.tscn")
const DesertBarrageRoverScene: PackedScene = preload("res://scenes/enemies/desert_barrage_rover_visuals.tscn")
const AzureSiegeTankScene: PackedScene = preload("res://scenes/enemies/azure_siege_tank_visuals.tscn")
const DesertIroncladScene: PackedScene = preload("res://scenes/enemies/desert_ironclad_visuals.tscn")

const IronViperScene: PackedScene = preload("res://scenes/enemies/air/iron_viper_visuals.tscn")
const CrimsonDesertScene: PackedScene = preload("res://scenes/enemies/air/crimson_desert_visuals.tscn")
const DesertRotorbladeBossScene: PackedScene = preload("res://scenes/enemies/air/desert_rotorblade_boss_visuals.tscn")
const AstraViperScene: PackedScene = preload("res://scenes/enemies/air/astra_viper_visuals.tscn")
const CrimsonSkybladeScene: PackedScene = preload("res://scenes/enemies/air/crimson_skyblade_visuals.tscn")
const IroncladSkycarrierScene: PackedScene = preload("res://scenes/enemies/air/ironclad_skycarrier_visuals.tscn")
const IroncladSkyrunnerScene: PackedScene = preload("res://scenes/enemies/air/ironclad_skyrunner_visuals.tscn")
const ViperhawkGunshipScene: PackedScene = preload("res://scenes/enemies/air/viperhawk_gunship_visuals.tscn")

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
		"attack_gunship":
			_mount_air_rig(enemy, visual, IronViperScene, "Iron Viper Gunship")

		"rocket_gunship":
			_mount_air_rig(enemy, visual, CrimsonDesertScene, "Crimson Desert Gunship")

		"heavy_gunship_boss":
			_mount_air_rig(enemy, visual, DesertRotorbladeBossScene, "Desert Rotorblade Miniature Boss")

		"interceptor":
			_mount_air_rig(enemy, visual, CrimsonSkybladeScene, "Crimson Skyblade")

		"attack_wing":
			_mount_air_rig(enemy, visual, IroncladSkyrunnerScene, "Ironclad Skyrunner")

		"escort_fighter":
			_mount_air_rig(enemy, visual, AstraViperScene, "Astra Viper")

		"heavy_bomber":
			_mount_air_rig(enemy, visual, IroncladSkycarrierScene, "Ironclad Skycarrier")

		"torpedo_vtol", "stealth_vtol", "minelayer":
			_mount_air_rig(enemy, visual, ViperhawkGunshipScene, "Viperhawk Gunship")

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

static func _mount_air_rig(enemy: Node3D, visual: Node3D, scene: PackedScene, vehicle_name: String) -> void:
	if scene:
		if visual and visual.get_parent() == enemy:
			enemy.remove_child(visual)
			visual.free()
		var rig = scene.instantiate()
		rig.name = "Visuals"
		enemy.add_child(rig)
	else:
		push_error("%s air scene unavailable" % vehicle_name)

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


