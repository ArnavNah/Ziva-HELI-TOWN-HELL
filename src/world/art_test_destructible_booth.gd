class_name ArtTestDestructibleBooth
extends Node3D

## ArtTestDestructibleBooth — Multi-stage destructible security outpost.
## Fulfills destruction guidelines:
## - Matching intact, damaged, and broken states with consistent origin (Vector3.ZERO) and scale
## - Closed interior faces on all debris pieces using shared fracture material
## - Collision height drops from 3.2m to 0.8m upon destruction to clear corridors

const Library = preload("res://src/world/retro_material_library.gd")

enum State {
	INTACT = 0,
	DAMAGED = 1,
	BROKEN = 2
}

@export var current_state: State = State.INTACT

var intact_node: Node3D
var damaged_node: Node3D
var broken_node: Node3D

var col_shape: CollisionShape3D
var box_shape: BoxShape3D
var static_body: StaticBody3D

func _ready() -> void:
	_build_components()
	set_state(current_state)

func _build_components() -> void:
	static_body = StaticBody3D.new()
	static_body.name = "BoothCollisionBody"
	add_child(static_body)
	
	col_shape = CollisionShape3D.new()
	box_shape = BoxShape3D.new()
	box_shape.size = Vector3(3.0, 3.2, 3.0)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0, 1.6, 0)
	static_body.add_child(col_shape)
	
	# -------------------------------------------------------------
	# 1. INTACT STATE
	# -------------------------------------------------------------
	intact_node = Node3D.new()
	intact_node.name = "State_Intact"
	add_child(intact_node)
	
	# Lower brick base (Y = 0 to 1.4m)
	var brick_base := BoxMesh.new()
	brick_base.size = Vector3(3.0, 1.4, 3.0)
	brick_base.material = Library.brick()
	var brick_inst := MeshInstance3D.new()
	brick_inst.mesh = brick_base
	brick_inst.position = Vector3(0, 0.7, 0)
	intact_node.add_child(brick_inst)
	
	# Upper plaster walls (Y = 1.4 to 2.8m)
	var plaster_wall := BoxMesh.new()
	plaster_wall.size = Vector3(3.0, 1.4, 3.0)
	plaster_wall.material = Library.plaster()
	var plaster_inst := MeshInstance3D.new()
	plaster_inst.mesh = plaster_wall
	plaster_inst.position = Vector3(0, 2.1, 0)
	intact_node.add_child(plaster_inst)
	
	# Observation Window (front Z = -1.5m)
	var win_mesh := BoxMesh.new()
	win_mesh.size = Vector3(1.8, 1.0, 0.1)
	var win_inst := MeshInstance3D.new()
	win_inst.mesh = win_mesh
	win_inst.material_override = Library.building_window()
	win_inst.position = Vector3(0, 2.1, -1.52)
	intact_node.add_child(win_inst)
	
	# Overhanging Roof Slab (Y = 2.8 to 3.2m)
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(3.4, 0.4, 3.4)
	roof_mesh.material = Library.pavement()
	var roof_inst := MeshInstance3D.new()
	roof_inst.mesh = roof_mesh
	roof_inst.position = Vector3(0, 3.0, 0)
	intact_node.add_child(roof_inst)
	
	# -------------------------------------------------------------
	# 2. DAMAGED STATE
	# -------------------------------------------------------------
	damaged_node = Node3D.new()
	damaged_node.name = "State_Damaged"
	add_child(damaged_node)
	
	# Cracked base
	var d_brick := BoxMesh.new()
	d_brick.size = Vector3(3.0, 1.4, 3.0)
	d_brick.material = Library.brick()
	var d_brick_inst := MeshInstance3D.new()
	d_brick_inst.mesh = d_brick
	d_brick_inst.position = Vector3(0, 0.7, 0)
	damaged_node.add_child(d_brick_inst)
	
	# Chipped plaster upper section
	var d_plaster := BoxMesh.new()
	d_plaster.size = Vector3(2.9, 1.35, 2.9)
	d_plaster.material = Library.plaster()
	var d_plaster_inst := MeshInstance3D.new()
	d_plaster_inst.mesh = d_plaster
	d_plaster_inst.position = Vector3(0.05, 2.05, 0)
	damaged_node.add_child(d_plaster_inst)
	
	# Tilted, damaged roof slab
	var d_roof := BoxMesh.new()
	d_roof.size = Vector3(3.4, 0.4, 3.4)
	d_roof.material = Library.pavement()
	var d_roof_inst := MeshInstance3D.new()
	d_roof_inst.mesh = d_roof
	d_roof_inst.position = Vector3(0.1, 2.9, 0.05)
	d_roof_inst.rotation_degrees = Vector3(5.0, 2.0, -7.0)
	damaged_node.add_child(d_roof_inst)
	
	# Chipped fracture exposed on corner
	var crack_chunk := BoxMesh.new()
	crack_chunk.size = Vector3(0.8, 1.2, 0.8)
	crack_chunk.material = Library.debris_fracture()
	var crack_inst := MeshInstance3D.new()
	crack_inst.mesh = crack_chunk
	crack_inst.position = Vector3(1.3, 1.4, -1.3)
	crack_inst.rotation_degrees = Vector3(12, 25, -15)
	damaged_node.add_child(crack_inst)
	
	# -------------------------------------------------------------
	# 3. BROKEN STATE (Collapsed Rubble + Closed Interior Fracture Pieces)
	# -------------------------------------------------------------
	broken_node = Node3D.new()
	broken_node.name = "State_Broken"
	add_child(broken_node)
	
	# Core collapsed rubble mound (height 0.7m)
	var mound_mesh := BoxMesh.new()
	mound_mesh.size = Vector3(3.6, 0.65, 3.6)
	mound_mesh.material = Library.debris_fracture()
	var mound_inst := MeshInstance3D.new()
	mound_inst.mesh = mound_mesh
	mound_inst.position = Vector3(0, 0.32, 0)
	broken_node.add_child(mound_inst)
	
	# 4 Closed-Face Polyhedron Debris Pieces with shared fracture material
	var debris_configs := [
		# Piece 1: Fallen corner pillar
		{"size": Vector3(1.2, 0.6, 1.8), "pos": Vector3(-1.1, 0.45, -0.9), "rot": Vector3(10, 35, -12), "mat": Library.brick()},
		# Piece 2: Shattered roof slab segment
		{"size": Vector3(2.2, 0.35, 1.6), "pos": Vector3(0.8, 0.4, 0.7), "rot": Vector3(-8, 15, 18), "mat": Library.pavement()},
		# Piece 3: Plaster/brick rubble block
		{"size": Vector3(1.4, 0.5, 1.2), "pos": Vector3(-0.5, 0.55, 1.1), "rot": Vector3(22, -40, 5), "mat": Library.plaster()},
		# Piece 4: Dense internal fracture core chunk
		{"size": Vector3(1.0, 0.55, 1.0), "pos": Vector3(1.2, 0.38, -1.1), "rot": Vector3(-15, 60, -25), "mat": Library.debris_fracture()}
	]
	
	for i in debris_configs.size():
		var cfg = debris_configs[i]
		var chunk_mesh := BoxMesh.new()
		chunk_mesh.size = cfg["size"]
		# In closed-face debris pieces, faces are solid and fracture material coats edges
		chunk_mesh.material = cfg["mat"]
		var chunk_inst := MeshInstance3D.new()
		chunk_inst.name = "DebrisChunk_" + str(i)
		chunk_inst.mesh = chunk_mesh
		chunk_inst.position = cfg["pos"]
		chunk_inst.rotation_degrees = cfg["rot"]
		broken_node.add_child(chunk_inst)
		
		# Overlay fracture cap on top of chunk to ensure visible interior core
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(cfg["size"].x * 0.7, 0.15, cfg["size"].z * 0.7)
		cap_mesh.material = Library.debris_fracture()
		var cap_inst := MeshInstance3D.new()
		cap_inst.mesh = cap_mesh
		cap_inst.position = Vector3(0, cfg["size"].y * 0.45, 0)
		chunk_inst.add_child(cap_inst)

func set_state(new_state: State) -> void:
	current_state = new_state
	if not intact_node or not damaged_node or not broken_node:
		return
		
	intact_node.visible = (current_state == State.INTACT)
	damaged_node.visible = (current_state == State.DAMAGED)
	broken_node.visible = (current_state == State.BROKEN)
	
	# Adjust collision height to match visual destruction
	if current_state == State.BROKEN:
		box_shape.size = Vector3(3.6, 0.8, 3.6)
		col_shape.position = Vector3(0, 0.4, 0)
	else:
		box_shape.size = Vector3(3.0, 3.2, 3.0)
		col_shape.position = Vector3(0, 1.6, 0)

func advance_state() -> void:
	match current_state:
		State.INTACT:
			set_state(State.DAMAGED)
		State.DAMAGED:
			set_state(State.BROKEN)
		State.BROKEN:
			set_state(State.INTACT) # Loop back for testing
