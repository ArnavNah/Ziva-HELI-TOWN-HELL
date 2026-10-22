class_name FlightAcademy
extends Node3D

## FlightAcademy — Interactive training proving ground (Page 3 & 4).
## Guides pilot through takeoff, waypoint rings, target practice, flare defense, and cargo sling.

enum TutorialStep {
	TAKEOFF = 0,
	WAYPOINTS = 1,
	TARGET_PRACTICE = 2,
	FLARE_DEFENSE = 3,
	CARGO_DELIVERY = 4,
	GRADUATED = 5
}

var current_step: TutorialStep = TutorialStep.TAKEOFF
var waypoints_cleared: int = 0
const TOTAL_WAYPOINTS: int = 3
var dummies_destroyed: int = 0
const TOTAL_DUMMIES: int = 2
var flare_defended: bool = false
var cargo_loaded: bool = false
var cargo_delivered: bool = false

# UI Elements
@onready var hud_layer: CanvasLayer = $TutorialHUD
@onready var title_label: Label = $TutorialHUD/Panel/VBox/TitleLabel
@onready var step_label: Label = $TutorialHUD/Panel/VBox/StepLabel
@onready var progress_bar: ProgressBar = $TutorialHUD/Panel/VBox/ProgressBar
@onready var finish_btn: Button = $TutorialHUD/Panel/VBox/FinishBtn

# World Elements
@onready var player: PlayerHelicopter = $PlayerHelicopter
@onready var ring1: Area3D = $Waypoints/Ring1
@onready var ring2: Area3D = $Waypoints/Ring2
@onready var ring3: Area3D = $Waypoints/Ring3

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_ui()
	_setup_rings()
	_connect_event_bus()
	_update_step_ui()

func _setup_ui() -> void:
	if finish_btn:
		finish_btn.visible = false
		finish_btn.pressed.connect(_on_finish_pressed)

func _setup_rings() -> void:
	if ring1: ring1.body_entered.connect(func(b): _on_ring_passed(1, b))
	if ring2: ring2.body_entered.connect(func(b): _on_ring_passed(2, b))
	if ring3: ring3.body_entered.connect(func(b): _on_ring_passed(3, b))

func _connect_event_bus() -> void:
	if has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		bus.entity_destroyed.connect(_on_entity_destroyed)
		bus.flares_deployed.connect(_on_flares_deployed)

func _process(_delta: float) -> void:
	match current_step:
		TutorialStep.TAKEOFF:
			if player and player.global_position.y >= 18.0:
				current_step = TutorialStep.WAYPOINTS
				_update_step_ui()
				if has_node("/root/AudioManager"):
					get_node("/root/AudioManager").play_sfx("pickup")

		TutorialStep.WAYPOINTS:
			if waypoints_cleared >= TOTAL_WAYPOINTS:
				current_step = TutorialStep.TARGET_PRACTICE
				_spawn_target_dummies()
				_update_step_ui()
				if has_node("/root/AudioManager"):
					get_node("/root/AudioManager").play_sfx("pickup")

		TutorialStep.TARGET_PRACTICE:
			if dummies_destroyed >= TOTAL_DUMMIES:
				current_step = TutorialStep.FLARE_DEFENSE
				_spawn_incoming_training_missile()
				_update_step_ui()
				if has_node("/root/AudioManager"):
					get_node("/root/AudioManager").play_sfx("pickup")

		TutorialStep.FLARE_DEFENSE:
			if flare_defended:
				current_step = TutorialStep.CARGO_DELIVERY
				_setup_cargo_pads()
				_update_step_ui()
				if has_node("/root/AudioManager"):
					get_node("/root/AudioManager").play_sfx("pickup")

		TutorialStep.CARGO_DELIVERY:
			_process_cargo_step()

func _update_step_ui() -> void:
	if not title_label or not step_label or not progress_bar:
		return

	match current_step:
		TutorialStep.TAKEOFF:
			title_label.text = "FLIGHT CERTIFICATION — STEP 1 / 5"
			step_label.text = "COLLECTIVE LIFT: Press Space or Shift to climb to altitude >= 18.0m"
			progress_bar.max_value = 18.0
			var curr_alt = player.global_position.y if player else 0.0
			progress_bar.value = curr_alt

		TutorialStep.WAYPOINTS:
			title_label.text = "FLIGHT CERTIFICATION — STEP 2 / 5"
			step_label.text = "CYCLIC NAVIGATION: Fly through 3 aerial tactical waypoint rings"
			progress_bar.max_value = TOTAL_WAYPOINTS
			progress_bar.value = waypoints_cleared

		TutorialStep.TARGET_PRACTICE:
			title_label.text = "FLIGHT CERTIFICATION — STEP 3 / 5"
			step_label.text = "CHIN TURRET ENGAGEMENT: Aim with mouse and destroy Ground & Air Target Dummies (LMB / J)"
			progress_bar.max_value = TOTAL_DUMMIES
			progress_bar.value = dummies_destroyed

		TutorialStep.FLARE_DEFENSE:
			title_label.text = "FLIGHT CERTIFICATION — STEP 4 / 5"
			step_label.text = "MISSILE DEFENSE: Warning! Incoming rocket detected. Press F or C to deploy flares!"
			progress_bar.max_value = 1.0
			progress_bar.value = 1.0 if flare_defended else 0.0

		TutorialStep.CARGO_DELIVERY:
			title_label.text = "FLIGHT CERTIFICATION — STEP 5 / 5"
			if not cargo_loaded:
				step_label.text = "CARGO SLING: Hover over Helipad Alpha (within 18m) to load medical container"
				progress_bar.max_value = 2.0
				progress_bar.value = 0.0
			else:
				step_label.text = "CARGO TRANSIT: Deliver container to Helipad Bravo (Yellow Marker)"
				progress_bar.max_value = 2.0
				progress_bar.value = 1.0

		TutorialStep.GRADUATED:
			title_label.text = "★ FLIGHT CERTIFICATION APPROVED ★"
			step_label.text = "Congratulations! You have completed Flight Academy training.\n+100 Starter Combat Credits awarded to your pilot profile!"
			progress_bar.max_value = 1.0
			progress_bar.value = 1.0
			if finish_btn:
				finish_btn.visible = true

func _on_ring_passed(ring_id: int, body: Node) -> void:
	if current_step != TutorialStep.WAYPOINTS or body != player:
		return
	waypoints_cleared += 1
	var r_node = get_node_or_null("Waypoints/Ring%d" % ring_id)
	if r_node:
		r_node.queue_free()
	_update_step_ui()

func _spawn_target_dummies() -> void:
	var dummy_ground = StaticBody3D.new()
	dummy_ground.name = "TargetDummy_Ground"
	dummy_ground.global_position = Vector3(0, 1, -45)
	dummy_ground.collision_layer = 4
	dummy_ground.collision_mask = 3
	dummy_ground.add_to_group("enemies")

	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(4, 2, 4)
	col.shape = box
	dummy_ground.add_child(col)

	var mesh = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(4, 2, 4)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 0.2)
	b_mesh.material = mat
	mesh.mesh = b_mesh
	dummy_ground.add_child(mesh)

	var recv = load("res://src/combat/damage_receiver.gd").new()
	recv.max_health = 60.0
	recv.current_health = 60.0
	dummy_ground.add_child(recv)
	add_child(dummy_ground)

	# Aerial target dummy
	var dummy_air = StaticBody3D.new()
	dummy_air.name = "TargetDummy_Air"
	dummy_air.global_position = Vector3(25, 22, -40)
	dummy_air.collision_layer = 4
	dummy_air.collision_mask = 3
	dummy_air.add_to_group("enemies")

	var col_air = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 2.0
	col_air.shape = sphere
	dummy_air.add_child(col_air)

	var mesh_air = MeshInstance3D.new()
	var s_mesh = SphereMesh.new()
	s_mesh.radius = 2.0
	s_mesh.height = 4.0
	var mat_air = StandardMaterial3D.new()
	mat_air.albedo_color = Color(0.9, 0.6, 0.1)
	s_mesh.material = mat_air
	mesh_air.mesh = s_mesh
	dummy_air.add_child(mesh_air)

	var recv_air = load("res://src/combat/damage_receiver.gd").new()
	recv_air.max_health = 45.0
	recv_air.current_health = 45.0
	dummy_air.add_child(recv_air)
	add_child(dummy_air)

func _spawn_incoming_training_missile() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").trigger_alarm("sam_lock")

func _on_entity_destroyed(entity: Node, _killer: String, _score: int, _xp: int) -> void:
	if current_step == TutorialStep.TARGET_PRACTICE and is_instance_valid(entity):
		if entity.name.begins_with("TargetDummy"):
			dummies_destroyed += 1
			_update_step_ui()

func _on_flares_deployed(_charges: int) -> void:
	if current_step == TutorialStep.FLARE_DEFENSE:
		flare_defended = true
		_update_step_ui()

func _setup_cargo_pads() -> void:
	pass

func _process_cargo_step() -> void:
	if not player:
		return
	var pad_a = Vector2(0, 0)
	var pad_b = Vector2(60, -60)
	var p_horiz = Vector2(player.global_position.x, player.global_position.z)

	if not cargo_loaded:
		if p_horiz.distance_to(pad_a) <= 18.0 and player.global_position.y <= 12.0:
			cargo_loaded = true
			_update_step_ui()
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("pickup")
	else:
		if p_horiz.distance_to(pad_b) <= 20.0 and player.global_position.y <= 12.0:
			cargo_delivered = true
			current_step = TutorialStep.GRADUATED
			_graduate_pilot()
			_update_step_ui()
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("level_up")

func _graduate_pilot() -> void:
	if has_node("/root/ProfileManager"):
		var pm = get_node("/root/ProfileManager")
		pm.wallet_credits += 100
		pm.save_profile()

func _on_finish_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
