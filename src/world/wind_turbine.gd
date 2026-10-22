class_name WindTurbine
extends Node3D

@export var rotation_speed: float = 0.8
var rotor_node: Node3D = null

func _ready() -> void:
	_build_turbine()

func _build_turbine() -> void:
	var tower_mat = StandardMaterial3D.new()
	tower_mat.albedo_color = Color(0.94, 0.95, 0.98)
	tower_mat.roughness = 0.65

	var blade_mat = StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.92, 0.93, 0.96)
	blade_mat.roughness = 0.55

	# Tapered Tower
	var tower = MeshInstance3D.new()
	var tm = CylinderMesh.new()
	tm.top_radius = 0.55
	tm.bottom_radius = 1.15
	tm.height = 24.0
	tm.radial_segments = 7
	tm.material = tower_mat
	tower.mesh = tm
	tower.position.y = 12.0
	add_child(tower)

	# Nacelle generator pod
	var nacelle = MeshInstance3D.new()
	var nm = BoxMesh.new()
	nm.size = Vector3(1.2, 1.2, 3.2)
	nm.material = tower_mat
	nacelle.mesh = nm
	nacelle.position.y = 24.0
	add_child(nacelle)

	# Rotor hub & blades
	rotor_node = Node3D.new()
	rotor_node.position = Vector3(0, 24.0, 1.6)
	add_child(rotor_node)

	# Hub
	var hub = MeshInstance3D.new()
	var hm = SphereMesh.new()
	hm.radius = 0.65
	hm.height = 1.3
	hm.radial_segments = 6
	hm.rings = 3
	hm.material = tower_mat
	hub.mesh = hm
	rotor_node.add_child(hub)

	# 3 aerodynamic blades
	for i in 3:
		var angle := float(i) * TAU / 3.0
		var blade = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.38, 8.5, 0.08)
		bm.material = blade_mat
		blade.mesh = bm
		blade.position = Vector3(sin(angle) * 4.4, cos(angle) * 4.4, 0)
		blade.rotation.z = -angle
		rotor_node.add_child(blade)

func _process(delta: float) -> void:
	if rotor_node:
		rotor_node.rotate_z(delta * rotation_speed)
