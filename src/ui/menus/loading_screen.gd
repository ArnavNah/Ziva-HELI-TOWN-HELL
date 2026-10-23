class_name LoadingScreen
extends CanvasLayer

const AircraftSpecs = preload("res://data/aircraft_specs.gd")

## LoadingScreen — High-impact tactical military sortie deployment & asset streaming screen.
## Features real-time threaded loading, GPU pipeline warmup, animated 3D turntable staging,
## rotating mission intelligence SITREPs, and buttery-smooth continuous progress pacing.

enum Phase { IDLE, REQUESTING, RESOURCES, WORLD, REVEAL, FAILED }
var phase: Phase = Phase.IDLE
var target_scene_path: String = "res://scenes/main_game.tscn"
var selected_aircraft: String = "apache"
var displayed_progress: float = 0.0
var target_progress: float = 0.0
var min_duration: float = 0.2
var elapsed_time: float = 0.0
var transition_started: bool = false
var is_scene_swapped: bool = false
static var default_headless_duration: float = 0.0

var root_control: Control
var progress_label: Label
var progress_bar_fill: ProgressBar
var progress_bar_bg: Control
var status_badge: Label
var aircraft_title: Label
var terminal_log_label: Label
var preview_viewport: SubViewport
var preview_aircraft: Node3D
var preview_rotor: Node3D
var preview_tail_rotor: Node3D
var radar_widget: Control
var scanline_overlay: Control
var error_box: VBoxContainer
var retry_button: Button
var back_button: Button

# Tactical UI additions
var percent_readout: Label
var stage_track_label: Label
var theater_sublabel: Label
var helipad_mesh: MeshInstance3D
var helipad_ring: MeshInstance3D

var progress_arr: Array = []
var _attempt: int = 0
var _world_wait: float = 0.0
var _tip_timer: float = 0.0
var _tip_idx: int = 0
var _in_reveal: bool = false

var frame_max_ms: float = 0.0
var frames_animated: int = 0
var world_frames: int = 0
var world_max_ms: float = 0.0
var _last_frame_us: int = 0

const TACTICAL_TIPS: Array[String] = [
	"// TACTICAL INTEL: Anti-air missile locks can be defeated by deploying countermeasure flares [F / B].",
	"// FLIGHT ADVICE: Ascending clears building collisions, but higher altitudes burn turbine fuel faster.",
	"// AVIONICS NOTE: Hold [RMB / LT] to paint and lock up to 6 targets for high-explosive Hellfire salvos.",
	"// DAMAGE CONTROL: Airframe fire ignites below 30% hull. Seek extraction or immediate field repairs.",
	"// AIR DEFENSE: Ground radar flak batteries track incoming gunships. Utilize evasive barrel rolls [SPACE / RB].",
	"// RECON DISPATCH: Armored convoys and enemy siege walkers yield concentrated XP cores upon destruction."
]

const AIRCRAFT_SPECS := {
	"apache": {
		"name": "AH-64 APACHE",
		"role": "ALL-WEATHER ASSAULT GUNSHIP",
		"scale_mult": 0.38,
		"hull_tint": Color(0.82, 0.85, 0.80, 1.0),
		"canopy_color": Color(0.25, 0.85, 0.95, 1.0),
		"ordnance": "30mm M230 Chaingun + Hydra-70 HE Rockets"
	},
	"nighthawk": {
		"name": "RAH-66 NIGHTHAWK",
		"role": "STEALTH RECON & HIGH-SPEED INTERCEPTOR",
		"scale_mult": 0.35,
		"hull_tint": Color(0.40, 0.42, 0.46, 1.0),
		"canopy_color": Color(0.15, 0.90, 0.85, 1.0),
		"ordnance": "20mm Vulcan Cannon + Precision High-Velocity Rockets"
	},
	"warlock": {
		"name": "MI-28 WARLOCK",
		"role": "HEAVY ARMORED SIEGE GUNSHIP",
		"scale_mult": 0.42,
		"hull_tint": Color(0.60, 0.62, 0.65, 1.0),
		"canopy_color": Color(1.0, 0.45, 0.15, 1.0),
		"ordnance": "30mm Shipunov 2A42 + Fragmentation Rockets"
	}
}

func _init() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _ready() -> void:
	if not root_control:
		_build_ui()

func start_loading(path: String = "res://scenes/main_game.tscn", aircraft_id: String = "apache", duration_override: float = -1.0) -> void:
	if phase not in [Phase.IDLE, Phase.FAILED]:
		return
	_attempt += 1
	phase = Phase.REQUESTING
	target_scene_path = path
	selected_aircraft = aircraft_id
	elapsed_time = 0.0
	_world_wait = 0.0
	_tip_timer = 0.0
	_tip_idx = 0
	_in_reveal = false
	displayed_progress = 0.0
	target_progress = 0.05
	transition_started = false
	is_scene_swapped = false

	var is_headless: bool = DisplayServer.get_name() == "headless"
	min_duration = duration_override if duration_override >= 0 else (default_headless_duration if is_headless else 0.8)

	error_box.hide()

	# Seamless entry transition: fade in curtain smoothly in real gameplay
	if is_headless or duration_override == 0.0:
		root_control.modulate.a = 1.0
	else:
		root_control.modulate.a = 0.0
		var in_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		in_tween.tween_property(root_control, "modulate:a", 1.0, 0.20).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	_update_aircraft_presentation(aircraft_id)
	progress_label.text = "INITIALIZING AVIONICS & SORTIE PROTOCOLS..."
	terminal_log_label.text = TACTICAL_TIPS[_tip_idx]
	_update_stage_track(1)

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("ui_click")

	_request.call_deferred(_attempt)

func _request(attempt: int) -> void:
	if not _attempt_is_current(attempt):
		return
	await get_tree().process_frame
	if not _attempt_is_current(attempt):
		return
	await get_tree().process_frame
	if not _attempt_is_current(attempt):
		return
	if not ResourceLoader.exists(target_scene_path):
		_fail("The destination scene is missing. You can retry or return to the menu.")
		return
	var error := ResourceLoader.load_threaded_request(target_scene_path, "PackedScene")
	if error != OK:
		_fail("The scene could not be requested: " + error_string(error))
		return
	phase = Phase.RESOURCES

func _attempt_is_current(attempt: int) -> bool:
	return attempt == _attempt and is_inside_tree() and not is_queued_for_deletion()

func _exit_tree() -> void:
	_attempt += 1

func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.033)
	elapsed_time += delta
	frames_animated += 1
	var now := Time.get_ticks_usec()
	var wall_ms := float(now - _last_frame_us) / 1000.0 if _last_frame_us > 0 else 0.0
	_last_frame_us = now
	frame_max_ms = maxf(frame_max_ms, wall_ms)

	if phase == Phase.WORLD:
		world_frames += 1
		world_max_ms = maxf(world_max_ms, wall_ms)

	# Turntable & rotor motion with clamped delta (prevents frame spike jerks)
	if preview_aircraft:
		preview_aircraft.rotation.y += dt * 0.38
	if preview_rotor:
		preview_rotor.rotation.y += dt * 18.0
	if preview_tail_rotor:
		preview_tail_rotor.rotation.x += dt * 26.0

	# Tactical badge pulse
	if status_badge:
		status_badge.modulate.a = 0.78 + sin(elapsed_time * 4.5) * 0.22

	# Rotating Field Intel Carousel
	_tip_timer += delta
	if _tip_timer >= 3.5:
		_tip_timer = 0.0
		_tip_idx = (_tip_idx + 1) % TACTICAL_TIPS.size()
		if terminal_log_label:
			terminal_log_label.text = TACTICAL_TIPS[_tip_idx]

	match phase:
		Phase.RESOURCES:
			var status := ResourceLoader.load_threaded_get_status(target_scene_path, progress_arr)
			if status in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
				_fail("The scene or one of its resources could not be loaded.")
				return
			var ratio: float = float(progress_arr[0]) if not progress_arr.is_empty() else 0.0
			target_progress = clampf(lerpf(0.05, 0.50, ratio), 0.05, 0.50)
			progress_label.text = "STREAMING COMBAT ASSETS & GEOMETRY... %d%%" % int(displayed_progress * 100)
			_update_stage_track(2 if ratio > 0.3 else 1)
			if status == ResourceLoader.THREAD_LOAD_LOADED and elapsed_time >= min_duration:
				_swap_scene()

		Phase.WORLD:
			_world_wait += delta
			var scene := get_tree().current_scene
			var city = scene.get_node_or_null("CityGenerator") if scene else null
			var world_ratio: float = 0.0
			if city and "generation_ratio" in city:
				world_ratio = city.generation_ratio
			elif scene and "is_prepared" in scene and scene.is_prepared:
				world_ratio = 1.0
			target_progress = lerpf(0.50, 0.96, world_ratio)
			if city and "generation_stage" in city and city.generation_stage != "":
				progress_label.text = "%s... %d%%" % [city.generation_stage, int(displayed_progress * 100)]
			else:
				progress_label.text = "PREPARING URBAN SECTOR & SPATIAL GRID... %d%%" % int(displayed_progress * 100)
			_update_stage_track(3)
			if scene and "is_prepared" in scene and scene.is_prepared:
				target_progress = 1.0
				_update_stage_track(4)
				if displayed_progress >= 0.92 or DisplayServer.get_name() == "headless":
					_reveal(scene)
			elif scene and not scene.has_method("activate_session"):
				_fail("The destination does not provide a gameplay readiness handoff.")
			elif _world_wait > 45.0:
				_fail("World preparation timed out. Please retry or return to the menu.")

		Phase.REVEAL:
			target_progress = 1.0
			_update_stage_track(4)

	# Continuous, buttery-smooth progress interpolation (zero jumping or freezing)
	if DisplayServer.get_name() == "headless":
		displayed_progress = target_progress
	else:
		var sc := get_tree().current_scene
		var is_prep = (sc and "is_prepared" in sc and sc.is_prepared)
		var p_rate = 3.8 if is_prep else 1.8
		displayed_progress = move_toward(displayed_progress, target_progress, dt * p_rate)

	progress_bar_fill.value = displayed_progress * 100.0
	if percent_readout:
		percent_readout.text = "[ %02d%% ]" % int(displayed_progress * 100.0)

func _swap_scene() -> void:
	if transition_started:
		return
	transition_started = true
	var scene = ResourceLoader.load_threaded_get(target_scene_path)
	if not scene is PackedScene:
		_fail("The loaded resource is not a playable scene.")
		return
	var error := get_tree().change_scene_to_packed(scene)
	if error != OK:
		_fail("The scene could not be opened: " + error_string(error))
		return
	is_scene_swapped = true
	phase = Phase.WORLD
	target_progress = maxf(target_progress, 0.50)

func _reveal(scene: Node) -> void:
	if _in_reveal:
		return
	_in_reveal = true
	var attempt := _attempt
	phase = Phase.REVEAL
	target_progress = 1.0
	displayed_progress = 1.0
	progress_label.text = "SORTIE DEPLOYMENT AUTHORIZED — ALL SYSTEMS GO"
	if percent_readout:
		percent_readout.text = "[ 100% ]"
	_update_stage_track(4)

	var is_headless: bool = DisplayServer.get_name() == "headless"
	if not is_headless:
		# Give GPU 2 frames to warm up viewport, terrain shaders, and camera before dropping curtain
		await get_tree().process_frame
		if attempt != _attempt or not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(scene) or scene.is_queued_for_deletion():
			return
		await RenderingServer.frame_post_draw
		if attempt != _attempt or not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(scene) or scene.is_queued_for_deletion():
			return

	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var fade_dur: float = 0.0 if is_headless else 0.35
	tween.tween_property(root_control, "modulate:a", 0.0, fade_dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func():
		if _attempt_is_current(attempt) and is_instance_valid(scene) and not scene.is_queued_for_deletion() and get_tree().current_scene == scene:
			get_node("/root/UIFlow").finish_loading(scene)
		queue_free()
	)

func _fail(message: String) -> void:
	phase = Phase.FAILED
	progress_label.text = message
	status_badge.text = "DEPLOYMENT INTERRUPTED"
	status_badge.add_theme_color_override("font_color", Color("ff5252"))
	error_box.show()
	retry_button.grab_focus()

func _retry() -> void:
	if phase != Phase.FAILED:
		return
	status_badge.text = "● SORTIE DEPLOYMENT PROTOCOL"
	status_badge.add_theme_color_override("font_color", Color("ffd275"))
	start_loading(target_scene_path, selected_aircraft)

func _back() -> void:
	_attempt += 1
	get_node("/root/UIFlow").return_to_menu()

func _input(event: InputEvent) -> void:
	if phase == Phase.FAILED:
		if event.is_action_pressed("ui_cancel"):
			_back()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()

func _update_aircraft_presentation(aircraft_id: String) -> void:
	var specs: Dictionary = AircraftSpecs.get_specs(aircraft_id)
	var live_stats: Dictionary = {}
	if has_node("/root/ProfileManager"):
		live_stats = get_node("/root/ProfileManager").preview_stats(aircraft_id)

	var spd: float = live_stats.get("speed", 36.0)
	var hl: float = live_stats.get("hull", 100.0)
	var fl: float = live_stats.get("fuel", 100.0)

	aircraft_title.text = "%s   [%s]\nSPEED: %.1f m/s   |   HULL: %.0f HP   |   FUEL: %.0f L   |   %s" % [
		specs["name"], specs["role"], spd, hl, fl, specs.get("tagline", "COMBAT READY")
	]

	if preview_aircraft and preview_aircraft.get_child_count() > 0:
		var visual := preview_aircraft.get_child(0) as Node3D
		if is_instance_valid(visual):
			var scale_mult: float = specs.get("preview_scale", 0.38)
			visual.scale = Vector3.ONE * scale_mult
			visual.position = Vector3(0, 0.05 + 2.20 * scale_mult, 0)
			AircraftSpecs.configure_airframe_visuals(visual, aircraft_id, true)

func _update_stage_track(active_stage: int) -> void:
	if not stage_track_label:
		return
	var stages := [
		" [1] AVIONICS ",
		" [2] WEAPON PODS ",
		" [3] THEATER GRID ",
		" [4] SORTIE READY "
	]
	var formatted := ""
	for i in range(stages.size()):
		var st_num := i + 1
		if st_num == active_stage:
			formatted += "●" + stages[i]
		elif st_num < active_stage:
			formatted += "✔" + stages[i]
		else:
			formatted += "○" + stages[i]
		if i < stages.size() - 1:
			formatted += " >> "
	stage_track_label.text = formatted

func _build_ui() -> void:
	root_control = Control.new()
	root_control.name = "LoadingRoot"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)

	# Deep tactical military slate-navy background
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color("080f14")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(background)

	# CRT Scanline & Tactical Framing Overlay
	var tactical_overlay := TacticalOverlay.new()
	tactical_overlay.name = "TacticalOverlay"
	tactical_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tactical_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(tactical_overlay)
	radar_widget = tactical_overlay
	scanline_overlay = tactical_overlay

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	root_control.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	# 1. Header Bar: Status Badge + Theater Sector
	var header_hbox := HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var header_left := VBoxContainer.new()
	header_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_left)

	status_badge = Label.new()
	status_badge.text = "● SORTIE DEPLOYMENT PROTOCOL"
	status_badge.add_theme_color_override("font_color", Color("ffd275"))
	status_badge.add_theme_font_override("font", preload("res://src/effects/floating_text.gd").get_pixel_font())
	status_badge.add_theme_font_size_override("font_size", 20)
	header_left.add_child(status_badge)

	theater_sublabel = Label.new()
	theater_sublabel.text = "THEATER: SECTOR 04 // TOWN HELL [STRIKE MEADOW]   |   THREAT: HOSTILE SIEGE"
	theater_sublabel.add_theme_color_override("font_color", Color("00e5ff"))
	theater_sublabel.add_theme_font_size_override("font_size", 12)
	header_left.add_child(theater_sublabel)

	var header_right := Label.new()
	header_right.text = "SYS.OP // 60 FPS // AIRFRAME SORTIE"
	header_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_right.add_theme_color_override("font_color", Color("5c7d8a"))
	header_right.add_theme_font_size_override("font_size", 12)
	header_hbox.add_child(header_right)

	# 2. Airframe Dossier Card
	var dossier_panel := PanelContainer.new()
	var dossier_style := StyleBoxFlat.new()
	dossier_style.bg_color = Color(0.05, 0.10, 0.14, 0.85)
	dossier_style.border_color = Color(0.18, 0.38, 0.46, 0.70)
	dossier_style.set_border_width_all(1)
	dossier_style.set_corner_radius_all(3)
	dossier_style.content_margin_left = 16
	dossier_style.content_margin_right = 16
	dossier_style.content_margin_top = 8
	dossier_style.content_margin_bottom = 8
	dossier_panel.add_theme_stylebox_override("panel", dossier_style)
	main_vbox.add_child(dossier_panel)

	aircraft_title = Label.new()
	aircraft_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aircraft_title.add_theme_font_size_override("font_size", 13)
	aircraft_title.add_theme_color_override("font_color", Color("d8f3dc"))
	dossier_panel.add_child(aircraft_title)

	# 3. 3D Turntable Showcase Stage
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size.y = 200
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(container)

	preview_viewport = SubViewport.new()
	preview_viewport.own_world_3d = true
	preview_viewport.size = Vector2i(720, 320)
	preview_viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(preview_viewport)
	_setup_preview()

	# 4. Tactical Field Intel / SITREP Carousel
	var intel_panel := PanelContainer.new()
	var intel_style := StyleBoxFlat.new()
	intel_style.bg_color = Color(0.04, 0.08, 0.12, 0.75)
	intel_style.border_color = Color(0.15, 0.30, 0.38, 0.60)
	intel_style.set_border_width_all(1)
	intel_style.set_corner_radius_all(3)
	intel_style.content_margin_left = 16
	intel_style.content_margin_right = 16
	intel_style.content_margin_top = 6
	intel_style.content_margin_bottom = 6
	intel_panel.add_theme_stylebox_override("panel", intel_style)
	main_vbox.add_child(intel_panel)

	terminal_log_label = Label.new()
	terminal_log_label.name = "TerminalLogLabel"
	terminal_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	terminal_log_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	terminal_log_label.add_theme_font_size_override("font_size", 12)
	terminal_log_label.add_theme_color_override("font_color", Color("8ecae6"))
	intel_panel.add_child(terminal_log_label)

	# 5. Deployment Step Track
	stage_track_label = Label.new()
	stage_track_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_track_label.add_theme_font_size_override("font_size", 11)
	stage_track_label.add_theme_color_override("font_color", Color("ffb703"))
	main_vbox.add_child(stage_track_label)
	_update_stage_track(1)

	# 6. High-Tech Glowing Progress Bar & Status Text
	var progress_header_hbox := HBoxContainer.new()
	main_vbox.add_child(progress_header_hbox)

	progress_label = Label.new()
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_label.add_theme_font_size_override("font_size", 13)
	progress_label.add_theme_color_override("font_color", Color("e0fbfc"))
	progress_header_hbox.add_child(progress_label)

	percent_readout = Label.new()
	percent_readout.text = "[ 00% ]"
	percent_readout.add_theme_font_override("font", preload("res://src/effects/floating_text.gd").get_pixel_font())
	percent_readout.add_theme_font_size_override("font_size", 14)
	percent_readout.add_theme_color_override("font_color", Color("ffd700"))
	progress_header_hbox.add_child(percent_readout)

	progress_bar_fill = ProgressBar.new()
	progress_bar_fill.custom_minimum_size.y = 16
	progress_bar_fill.show_percentage = false

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("0a141b")
	bar_bg.border_color = Color("1e3d48")
	bar_bg.set_border_width_all(1)
	bar_bg.set_corner_radius_all(2)
	progress_bar_fill.add_theme_stylebox_override("background", bar_bg)

	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = Color("00c3ff")
	bar_fg.border_color = Color("80edff")
	bar_fg.set_border_width_all(1)
	bar_fg.set_corner_radius_all(2)
	progress_bar_fill.add_theme_stylebox_override("fill", bar_fg)

	main_vbox.add_child(progress_bar_fill)
	progress_bar_bg = progress_bar_fill

	# 7. Error / Failure UI Box
	error_box = VBoxContainer.new()
	error_box.add_theme_constant_override("separation", 8)
	main_vbox.add_child(error_box)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 16)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	error_box.add_child(btn_hbox)

	retry_button = Button.new()
	retry_button.text = "RETRY SORTIE"
	retry_button.custom_minimum_size = Vector2(160, 36)
	retry_button.pressed.connect(_retry)
	btn_hbox.add_child(retry_button)

	back_button = Button.new()
	back_button.text = "RETURN TO BASE"
	back_button.custom_minimum_size = Vector2(160, 36)
	back_button.pressed.connect(_back)
	btn_hbox.add_child(back_button)

	error_box.hide()

func _setup_preview() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("070d12")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("40606e")
	env.ambient_light_energy = 0.8
	environment.environment = env
	preview_viewport.add_child(environment)

	# Helipad Pedestal Deck
	helipad_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 4.0
	cyl.bottom_radius = 4.2
	cyl.height = 0.10
	helipad_mesh.mesh = cyl
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color("0e1820")
	pad_mat.roughness = 0.85
	helipad_mesh.material_override = pad_mat
	preview_viewport.add_child(helipad_mesh)

	# Glowing Perimeter Landing Ring
	helipad_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.85
	torus.outer_radius = 3.96
	helipad_ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color("00e5ff")
	ring_mat.emission_enabled = true
	ring_mat.emission = Color("00e5ff")
	ring_mat.emission_energy_multiplier = 1.6
	helipad_ring.material_override = ring_mat
	helipad_ring.position.y = 0.05
	preview_viewport.add_child(helipad_ring)

	preview_aircraft = Node3D.new()
	preview_viewport.add_child(preview_aircraft)

	# Multi-point studio lighting
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_color = Color("fff5ea")
	sun.light_energy = 1.3
	preview_viewport.add_child(sun)

	var rim_light := DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(15, 145, 0)
	rim_light.light_color = Color("00e5ff")
	rim_light.light_energy = 0.75
	preview_viewport.add_child(rim_light)

	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 5.0, 0)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	spot.spot_range = 10.0
	spot.spot_angle = 45.0
	spot.light_color = Color("ffe5a0")
	spot.light_energy = 0.6
	preview_viewport.add_child(spot)

	var camera := Camera3D.new()
	camera.look_at_from_position(Vector3(6.5, 3.8, 8.2), Vector3(0, 0.7, 0))
	camera.fov = 34.0
	camera.current = true
	preview_viewport.add_child(camera)

	# Load verified player airframe visuals
	var visual: Node3D = null
	var scene = get_tree().current_scene if is_inside_tree() and get_tree() else null
	if scene:
		var selection = scene.get_node_or_null("VehicleSelectionMenu")
		if selection and is_instance_valid(selection.heli_model):
			visual = selection.heli_model.duplicate()
		elif "player" in scene and is_instance_valid(scene.player):
			var p_vis = scene.player.get_node_or_null("Visuals")
			if p_vis:
				visual = p_vis.duplicate()

	if not visual:
		var p_res = load("res://scenes/player/player.tscn")
		if p_res:
			var temp_p = p_res.instantiate()
			var p_vis = temp_p.get_node_or_null("Visuals")
			if p_vis:
				visual = p_vis.duplicate()
			temp_p.free()

	if visual:
		visual.position = Vector3(0, 0.88, 0)
		visual.rotation = Vector3(0, deg_to_rad(140.0), 0)
		visual.scale = Vector3.ONE * 0.38
		visual.visible = true

		# Center Apache bounding box
		var apache_inner = visual.find_child("ApacheModel", true, false)
		if apache_inner:
			apache_inner.position.z -= 1.005

		preview_aircraft.add_child(visual)

		for particles in visual.find_children("*", "CPUParticles3D", true, false):
			particles.emitting = false
		for light in visual.find_children("*", "Light3D", true, false):
			light.visible = false

		preview_rotor = visual.find_child("Main_Rotor", true, false)
		if not preview_rotor:
			preview_rotor = visual.get_node_or_null("MainRotor")
		if not preview_rotor:
			preview_rotor = Node3D.new()
			visual.add_child(preview_rotor)

		preview_tail_rotor = visual.find_child("Tail_Rotor", true, false)
		if not preview_tail_rotor:
			preview_tail_rotor = visual.get_node_or_null("TailRotor")
	else:
		preload("res://src/enemies/raider_visuals.gd").build(preview_aircraft, "attack_gunship")
		preview_rotor = preview_aircraft.find_child("AnimatedRotor", true, false)
		if not preview_rotor:
			preview_rotor = preview_aircraft.find_child("Main_Rotor", true, false)

## TacticalOverlay — Canvas overlay rendering cyber-military corner brackets and framing
class TacticalOverlay extends Control:
	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var cyan_dim := Color(0.0, 0.9, 1.0, 0.25)
		var cyan_bright := Color(0.0, 0.9, 1.0, 0.65)
		var b_len: float = 24.0
		var m: float = 16.0

		# Corner brackets
		# Top-Left
		draw_line(Vector2(m, m), Vector2(m + b_len, m), cyan_bright, 2.0)
		draw_line(Vector2(m, m), Vector2(m, m + b_len), cyan_bright, 2.0)
		# Top-Right
		draw_line(Vector2(w - m, m), Vector2(w - m - b_len, m), cyan_bright, 2.0)
		draw_line(Vector2(w - m, m), Vector2(w - m, m + b_len), cyan_bright, 2.0)
		# Bottom-Left
		draw_line(Vector2(m, h - m), Vector2(m + b_len, h - m), cyan_bright, 2.0)
		draw_line(Vector2(m, h - m), Vector2(m, h - m - b_len), cyan_bright, 2.0)
		# Bottom-Right
		draw_line(Vector2(w - m, h - m), Vector2(w - m - b_len, h - m), cyan_bright, 2.0)
		draw_line(Vector2(w - m, h - m), Vector2(w - m, h - m - b_len), cyan_bright, 2.0)

		# Subtle horizontal framing ticks
		draw_line(Vector2(w * 0.5 - 50, m), Vector2(w * 0.5 + 50, m), cyan_dim, 1.0)
		draw_line(Vector2(w * 0.5 - 50, h - m), Vector2(w * 0.5 + 50, h - m), cyan_dim, 1.0)
