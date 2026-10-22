class_name VehicleSelectionMenu
extends Control

## VehicleSelectionMenu — Professional retro military hangar interface.
## Features a dedicated 3D turntable showcase with isolated viewport, truthful shared
## performance stats, authentic loadout matrix, and responsive layout across all resolutions.

signal vehicle_selected(aircraft_id: String)
signal returned_to_menu()

const Specs = preload("res://data/aircraft_specs.gd")
const GameConst = preload("res://data/game_constants.gd")
const HangarScript = preload("res://src/ui/menus/hangar_menu.gd")

# Expose backwards-compatible AIRCRAFT_ROSTER derived authoritatively from AircraftSpecs
static var AIRCRAFT_ROSTER: Array[Dictionary] = [
	Specs.AIRCRAFT["apache"],
	Specs.AIRCRAFT["nighthawk"],
	Specs.AIRCRAFT["warlock"]
]

var current_aircraft_idx: int = 0
var is_dragging: bool = false
var drag_start_x: float = 0.0
var rot_velocity: float = 0.0
var is_deploying: bool = false
var _selection_tween: Tween

# 3D Showcase Nodes
var stage_container: SubViewportContainer
var stage_viewport: SubViewport
var stage_camera: Camera3D
var turntable_root: Node3D
var heli_model: Node3D
var main_rotor_mesh: Node3D
var tail_rotor_mesh: Node3D
var pedestal_ring: MeshInstance3D

# UI Nodes
var wallet_label: Label
var salvage_label: Label
var record_label: Label

var aircraft_title: Label
var aircraft_role: Label
var aircraft_status: Label
var aircraft_doctrine: Label

var speed_label: Label
var speed_bar: ProgressBar
var hull_label: Label
var hull_bar: ProgressBar
var fuel_label: Label
var fuel_bar: ProgressBar
var handling_label: Label
var handling_bar: ProgressBar
var damage_label: Label
var damage_bar: ProgressBar

var primary_val: Label
var secondary_val: Label
var special_val: Label
var super_val: Label

var card_buttons: Array[Button] = []
var deploy_btn: Button
var back_btn: Button
var armory_btn: Button
var reset_view_btn: Button
var prev_btn: Button
var next_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui_layout()
	_setup_3d_stage()
	var chosen: String = "apache"
	if has_node("/root/GameManager"):
		chosen = get_node("/root/GameManager").selected_aircraft
	var initial_idx = ["apache", "nighthawk", "warlock"].find(chosen)
	select_aircraft(maxi(0, initial_idx))
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if not visible:
		if stage_viewport:
			stage_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return

	if not stage_viewport:
		_setup_3d_stage()

	if stage_viewport:
		stage_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	is_deploying = false
	if deploy_btn:
		deploy_btn.disabled = false
		deploy_btn.grab_focus()

	# Immediately refresh wallet & live performance stats when reopened
	_update_wallet_display()
	select_aircraft(current_aircraft_idx)

func _update_wallet_display() -> void:
	if not has_node("/root/ProfileManager"):
		return
	var pm = get_node("/root/ProfileManager")
	if wallet_label:
		wallet_label.text = "CREDITS: %d CR" % pm.banked_credits
	if salvage_label:
		salvage_label.text = "SALVAGE: %d" % pm.salvage
	if record_label:
		record_label.text = "RECORD: %d PTS" % pm.high_score

func select_aircraft(idx: int) -> void:
	current_aircraft_idx = clampi(idx, 0, 2)
	var aircraft_keys = ["apache", "nighthawk", "warlock"]
	var aircraft_id: String = aircraft_keys[current_aircraft_idx]

	# Update persistent managers
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").selected_aircraft = aircraft_id
	if has_node("/root/ProfileManager"):
		get_node("/root/ProfileManager").remember_aircraft(aircraft_id)

	# Fetch authoritative stats
	var pm = get_node_or_null("/root/ProfileManager")
	var h_ranks: Dictionary = pm.hangar_ranks if pm else {}
	var p_ranks: Dictionary = pm.perk_ranks if pm else {}
	var effective: Dictionary = Specs.calculate_effective_stats(aircraft_id, h_ranks, p_ranks)

	# Update 3D Showcase Model
	if heli_model:
		Specs.configure_airframe_visuals(heli_model, aircraft_id, true)
		if _selection_tween and _selection_tween.is_valid():
			_selection_tween.kill()
		var stween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_selection_tween = stween
		stween.tween_property(heli_model, "scale", Vector3.ONE * effective.preview_scale, 0.28)
		stween.tween_property(heli_model, "position:y", 0.12 + 2.20 * effective.preview_scale, 0.28)
		if turntable_root:
			stween.tween_property(turntable_root, "rotation:y", 0.0, 0.35)
			rot_velocity = 0.0

	# Update Identity Text
	if aircraft_title:
		aircraft_title.text = effective.name
	if aircraft_role:
		aircraft_role.text = effective.role
	if aircraft_status:
		aircraft_status.text = effective.status
	if aircraft_doctrine:
		aircraft_doctrine.text = effective.doctrine

	# Update Truthful Performance Metrics
	# Shared comparison ceilings: Speed 60 m/s, Hull 220 HP, Fuel 220 L, Agility 2.0x, Damage 30%
	if speed_bar and speed_label:
		speed_bar.value = (effective.speed / 60.0) * 100.0
		if effective.has_speed_upgrade:
			speed_label.text = "%.1f m/s  (+%.1f HANGAR)" % [effective.speed, effective.speed_bonus]
		else:
			speed_label.text = "%.1f m/s  [BASE]" % effective.speed

	if hull_bar and hull_label:
		hull_bar.value = (effective.hull / 220.0) * 100.0
		if effective.has_hull_upgrade:
			hull_label.text = "%.0f HP  (+%.0f ARMOR)" % [effective.hull, effective.hull_bonus]
		else:
			hull_label.text = "%.0f HP  [BASE]" % effective.hull

	if fuel_bar and fuel_label:
		fuel_bar.value = (effective.fuel / 220.0) * 100.0
		if effective.has_fuel_upgrade:
			fuel_label.text = "%.0f L  (+%.0f AUX)" % [effective.fuel, effective.fuel_bonus]
		else:
			fuel_label.text = "%.0f L  [BASE]" % effective.fuel

	if handling_bar and handling_label:
		handling_bar.value = (effective.handling / 2.0) * 100.0
		if effective.has_handling_upgrade:
			handling_label.text = "%.2fx  (+%.0f%% ROTOR)" % [effective.handling, effective.handling_bonus * 100.0]
		else:
			handling_label.text = "%.2fx  [BASE]" % effective.handling

	if damage_bar and damage_label:
		damage_bar.value = (effective.damage_bonus_pct / 30.0) * 100.0
		if effective.damage_bonus_pct > 0:
			damage_label.text = "+%.0f%% WEAPONS  [LVL %d]" % [effective.damage_bonus_pct, h_ranks.get("weapon_system", 0)]
		else:
			damage_label.text = "+0%  [STANDARD]"

	# Pulse stat bars on switch
	var b_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	for bar in [speed_bar, hull_bar, fuel_bar, handling_bar, damage_bar]:
		if bar:
			bar.modulate = Color(1.6, 1.6, 1.6)
			b_tween.tween_property(bar, "modulate", Color.WHITE, 0.22)

	# Update Tactical Armament Loadout from real ProfileManager active mods
	_update_tactical_loadout()

	# Highlight Active Card
	for i in range(card_buttons.size()):
		var btn = card_buttons[i]
		if i == current_aircraft_idx:
			btn.add_theme_color_override("font_color", Color("ffd700"))
			btn.add_theme_stylebox_override("normal", _create_panel_style(Color("1e3540"), Color("ffd700"), 2))
		else:
			btn.add_theme_color_override("font_color", Color("9ab0b8"))
			btn.add_theme_stylebox_override("normal", _create_panel_style(Color("0f1a21"), Color("253d48"), 1))

	vehicle_selected.emit(aircraft_id)

func _update_tactical_loadout() -> void:
	var mg_mod_name = "STANDARD 20MM DUAL"
	var mis_mod_name = "AGM-114 HELLFIRE"
	var rkt_mod_name = "HYDRA-70 FFAR"
	var sgn_mod_name = "FLAK COMBAT SHOTGUN"

	if has_node("/root/ProfileManager"):
		var pm = get_node("/root/ProfileManager")
		var mg_mod = pm.get_equipped_mod(GameConst.WeaponType.MACHINE_GUN)
		if mg_mod == GameConst.WeaponMod.MG_INCENDIARY:
			mg_mod_name = "20MM INCENDIARY TRACERS"
		elif mg_mod == GameConst.WeaponMod.MG_PIERCING:
			mg_mod_name = "20MM ARMOR-PIERCING SABOT"

		var mis_mod = pm.get_equipped_mod(GameConst.WeaponType.MISSILE)
		if mis_mod == GameConst.WeaponMod.MISSILE_EMP:
			mis_mod_name = "HELLFIRE [EMP WARHEAD]"
		elif mis_mod == GameConst.WeaponMod.MISSILE_CLUSTER:
			mis_mod_name = "HELLFIRE [CLUSTER SUBMUNITIONS]"

		var rkt_mod = pm.get_equipped_mod(GameConst.WeaponType.ROCKET)
		if rkt_mod == GameConst.WeaponMod.ROCKET_NAPALM:
			rkt_mod_name = "HYDRA-70 [NAPALM THERMOBARIC]"
		elif rkt_mod == GameConst.WeaponMod.ROCKET_SHAPED:
			rkt_mod_name = "HYDRA-70 [SHAPED CHARGE]"

	if primary_val:
		primary_val.text = "PRIMARY: " + mg_mod_name
	if secondary_val:
		secondary_val.text = "ORDNANCE: %s // %s" % [mis_mod_name, rkt_mod_name]
	if special_val:
		special_val.text = "SPECIAL: Painted Target Salvo (up to 6 locks)"
	if super_val:
		super_val.text = "SUPER: Devastation Carpet Bomb [V / G]"

func _on_prev_pressed() -> void:
	var next_idx = (current_aircraft_idx - 1 + 3) % 3
	select_aircraft(next_idx)

func _on_next_pressed() -> void:
	var next_idx = (current_aircraft_idx + 1) % 3
	select_aircraft(next_idx)

func _on_reset_view_pressed() -> void:
	if turntable_root:
		var rt = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		rt.tween_property(turntable_root, "rotation:y", 0.0, 0.40)
		rot_velocity = 0.0

func _on_deploy_pressed() -> void:
	if is_deploying or not visible:
		return
	var aircraft_keys = ["apache", "nighthawk", "warlock"]
	var chosen_id: String = aircraft_keys[current_aircraft_idx]
	if get_node("/root/UIFlow").begin_run(chosen_id):
		is_deploying = true
		deploy_btn.disabled = true
		if stage_viewport:
			stage_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _on_back_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("ui_click")
	visible = false
	returned_to_menu.emit()

func _on_armory_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("ui_click")
	var parent_menu = get_parent()
	if parent_menu and parent_menu.has_node("HangarMenu"):
		var hangar = parent_menu.get_node("HangarMenu")
		if "caller_origin" in hangar:
			hangar.caller_origin = "vehicle_select"
		hangar.refresh_ui()
		hangar.visible = true
		visible = false
		if hangar.back_button:
			hangar.back_button.grab_focus()
		if not hangar.has_meta("_veh_menu_hooked"):
			hangar.set_meta("_veh_menu_hooked", true)
			if hangar.has_signal("hangar_closed"):
				hangar.hangar_closed.connect(func(target_return: String):
					if target_return == "vehicle_select":
						visible = true
						select_aircraft(current_aircraft_idx)
						_update_wallet_display()
						if armory_btn:
							armory_btn.grab_focus()
				)

# ------------------------------------------------------------------------------
# 3D Showcase Stage Setup (Isolated Viewport Studio)
# ------------------------------------------------------------------------------
func _setup_3d_stage() -> void:
	if not stage_container:
		return

	var viewport = SubViewport.new()
	viewport.name = "StageViewport"
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Allow SubViewportContainer with stretch=true to determine exact size responsively
	viewport.size = Vector2i(640, 480)
	stage_container.add_child(viewport)
	stage_viewport = viewport

	# 1. World Environment
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("070c10") # Dark charcoal military hangar background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("232f38") # Soft neutral fill
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env_node.environment = env
	viewport.add_child(env_node)

	# 2. Camera Framing: Centered with heroic 3/4 elevation
	stage_camera = Camera3D.new()
	stage_camera.name = "StageCamera"
	viewport.add_child(stage_camera)
	stage_camera.position = Vector3(0.0, 2.9, 7.3)
	stage_camera.look_at(Vector3(0.0, 0.40, 0.0))
	stage_camera.fov = 34.0
	stage_camera.current = true

	# 3. Studio Directional Lights (Key, Left Fill, Back Rim)
	var key_light = DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(35)) * Basis(Vector3.RIGHT, deg_to_rad(-38)), Vector3(5, 12, 7))
	key_light.light_color = Color("fffcf5")
	key_light.light_energy = 1.05
	key_light.shadow_enabled = true
	viewport.add_child(key_light)

	var fill_light = DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-70)) * Basis(Vector3.RIGHT, deg_to_rad(-25)), Vector3(-8, 6, 4))
	fill_light.light_color = Color("8fa8b8")
	fill_light.light_energy = 0.45
	fill_light.shadow_enabled = false
	viewport.add_child(fill_light)

	var rim_light = DirectionalLight3D.new()
	rim_light.name = "RimLight"
	rim_light.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-145)) * Basis(Vector3.RIGHT, deg_to_rad(-30)), Vector3(-6, 8, -6))
	rim_light.light_color = Color("c0d5e0")
	rim_light.light_energy = 0.50
	rim_light.shadow_enabled = false
	viewport.add_child(rim_light)

	# 4. Hangar Ground Floor & Subdued Pedestal
	var floor_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor_mesh.mesh = plane
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color("091014")
	floor_mat.roughness = 0.90
	floor_mat.metallic = 0.20
	floor_mesh.material_override = floor_mat
	viewport.add_child(floor_mesh)

	# Subdued Pedestal Turntable
	turntable_root = Node3D.new()
	turntable_root.name = "Turntable"
	turntable_root.position = Vector3(0, 0, 0)
	viewport.add_child(turntable_root)

	var pedestal_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 1.95
	cyl.bottom_radius = 2.05
	cyl.height = 0.08
	cyl.radial_segments = 48
	pedestal_mesh.mesh = cyl
	pedestal_mesh.position.y = 0.04
	var ped_mat = StandardMaterial3D.new()
	ped_mat.albedo_color = Color("10161a")
	ped_mat.metallic = 0.45
	ped_mat.roughness = 0.75
	pedestal_mesh.material_override = ped_mat
	turntable_root.add_child(pedestal_mesh)

	# Subdued Perimeter Ring (Restrained, non-blinding military amber)
	pedestal_ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 1.84
	torus.outer_radius = 1.90
	torus.rings = 48
	torus.ring_segments = 24
	pedestal_ring.mesh = torus
	pedestal_ring.position.y = 0.085
	var hazard_mat = StandardMaterial3D.new()
	hazard_mat.albedo_color = Color("b58428")
	hazard_mat.emission_enabled = true
	hazard_mat.emission = Color("5e410f")
	hazard_mat.emission_energy_multiplier = 0.22
	hazard_mat.roughness = 0.6
	pedestal_ring.material_override = hazard_mat
	turntable_root.add_child(pedestal_ring)

	# 5. Helicopter 3D Model Instance (Instantiated from player.tscn for authentic visual tree)
	var player_src = load("res://scenes/player/player.tscn").instantiate()
	heli_model = player_src.get_node("Visuals").duplicate()
	player_src.free()
	heli_model.name = "ShowcaseHelicopter"

	# Center geometric bounds around (0, 0, 0)
	var apache_inner = heli_model.find_child("ApacheModel", true, false)
	if apache_inner:
		apache_inner.position.z -= 1.005

	# Landing gear rests squarely on top of pedestal (top y = 0.12)
	heli_model.position = Vector3(0, 0.12 + 2.20 * 0.38, 0)
	heli_model.rotation.y = deg_to_rad(140.0)
	heli_model.scale = Vector3.ONE * 0.38
	turntable_root.add_child(heli_model)

	# Disable gameplay combat lights
	for light_name in ["NavLightLeft", "NavLightRight", "AirframeFillLight", "TailStrobe", "SearchLight"]:
		var l = heli_model.find_child(light_name, true, false)
		if l:
			l.visible = false

	# Build authentic military landing gear and chin turret for showcase
	_build_showcase_landing_gear(heli_model)

	# Apply initial aircraft visual configuration
	var aircraft_keys = ["apache", "nighthawk", "warlock"]
	Specs.configure_airframe_visuals(heli_model, aircraft_keys[current_aircraft_idx], true)

func _build_showcase_landing_gear(parent: Node3D) -> void:
	var rubber_mat = StandardMaterial3D.new()
	rubber_mat.albedo_color = Color("141618")
	rubber_mat.metallic = 0.05
	rubber_mat.roughness = 0.88

	var strut_mat = StandardMaterial3D.new()
	strut_mat.albedo_color = Color("282c30")
	strut_mat.metallic = 0.80
	strut_mat.roughness = 0.30

	# Left Main Landing Gear
	var left_gear = Node3D.new()
	left_gear.name = "LeftMainGear"
	parent.add_child(left_gear)

	var left_wheel = MeshInstance3D.new()
	var w_cyl = CylinderMesh.new()
	w_cyl.top_radius = 0.30
	w_cyl.bottom_radius = 0.30
	w_cyl.height = 0.18
	w_cyl.radial_segments = 24
	left_wheel.mesh = w_cyl
	left_wheel.material_override = rubber_mat
	left_wheel.rotation.z = deg_to_rad(90)
	left_wheel.position = Vector3(-1.65, -1.90, -0.60)
	left_gear.add_child(left_wheel)

	var left_strut = MeshInstance3D.new()
	var s_cyl = CylinderMesh.new()
	s_cyl.top_radius = 0.055
	s_cyl.bottom_radius = 0.065
	s_cyl.height = 0.95
	left_strut.mesh = s_cyl
	left_strut.material_override = strut_mat
	left_strut.position = Vector3(-1.42, -1.50, -0.60)
	left_strut.rotation.z = deg_to_rad(-30)
	left_gear.add_child(left_strut)

	# Right Main Landing Gear
	var right_gear = Node3D.new()
	right_gear.name = "RightMainGear"
	parent.add_child(right_gear)

	var right_wheel = MeshInstance3D.new()
	right_wheel.mesh = w_cyl
	right_wheel.material_override = rubber_mat
	right_wheel.rotation.z = deg_to_rad(90)
	right_wheel.position = Vector3(1.65, -1.90, -0.60)
	right_gear.add_child(right_wheel)

	var right_strut = MeshInstance3D.new()
	right_strut.mesh = s_cyl
	right_strut.material_override = strut_mat
	right_strut.position = Vector3(1.42, -1.50, -0.60)
	right_strut.rotation.z = deg_to_rad(30)
	right_gear.add_child(right_strut)

	# Tail Wheel
	var tail_gear = Node3D.new()
	tail_gear.name = "TailGear"
	parent.add_child(tail_gear)

	var tail_wheel = MeshInstance3D.new()
	var tw_cyl = CylinderMesh.new()
	tw_cyl.top_radius = 0.16
	tw_cyl.bottom_radius = 0.16
	tw_cyl.height = 0.10
	tw_cyl.radial_segments = 20
	tail_wheel.mesh = tw_cyl
	tail_wheel.material_override = rubber_mat
	tail_wheel.rotation.z = deg_to_rad(90)
	tail_wheel.position = Vector3(0, -2.04, 5.20)
	tail_gear.add_child(tail_wheel)

	var tail_strut = MeshInstance3D.new()
	var ts_cyl = CylinderMesh.new()
	ts_cyl.top_radius = 0.04
	ts_cyl.bottom_radius = 0.045
	ts_cyl.height = 0.65
	tail_strut.mesh = ts_cyl
	tail_strut.material_override = strut_mat
	tail_strut.position = Vector3(0, -1.75, 5.15)
	tail_strut.rotation.x = deg_to_rad(-20)
	tail_gear.add_child(tail_strut)

	# Chin Chaingun Turret
	var chin_turret = Node3D.new()
	chin_turret.name = "ChinTurret"
	parent.add_child(chin_turret)

	var gun_base = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(0.35, 0.28, 0.45)
	gun_base.mesh = b_mesh
	gun_base.material_override = strut_mat
	gun_base.position = Vector3(0, -1.55, -4.10)
	chin_turret.add_child(gun_base)

	var gun_barrel = MeshInstance3D.new()
	var gb_cyl = CylinderMesh.new()
	gb_cyl.top_radius = 0.045
	gb_cyl.bottom_radius = 0.055
	gb_cyl.height = 1.35
	gun_barrel.mesh = gb_cyl
	gun_barrel.material_override = strut_mat
	gun_barrel.position = Vector3(0, -1.65, -4.80)
	gun_barrel.rotation_degrees = Vector3(90, 0, 0)
	chin_turret.add_child(gun_barrel)

func _process(delta: float) -> void:
	if not visible:
		return

	# Turntable inertial rotation
	if not is_dragging and abs(rot_velocity) > 0.0005 and turntable_root:
		turntable_root.rotate_y(rot_velocity * delta)
		rot_velocity = lerp(rot_velocity, 0.0, delta * 5.0)

# ------------------------------------------------------------------------------
# UI Layout Construction (Retro Military Hangar Interface)
# ------------------------------------------------------------------------------
func _build_ui_layout() -> void:
	var pixel_font = preload("res://src/effects/floating_text.gd").get_pixel_font()

	# Main Margin Container (14px margins all around)
	var main_margin = MarginContainer.new()
	main_margin.name = "MainMargin"
	main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_left", 14)
	main_margin.add_theme_constant_override("margin_top", 10)
	main_margin.add_theme_constant_override("margin_right", 14)
	main_margin.add_theme_constant_override("margin_bottom", 12)
	add_child(main_margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.name = "RootVBox"
	root_vbox.add_theme_constant_override("separation", 8)
	main_margin.add_child(root_vbox)

	# 1. Top Header Bar (Height ~42px)
	var top_panel = PanelContainer.new()
	top_panel.name = "TopBar"
	top_panel.custom_minimum_size.y = 42
	top_panel.add_theme_stylebox_override("panel", _create_panel_style(Color("0c141a"), Color("223b47"), 1))
	root_vbox.add_child(top_panel)

	var top_margin = MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 14)
	top_margin.add_theme_constant_override("margin_right", 14)
	top_margin.add_theme_constant_override("margin_top", 4)
	top_margin.add_theme_constant_override("margin_bottom", 4)
	top_panel.add_child(top_margin)

	var top_hbox = HBoxContainer.new()
	top_margin.add_child(top_hbox)

	var title_box = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 1)
	top_hbox.add_child(title_box)

	var cmd_title = Label.new()
	cmd_title.text = "SELECT AIRCRAFT"
	cmd_title.add_theme_font_override("font", pixel_font)
	cmd_title.add_theme_font_size_override("font_size", 16)
	cmd_title.add_theme_color_override("font_color", Color("ffd700"))
	title_box.add_child(cmd_title)

	var cmd_sub = Label.new()
	cmd_sub.text = "TACTICAL AIR COMMAND // SORTIE PREPARATION"
	cmd_sub.add_theme_font_override("font", pixel_font)
	cmd_sub.add_theme_font_size_override("font_size", 9)
	cmd_sub.add_theme_color_override("font_color", Color("7a98a3"))
	title_box.add_child(cmd_sub)

	# Right Wallet & High Score Group
	var wallet_box = HBoxContainer.new()
	wallet_box.add_theme_constant_override("separation", 12)
	top_hbox.add_child(wallet_box)

	wallet_label = Label.new()
	wallet_label.text = "CREDITS: 0 CR"
	wallet_label.add_theme_font_override("font", pixel_font)
	wallet_label.add_theme_font_size_override("font_size", 10)
	wallet_label.add_theme_color_override("font_color", Color("eaf0f2"))
	wallet_box.add_child(wallet_label)

	var sep1 = Label.new()
	sep1.text = "|"
	sep1.add_theme_font_override("font", pixel_font)
	sep1.add_theme_font_size_override("font_size", 10)
	sep1.add_theme_color_override("font_color", Color("315566"))
	wallet_box.add_child(sep1)

	salvage_label = Label.new()
	salvage_label.text = "SALVAGE: 0"
	salvage_label.add_theme_font_override("font", pixel_font)
	salvage_label.add_theme_font_size_override("font_size", 10)
	salvage_label.add_theme_color_override("font_color", Color("56c9b8"))
	wallet_box.add_child(salvage_label)

	var sep2 = Label.new()
	sep2.text = "|"
	sep2.add_theme_font_override("font", pixel_font)
	sep2.add_theme_font_size_override("font_size", 10)
	sep2.add_theme_color_override("font_color", Color("315566"))
	wallet_box.add_child(sep2)

	record_label = Label.new()
	record_label.text = "RECORD: 0 PTS"
	record_label.add_theme_font_override("font", pixel_font)
	record_label.add_theme_font_size_override("font_size", 10)
	record_label.add_theme_color_override("font_color", Color("7a98a3"))
	wallet_box.add_child(record_label)
	_update_wallet_display()

	# 2. Main Content Split (Left 58% Showcase, Right 42% Dossier)
	var main_split = HBoxContainer.new()
	main_split.name = "MainSplit"
	main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.add_theme_constant_override("separation", 14)
	root_vbox.add_child(main_split)

	# --- LEFT SHOWCASE COLUMN ---
	var left_col = VBoxContainer.new()
	left_col.name = "LeftShowcaseColumn"
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 1.38 # ~58% width
	left_col.add_theme_constant_override("separation", 10)
	main_split.add_child(left_col)

	# Showcase Panel Container
	var showcase_panel = PanelContainer.new()
	showcase_panel.name = "ShowcasePanel"
	showcase_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	showcase_panel.add_theme_stylebox_override("panel", _create_panel_style(Color("080d12"), Color("223b47"), 1))
	left_col.add_child(showcase_panel)

	# Viewport Container inside panel
	stage_container = SubViewportContainer.new()
	stage_container.name = "StageContainer"
	stage_container.stretch = true
	stage_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_container.mouse_filter = Control.MOUSE_FILTER_PASS
	stage_container.gui_input.connect(_on_showcase_gui_input)
	showcase_panel.add_child(stage_container)

	# Showcase HUD Overlay (Rotation hint & Reset View)
	var showcase_hud = MarginContainer.new()
	showcase_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	showcase_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase_hud.add_theme_constant_override("margin_left", 12)
	showcase_hud.add_theme_constant_override("margin_top", 10)
	showcase_hud.add_theme_constant_override("margin_right", 12)
	showcase_hud.add_theme_constant_override("margin_bottom", 10)
	showcase_panel.add_child(showcase_hud)

	var hud_top_bar = HBoxContainer.new()
	hud_top_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hud_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase_hud.add_child(hud_top_bar)

	var rot_hint = Label.new()
	rot_hint.text = "[ MOUSE DRAG: ROTATE 360° ]"
	rot_hint.add_theme_font_override("font", pixel_font)
	rot_hint.add_theme_font_size_override("font_size", 9)
	rot_hint.add_theme_color_override("font_color", Color("56c9b8"))
	rot_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_top_bar.add_child(rot_hint)

	reset_view_btn = Button.new()
	reset_view_btn.text = "RESET VIEW"
	reset_view_btn.add_theme_font_override("font", pixel_font)
	reset_view_btn.add_theme_font_size_override("font_size", 9)
	reset_view_btn.add_theme_color_override("font_color", Color("9ab0b8"))
	reset_view_btn.add_theme_stylebox_override("normal", _create_panel_style(Color("122028"), Color("2b4c5c"), 1))
	reset_view_btn.add_theme_stylebox_override("hover", _create_panel_style(Color("1c3340"), Color("56c9b8"), 1))
	reset_view_btn.custom_minimum_size = Vector2(90, 22)
	reset_view_btn.pressed.connect(_on_reset_view_pressed)
	hud_top_bar.add_child(reset_view_btn)

	# Bottom Aircraft Cards Row
	var cards_row = HBoxContainer.new()
	cards_row.name = "AircraftCardsRow"
	cards_row.custom_minimum_size.y = 46
	cards_row.add_theme_constant_override("separation", 6)
	left_col.add_child(cards_row)

	prev_btn = Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(28, 46)
	prev_btn.add_theme_font_override("font", pixel_font)
	prev_btn.add_theme_font_size_override("font_size", 12)
	prev_btn.add_theme_stylebox_override("normal", _create_panel_style(Color("101b22"), Color("253d48"), 1))
	prev_btn.add_theme_stylebox_override("hover", _create_panel_style(Color("1c3340"), Color("ffd700"), 1))
	prev_btn.pressed.connect(_on_prev_pressed)
	cards_row.add_child(prev_btn)

	card_buttons.clear()
	var card_specs := [
		{"name": "AH-64 APACHE", "tag": "BALANCED ASSAULT"},
		{"name": "RAH-66 NIGHTHAWK", "tag": "+15% SPEED // AGILE"},
		{"name": "MI-28 WARLOCK", "tag": "+30% HULL // FORTIFIED"}
	]

	for i in range(card_specs.size()):
		var c_spec = card_specs[i]
		var card = Button.new()
		card.name = "Card_" + str(i)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = 46
		card.add_theme_font_override("font", pixel_font)
		card.add_theme_font_size_override("font_size", 9)
		card.text = "%s\n[%s]" % [c_spec.name, c_spec.tag]
		var idx = i
		card.pressed.connect(func(): select_aircraft(idx))
		cards_row.add_child(card)
		card_buttons.append(card)

	next_btn = Button.new()
	next_btn.text = ">"
	next_btn.custom_minimum_size = Vector2(28, 46)
	next_btn.add_theme_font_override("font", pixel_font)
	next_btn.add_theme_font_size_override("font_size", 12)
	next_btn.add_theme_stylebox_override("normal", _create_panel_style(Color("101b22"), Color("253d48"), 1))
	next_btn.add_theme_stylebox_override("hover", _create_panel_style(Color("1c3340"), Color("ffd700"), 1))
	next_btn.pressed.connect(_on_next_pressed)
	cards_row.add_child(next_btn)

	# --- RIGHT DOSSIER COLUMN ---
	var right_col = PanelContainer.new()
	right_col.name = "RightDossierColumn"
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 1.0 # ~42% width
	right_col.add_theme_stylebox_override("panel", _create_panel_style(Color("0c141a"), Color("223b47"), 1))
	main_split.add_child(right_col)

	var dossier_margin = MarginContainer.new()
	dossier_margin.add_theme_constant_override("margin_left", 14)
	dossier_margin.add_theme_constant_override("margin_top", 12)
	dossier_margin.add_theme_constant_override("margin_right", 14)
	dossier_margin.add_theme_constant_override("margin_bottom", 12)
	right_col.add_child(dossier_margin)

	var dossier_vbox = VBoxContainer.new()
	dossier_vbox.add_theme_constant_override("separation", 10)
	dossier_margin.add_child(dossier_vbox)

	# SECTION 1: Identity & Role
	var id_box = VBoxContainer.new()
	id_box.add_theme_constant_override("separation", 2)
	dossier_vbox.add_child(id_box)

	aircraft_title = Label.new()
	aircraft_title.text = "AH-64 APACHE"
	aircraft_title.add_theme_font_override("font", pixel_font)
	aircraft_title.add_theme_font_size_override("font_size", 18)
	aircraft_title.add_theme_color_override("font_color", Color("eaf0f2"))
	id_box.add_child(aircraft_title)

	aircraft_role = Label.new()
	aircraft_role.text = "ALL-WEATHER ASSAULT GUNSHIP"
	aircraft_role.add_theme_font_override("font", pixel_font)
	aircraft_role.add_theme_font_size_override("font_size", 10)
	aircraft_role.add_theme_color_override("font_color", Color("ffd700"))
	id_box.add_child(aircraft_role)

	aircraft_status = Label.new()
	aircraft_status.text = "COMBAT READY // BALANCED AIRFRAME"
	aircraft_status.add_theme_font_override("font", pixel_font)
	aircraft_status.add_theme_font_size_override("font_size", 9)
	aircraft_status.add_theme_color_override("font_color", Color("56c9b8"))
	id_box.add_child(aircraft_status)

	aircraft_doctrine = Label.new()
	aircraft_doctrine.text = "Frontline twin-turboshaft attack helicopter engineered for armored breakthrough. Delivers the tactical baseline balance of cruise speed, composite hull durability, and sustained fuel reserves."
	aircraft_doctrine.add_theme_font_override("font", pixel_font)
	aircraft_doctrine.add_theme_font_size_override("font_size", 10)
	aircraft_doctrine.add_theme_color_override("font_color", Color("c0ced4"))
	aircraft_doctrine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aircraft_doctrine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_box.add_child(aircraft_doctrine)

	var div1 = HSeparator.new()
	div1.add_theme_stylebox_override("separator", _create_line_style(Color("223b47")))
	dossier_vbox.add_child(div1)

	# SECTION 2: Truthful Performance Matrix
	var perf_header = Label.new()
	perf_header.text = "AIRFRAME PERFORMANCE MATRIX"
	perf_header.add_theme_font_override("font", pixel_font)
	perf_header.add_theme_font_size_override("font_size", 10)
	perf_header.add_theme_color_override("font_color", Color("7a98a3"))
	dossier_vbox.add_child(perf_header)

	var matrix_vbox = VBoxContainer.new()
	matrix_vbox.add_theme_constant_override("separation", 6)
	dossier_vbox.add_child(matrix_vbox)

	var speed_res = _create_stat_meter(matrix_vbox, pixel_font, "CRUISE SPEED", Color("3da89b"))
	speed_label = speed_res.label
	speed_bar = speed_res.bar

	var hull_res = _create_stat_meter(matrix_vbox, pixel_font, "HULL DURABILITY", Color("d96d43"))
	hull_label = hull_res.label
	hull_bar = hull_res.bar

	var fuel_res = _create_stat_meter(matrix_vbox, pixel_font, "FUEL CAPACITY", Color("438fd9"))
	fuel_label = fuel_res.label
	fuel_bar = fuel_res.bar

	var hand_res = _create_stat_meter(matrix_vbox, pixel_font, "TURN AGILITY", Color("43d99e"))
	handling_label = hand_res.label
	handling_bar = hand_res.bar

	var dmg_res = _create_stat_meter(matrix_vbox, pixel_font, "WEAPON DAMAGE", Color("e6af2e"))
	damage_label = dmg_res.label
	damage_bar = dmg_res.bar

	var div2 = HSeparator.new()
	div2.add_theme_stylebox_override("separator", _create_line_style(Color("223b47")))
	dossier_vbox.add_child(div2)

	# SECTION 3: Tactical Armament Loadout
	var loadout_header = Label.new()
	loadout_header.text = "TACTICAL ARMAMENT LOADOUT"
	loadout_header.add_theme_font_override("font", pixel_font)
	loadout_header.add_theme_font_size_override("font_size", 10)
	loadout_header.add_theme_color_override("font_color", Color("7a98a3"))
	dossier_vbox.add_child(loadout_header)

	var loadout_box = VBoxContainer.new()
	loadout_box.add_theme_constant_override("separation", 3)
	dossier_vbox.add_child(loadout_box)

	primary_val = Label.new()
	primary_val.text = "PRIMARY CANNON: M197 20MM DUAL"
	primary_val.add_theme_font_override("font", pixel_font)
	primary_val.add_theme_font_size_override("font_size", 9)
	primary_val.add_theme_color_override("font_color", Color("eaf0f2"))
	primary_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	primary_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout_box.add_child(primary_val)

	secondary_val = Label.new()
	secondary_val.text = "ORDNANCE PODS: AGM-114 HELLFIRE // HYDRA-70"
	secondary_val.add_theme_font_override("font", pixel_font)
	secondary_val.add_theme_font_size_override("font_size", 9)
	secondary_val.add_theme_color_override("font_color", Color("c0ced4"))
	secondary_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	secondary_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout_box.add_child(secondary_val)

	special_val = Label.new()
	special_val.text = "TARGET SALVO: Painted Radar Lock (up to 6 targets)"
	special_val.add_theme_font_override("font", pixel_font)
	special_val.add_theme_font_size_override("font_size", 9)
	special_val.add_theme_color_override("font_color", Color("56c9b8"))
	special_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	special_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout_box.add_child(special_val)

	super_val = Label.new()
	super_val.text = "PILOT SUPER: Devastation Carpet Bomb & Overdrive [V / G]"
	super_val.add_theme_font_override("font", pixel_font)
	super_val.add_theme_font_size_override("font_size", 9)
	super_val.add_theme_color_override("font_color", Color("ffd700"))
	super_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	super_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout_box.add_child(super_val)

	# Flexible spacer to push action buttons firmly to bottom
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier_vbox.add_child(spacer)

	# SECTION 4: Action Buttons (Launch Sortie, Back, Upgrade Hangar)
	var actions_box = VBoxContainer.new()
	actions_box.add_theme_constant_override("separation", 8)
	dossier_vbox.add_child(actions_box)

	deploy_btn = Button.new()
	deploy_btn.name = "DeployBtn"
	deploy_btn.text = ">>> LAUNCH SORTIE <<<"
	deploy_btn.custom_minimum_size.y = 42
	deploy_btn.add_theme_font_override("font", pixel_font)
	deploy_btn.add_theme_font_size_override("font_size", 13)
	deploy_btn.add_theme_color_override("font_color", Color.WHITE)
	deploy_btn.add_theme_color_override("font_hover_color", Color("ffd700"))
	deploy_btn.add_theme_stylebox_override("normal", _create_panel_style(Color("1f6b63"), Color("38b3a4"), 2))
	deploy_btn.add_theme_stylebox_override("hover", _create_panel_style(Color("268278"), Color("56c9b8"), 2))
	deploy_btn.pressed.connect(_on_deploy_pressed)
	actions_box.add_child(deploy_btn)

	var sub_actions = HBoxContainer.new()
	sub_actions.add_theme_constant_override("separation", 8)
	actions_box.add_child(sub_actions)

	back_btn = Button.new()
	back_btn.name = "BackBtn"
	back_btn.text = "< BACK"
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.custom_minimum_size.y = 34
	back_btn.add_theme_font_override("font", pixel_font)
	back_btn.add_theme_font_size_override("font_size", 10)
	back_btn.add_theme_color_override("font_color", Color("c0ced4"))
	back_btn.add_theme_stylebox_override("normal", _create_panel_style(Color("101a20"), Color("253d48"), 1))
	back_btn.add_theme_stylebox_override("hover", _create_panel_style(Color("182832"), Color("56c9b8"), 1))
	back_btn.pressed.connect(_on_back_pressed)
	sub_actions.add_child(back_btn)

	armory_btn = Button.new()
	armory_btn.name = "ArmoryBtn"
	armory_btn.text = "UPGRADE HANGAR >"
	armory_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	armory_btn.custom_minimum_size.y = 34
	armory_btn.add_theme_font_override("font", pixel_font)
	armory_btn.add_theme_font_size_override("font_size", 10)
	armory_btn.add_theme_color_override("font_color", Color("ffd700"))
	armory_btn.add_theme_stylebox_override("normal", _create_panel_style(Color("16242c"), Color("385058"), 1))
	armory_btn.add_theme_stylebox_override("hover", _create_panel_style(Color("223642"), Color("ffd700"), 1))
	armory_btn.pressed.connect(_on_armory_pressed)
	sub_actions.add_child(armory_btn)

	# Keyboard / Joypad Navigation Focus Wiring
	_setup_focus_navigation()

func _create_stat_meter(parent: VBoxContainer, font: Font, label_text: String, fill_color: Color) -> Dictionary:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	parent.add_child(vbox)

	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)

	var title_lbl = Label.new()
	title_lbl.text = label_text
	title_lbl.add_theme_font_override("font", font)
	title_lbl.add_theme_font_size_override("font_size", 9)
	title_lbl.add_theme_color_override("font_color", Color("8fa4ad"))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title_lbl)

	var val_lbl = Label.new()
	val_lbl.text = "---"
	val_lbl.add_theme_font_override("font", font)
	val_lbl.add_theme_font_size_override("font_size", 9)
	val_lbl.add_theme_color_override("font_color", Color("eaf0f2"))
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(val_lbl)

	var bar = ProgressBar.new()
	bar.custom_minimum_size.y = 6
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 50.0

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color("0d171d")
	bg_style.set_corner_radius_all(1)
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(1)
	bar.add_theme_stylebox_override("fill", fill_style)

	vbox.add_child(bar)

	return {"label": val_lbl, "bar": bar}

func _setup_focus_navigation() -> void:
	# Card buttons focus
	for i in range(card_buttons.size()):
		var btn = card_buttons[i]
		if i > 0:
			btn.focus_neighbor_left = card_buttons[i - 1].get_path()
		else:
			btn.focus_neighbor_left = prev_btn.get_path()
		if i < card_buttons.size() - 1:
			btn.focus_neighbor_right = card_buttons[i + 1].get_path()
		else:
			btn.focus_neighbor_right = next_btn.get_path()
		btn.focus_neighbor_top = reset_view_btn.get_path()
		btn.focus_neighbor_bottom = deploy_btn.get_path()

	prev_btn.focus_neighbor_right = card_buttons[0].get_path()
	prev_btn.focus_neighbor_bottom = deploy_btn.get_path()
	next_btn.focus_neighbor_left = card_buttons[card_buttons.size() - 1].get_path()
	next_btn.focus_neighbor_bottom = deploy_btn.get_path()

	deploy_btn.focus_neighbor_top = card_buttons[current_aircraft_idx].get_path()
	deploy_btn.focus_neighbor_bottom = back_btn.get_path()

	back_btn.focus_neighbor_top = deploy_btn.get_path()
	back_btn.focus_neighbor_right = armory_btn.get_path()

	armory_btn.focus_neighbor_top = deploy_btn.get_path()
	armory_btn.focus_neighbor_left = back_btn.get_path()

# Mouse dragging strictly inside showcase viewport container
func _on_showcase_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			drag_start_x = event.position.x
			if is_dragging:
				rot_velocity = 0.0
	elif event is InputEventMouseMotion and is_dragging and turntable_root:
		var diff = event.relative.x
		turntable_root.rotate_y(diff * 0.010)
		var dt = maxf(get_process_delta_time(), 0.001)
		rot_velocity = (diff * 0.010) / dt

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		is_dragging = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible or event.is_echo() or get_node("/root/UIFlow").busy:
		return
	if event.is_action_pressed("ui_left"):
		_on_prev_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_on_next_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _create_panel_style(bg: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(2)
	return sb

func _create_line_style(color: Color) -> StyleBoxLine:
	var sl = StyleBoxLine.new()
	sl.color = color
	sl.thickness = 1
	return sl
