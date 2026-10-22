class_name ArtTestStreet
extends Node3D

## ArtTestStreet — Playable test scene for validating the modern-retro art style.
## Includes:
## 1. Modular building (warm brick lower, pale plaster upper, windows, parapet)
## 2. Road (asphalt with low-contrast lane markings) and pavement sidewalk with curbs
## 3. Grass and rich soil transition patch
## 4. Stylized low-poly tree (bark trunk + alpha-scissor foliage cards)
## 5. Props: supply crate and hazardous fuel barrel
## 6. Destructible guard booth with matching intact/damaged/broken states and closed fracture debris
## 7. Readability proxies: enemy combat vehicle and glowing tactical pickup
## 8. Dual-camera comparison: Elevated 3/4 Third-Person vs Higher Top-Down View

const PropBuilder = preload("res://src/world/art_test_prop_builder.gd")
const BoothScript = preload("res://src/world/art_test_destructible_booth.gd")

enum CameraMode {
	ELEVATED_THIRD_PERSON = 0,
	TACTICAL_TOP_DOWN = 1
}

var current_camera_mode: CameraMode = CameraMode.ELEVATED_THIRD_PERSON

@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var camera_rig: Node3D = $CameraRig
var booth: Node3D = null

# Camera Targets
const CAM_CONFIGS := {
	CameraMode.ELEVATED_THIRD_PERSON: {
		"offset": Vector3(0.0, 22.0, 24.0),
		"pitch_deg": -42.0,
		"fov": 52.0,
		"name": "Elevated 3/4 Third-Person"
	},
	CameraMode.TACTICAL_TOP_DOWN: {
		"offset": Vector3(0.0, 36.0, 8.0),
		"pitch_deg": -75.0,
		"fov": 48.0,
		"name": "Higher Tactical Top-Down"
	}
}

var target_cam_offset: Vector3 = Vector3(0.0, 22.0, 24.0)
var target_pitch: float = -42.0
var target_fov: float = 52.0
var rig_center: Vector3 = Vector3(0, 0, 0)
var pan_speed: float = 18.0

# UI Labels
var ui_camera_label: Label
var ui_booth_label: Label

func _ready() -> void:
	_setup_lighting_and_environment()
	_populate_test_street()
	_setup_camera()
	_setup_ui()
	set_camera_mode(current_camera_mode, true)

func _setup_lighting_and_environment() -> void:
	# Directional Sun Light (broad shadows preserving pixel art)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-48.0, 38.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.98, 0.94)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	add_child(sun)
	
	# WorldEnvironment with restrained distance fog & matte sky
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.68, 0.74, 0.80)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.52, 0.56)
	env.ambient_light_energy = 0.75
	
	# Single distance fog system (restrained, no conflicting fog passes)
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.74, 0.80)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.3
	world_env.environment = env
	add_child(world_env)

func _populate_test_street() -> void:
	# 1. Base Environment: Road, Sidewalks, Grass/Soil Lot
	var street_env = PropBuilder.build_street_environment()
	add_child(street_env)
	
	# 2. Modular Building (East side, facing street)
	var building = PropBuilder.build_modular_building()
	building.position = Vector3(12.0, 0.0, -4.0)
	building.rotation_degrees = Vector3(0, -90, 0) # Facade faces West to road
	add_child(building)
	
	# 3. Stylized Low-Poly Tree (West grass patch)
	var tree = PropBuilder.build_tree()
	tree.position = Vector3(-11.0, 0.0, -3.0)
	add_child(tree)
	
	# 4. Props: Supply Crate & Fuel Barrel (East sidewalk edge)
	var crate = PropBuilder.build_crate(Vector3(6.2, 0.0, 4.5))
	add_child(crate)
	
	var barrel = PropBuilder.build_barrel(Vector3(6.2, 0.0, 7.0))
	add_child(barrel)
	
	# 5. Destructible Guard Booth Prop (West curb checkpoint)
	booth = PropBuilder.build_destructible_booth(Vector3(-5.5, 0.0, 7.5))
	add_child(booth)
	
	# 6. Readability Proxies: Enemy Vehicle & Interactive Pickup
	var enemy = PropBuilder.build_enemy_proxy(Vector3(1.8, 0.0, -8.0))
	add_child(enemy)
	
	var pickup = PropBuilder.build_pickup_proxy(Vector3(-1.8, 0.8, 3.0))
	add_child(pickup)

func _setup_camera() -> void:
	if not camera_rig:
		camera_rig = Node3D.new()
		camera_rig.name = "CameraRig"
		add_child(camera_rig)
		
	if not camera:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera.current = true
		camera_rig.add_child(camera)

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)
	
	var panel := PanelContainer.new()
	panel.offset_left = 20
	panel.offset_top = 20
	panel.offset_right = 520
	panel.offset_bottom = 220
	canvas.add_child(panel)
	
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	
	var title := Label.new()
	title.text = "NUCLEAR STRIKE — MODERN-RETRO ART TEST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var separator := HSeparator.new()
	vbox.add_child(separator)
	
	ui_camera_label = Label.new()
	vbox.add_child(ui_camera_label)
	
	ui_booth_label = Label.new()
	vbox.add_child(ui_booth_label)
	
	var density_label := Label.new()
	density_label.text = "Scale Standard: 64 px/meter (128px=2m, 256px=4m)"
	vbox.add_child(density_label)
	
	var guide := Label.new()
	guide.text = "Controls: [V] Toggle Camera | [E] Cycle Booth Destruction | [WASD] Pan | [Space] Reset"
	guide.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	vbox.add_child(guide)
	
	_update_ui_labels()

func _update_ui_labels() -> void:
	if ui_camera_label:
		var cfg = CAM_CONFIGS[current_camera_mode]
		ui_camera_label.text = "Camera: " + cfg["name"] + " (Press [V])"
	if ui_booth_label and booth:
		var state_str := "INTACT"
		match booth.current_state:
			BoothScript.State.INTACT: state_str = "INTACT"
			BoothScript.State.DAMAGED: state_str = "DAMAGED"
			BoothScript.State.BROKEN: state_str = "BROKEN (Collapsed with closed fracture faces)"
		ui_booth_label.text = "Booth State: " + state_str + " (Press [E])"

func set_camera_mode(mode: CameraMode, instant: bool = false) -> void:
	current_camera_mode = mode
	var cfg = CAM_CONFIGS[current_camera_mode]
	target_cam_offset = cfg["offset"]
	target_pitch = cfg["pitch_deg"]
	target_fov = cfg["fov"]
	
	if instant and camera:
		camera.position = target_cam_offset
		camera.rotation_degrees = Vector3(target_pitch, 0, 0)
		camera.fov = target_fov
		
	_update_ui_labels()

func toggle_camera_mode() -> void:
	var next_mode = CameraMode.TACTICAL_TOP_DOWN if current_camera_mode == CameraMode.ELEVATED_THIRD_PERSON else CameraMode.ELEVATED_THIRD_PERSON
	set_camera_mode(next_mode, false)

func trigger_booth_destruction() -> void:
	if booth:
		booth.advance_state()
		_update_ui_labels()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			toggle_camera_mode()
		elif event.keycode == KEY_E:
			trigger_booth_destruction()
		elif event.keycode == KEY_SPACE:
			rig_center = Vector3.ZERO
			set_camera_mode(CameraMode.ELEVATED_THIRD_PERSON, true)

func _process(delta: float) -> void:
	# Pan rig with WASD or arrow keys
	var move_input := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_input.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_input.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_input.x += 1.0
		
	if move_input != Vector3.ZERO:
		rig_center += move_input.normalized() * pan_speed * delta
		
	# Smoothly update camera rig position & camera transform
	camera_rig.position = camera_rig.position.lerp(rig_center, delta * 10.0)
	
	if camera:
		camera.position = camera.position.lerp(target_cam_offset, delta * 6.0)
		camera.rotation_degrees.x = lerpf(camera.rotation_degrees.x, target_pitch, delta * 6.0)
		camera.fov = lerpf(camera.fov, target_fov, delta * 6.0)
