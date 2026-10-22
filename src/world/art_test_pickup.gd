class_name ArtTestPickup
extends Node3D

## ArtTestPickup — Interactive supply pickup for visual readability check.
## Features:
## - Bright amber accent (Color(1.0, 0.75, 0.15)) designed to stand out against muted asphalt/olive terrain
## - Gentle bobbing and continuous rotation
## - Area3D detection trigger

var time: float = 0.0
var base_y: float = 1.0

var icon_root: Node3D
var area: Area3D

func _ready() -> void:
	base_y = position.y if position.y > 0.1 else 1.0
	_build_visuals()

func _build_visuals() -> void:
	icon_root = Node3D.new()
	icon_root.name = "FloatingIcon"
	add_child(icon_root)
	
	# Central Ammo Box / Battery Core
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.8, 0.8, 0.8)
	var mat := StandardMaterial3D.new()
	mat.resource_name = "mat_pickup_glow"
	mat.albedo_color = Color(1.0, 0.76, 0.18) # Bright tactical amber
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.70, 0.12)
	mat.emission_energy_multiplier = 1.6
	mat.roughness = 0.4
	
	var box_inst := MeshInstance3D.new()
	box_inst.mesh = box_mesh
	box_inst.material_override = mat
	icon_root.add_child(box_inst)
	
	# Accent cross bands (high contrast dark border)
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(0.84, 0.22, 0.84)
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.18, 0.20, 0.22)
	band_mat.roughness = 0.8
	var band_inst := MeshInstance3D.new()
	band_inst.mesh = band_mesh
	band_inst.material_override = band_mat
	icon_root.add_child(band_inst)
	
	# Collision Area
	area = Area3D.new()
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.2
	col.shape = sphere
	area.add_child(col)
	add_child(area)

func _process(delta: float) -> void:
	time += delta
	if icon_root:
		icon_root.rotation.y += delta * 2.2
		icon_root.rotation.x = sin(time * 1.5) * 0.15
		position.y = base_y + sin(time * 3.0) * 0.22
