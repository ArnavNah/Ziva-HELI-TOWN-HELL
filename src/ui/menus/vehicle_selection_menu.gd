class_name VehicleSelectionMenu
extends Control

## VehicleSelectionMenu — Minimal modern retro military hangar interface.
## Features an open 3D turntable showroom with smooth rotation and scroll zoom,
## truthful shared performance metrics, authentic loadout matrix, and responsive layout
## matching the tactical air command specification.

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

var target_fov: float = 32.0
const MIN_FOV: float = 20.0
const MAX_FOV: float = 44.0

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

# Property aliases for backward compatibility with older tests
var firepower_bar: ProgressBar:
	get: return damage_bar
var firepower_label: Label:
	get: return damage_label

var primary_val: Label
var secondary_val: Label
var special_val: Label
var super_val: Label

var card_buttons: Array[Button] = []
var card_names: Array[Label] = []
var card_tags: Array[Label] = []

var deploy_btn: Button
var biome_selector: OptionButton
var preview_hint: Label
var back_btn: Button
var armory_btn: Button
var prev_btn: Button
var next_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui_layout()
	_setup_3d_stage()
	var chosen: String = "apache"
	if has_node("/root/GameManager"):
		chosen = get_node("/root/GameManager").selected_aircraft
	var initial_idx = ["apache", "nighthawk", "warlock"].find(chosen)
	select_aircraft(maxi(0, initial_idx))
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()

func _on_visibility_changed() -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		is_dragging = false
		if stage_viewport:
			stage_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return

	if not stage_viewport:
		_setup_3d_stage()

	if stage_viewport:
		stage_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	is_deploying = false
	is_dragging = false
	target_fov = 32.0
	if stage_camera:
		stage_camera.fov = 32.0
	if deploy_btn and deploy_btn.is_inside_tree():
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
		wallet_label.text = "%d CR" % pm.banked_credits
	if salvage_label:
		salvage_label.text = "%d" % pm.salvage
	if record_label:
		record_label.text = "%d PTS" % pm.high_score

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

	var model_scale = effective.preview_scale

	# Update 3D Showcase Model
	if heli_model:
		Specs.configure_airframe_visuals(heli_model, aircraft_id, true)
		if _selection_tween and _selection_tween.is_valid():
			_selection_tween.kill()
		var stween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_selection_tween = stween
		stween.tween_property(heli_model, "scale", Vector3.ONE * model_scale, 0.28)
		stween.tween_property(heli_model, "position:y", 2.20 * model_scale, 0.28)
		heli_model.rotation.y = deg_to_rad(150.0)
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
		aircraft_doctrine.tooltip_text = effective.doctrine
		aircraft_doctrine.text = {
			"apache": "Balanced speed, armor and range. Built for sustained frontline sorties.",
			"nighthawk": "Fast, agile reconnaissance. Lighter armor rewards precise flying.",
			"warlock": "Heavy armor and larger fuel reserves. Slower turns, longer survival."
		}.get(aircraft_id, effective.doctrine)

	# Update Truthful Performance Metrics
	# Ceilings: Speed 60 m/s, Hull 220 HP, Fuel 220 L, Agility 2.0x, Damage 30%
	if speed_bar and speed_label:
		speed_bar.value = (effective.speed / 60.0) * 100.0
		if effective.has_speed_upgrade:
			speed_label.text = "%.1f m/s (+%.1f)" % [effective.speed, effective.speed_bonus]
		else:
			speed_label.text = "%.1f m/s" % effective.speed

	if hull_bar and hull_label:
		hull_bar.value = (effective.hull / 220.0) * 100.0
		if effective.has_hull_upgrade:
			hull_label.text = "%.0f HP (+%.0f)" % [effective.hull, effective.hull_bonus]
		else:
			hull_label.text = "%.0f HP" % effective.hull

	if fuel_bar and fuel_label:
		fuel_bar.value = (effective.fuel / 220.0) * 100.0
		if effective.has_fuel_upgrade:
			fuel_label.text = "%.0f L (+%.0f)" % [effective.fuel, effective.fuel_bonus]
		else:
			fuel_label.text = "%.0f L" % effective.fuel

	if handling_bar and handling_label:
		handling_bar.value = (effective.handling / 2.0) * 100.0
		if effective.has_handling_upgrade:
			handling_label.text = "%.2fx (+%.0f%%)" % [effective.handling, effective.handling_bonus * 100.0]
		else:
			handling_label.text = "%.2fx" % effective.handling

	if damage_bar and damage_label:
		damage_bar.value = (effective.damage_bonus_pct / 30.0) * 100.0
		if effective.damage_bonus_pct > 0:
			damage_label.text = "+%.0f%%" % effective.damage_bonus_pct
		else:
			damage_label.text = "+0%"

	# Pulse stat bars subtly on switch
	var b_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	for bar in [speed_bar, hull_bar, fuel_bar, handling_bar, damage_bar]:
		if bar:
			bar.modulate = Color(1.5, 1.5, 1.5)
			b_tween.tween_property(bar, "modulate", Color.WHITE, 0.20)

	# Update Tactical Armament Loadout from real ProfileManager active mods
	_update_tactical_loadout()

	# Highlight Active Card
	for i in range(card_buttons.size()):
		var btn = card_buttons[i]
		var name_lbl = card_names[i] if i < card_names.size() else null
		var tag_lbl = card_tags[i] if i < card_tags.size() else null
		if i == current_aircraft_idx:
			btn.add_theme_stylebox_override("normal", _create_rounded_panel(Color("0f1b24", 0.95), Color("ffd700"), 2, 6))
			btn.add_theme_stylebox_override("hover", _create_rounded_panel(Color("162633", 0.98), Color("ffe240"), 2, 6))
			if name_lbl:
				name_lbl.add_theme_color_override("font_color", Color("ffd700"))
			if tag_lbl:
				tag_lbl.add_theme_color_override("font_color", Color("ffd700"))
		else:
			btn.add_theme_stylebox_override("normal", _create_rounded_panel(Color("091016", 0.85), Color("1b2c38"), 1, 6))
			btn.add_theme_stylebox_override("hover", _create_rounded_panel(Color("101d27", 0.90), Color("345062"), 1, 6))
			if name_lbl:
				name_lbl.add_theme_color_override("font_color", Color("e0e8ec"))
			if tag_lbl:
				tag_lbl.add_theme_color_override("font_color", Color("617d8b"))

	vehicle_selected.emit(aircraft_id)

func _update_tactical_loadout() -> void:
	var mg_name = "20mm Dual Cannon (Standard)"
	var mis_name = "AGM-114 Hellfire"
	var rkt_name = "Hydra-70 FFAR"

	if has_node("/root/ProfileManager"):
		var pm = get_node("/root/ProfileManager")
		var mg_mod = pm.get_equipped_mod(GameConst.WeaponType.MACHINE_GUN)
		if mg_mod == GameConst.WeaponMod.MG_INCENDIARY:
			mg_name = "20mm Incendiary Tracers"
		elif mg_mod == GameConst.WeaponMod.MG_PIERCING:
			mg_name = "20mm Armor-Piercing Sabot"

		var mis_mod = pm.get_equipped_mod(GameConst.WeaponType.MISSILE)
		if mis_mod == GameConst.WeaponMod.MISSILE_EMP:
			mis_name = "Hellfire [EMP Warhead]"
		elif mis_mod == GameConst.WeaponMod.MISSILE_CLUSTER:
			mis_name = "Hellfire [Cluster Munitions]"

		var rkt_mod = pm.get_equipped_mod(GameConst.WeaponType.ROCKET)
		if rkt_mod == GameConst.WeaponMod.ROCKET_NAPALM:
			rkt_name = "Hydra-70 [Napalm]"
		elif rkt_mod == GameConst.WeaponMod.ROCKET_SHAPED:
			rkt_name = "Hydra-70 [Shaped Charge]"

	if primary_val:
		primary_val.text = mg_name
	if secondary_val:
		secondary_val.text = "%s  /  %s" % [mis_name, rkt_name]
	if special_val:
		special_val.text = "Painted Target Salvo (up to 6 locks)"
	if super_val:
		super_val.text = "Devastation Carpet Bomb   [V / G]"

func _on_prev_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("ui_click")
	var next_idx = (current_aircraft_idx - 1 + 3) % 3
	select_aircraft(next_idx)

func _on_next_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("ui_click")
	var next_idx = (current_aircraft_idx + 1) % 3
	select_aircraft(next_idx)

func _on_deploy_pressed() -> void:
	if is_deploying or not visible:
		return
	var aircraft_keys = ["apache", "nighthawk", "warlock"]
	var chosen_id: String = aircraft_keys[current_aircraft_idx]
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("ui_click")
	if has_node("/root/UIFlow"):
		if get_node("/root/UIFlow").begin_run(chosen_id):
			is_deploying = true
			if deploy_btn:
				deploy_btn.disabled = true
			if stage_viewport:
				stage_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	elif has_node("/root/GameManager"):
		get_node("/root/GameManager").start_game(chosen_id)

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
# 3D Showcase Stage Setup (Heroic eye-level perspective & clean ground plane)
# ------------------------------------------------------------------------------
func _setup_3d_stage() -> void:
	if not stage_container:
		return

	var viewport = SubViewport.new()
	viewport.name = "StageViewport"
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	viewport.size = Vector2i(1280, 720)
	stage_container.add_child(viewport)
	stage_viewport = viewport

	# 1. World Environment
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0a1016") # Deep military hangar atmosphere
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("25323d") # Subtle neutral fill
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.fog_enabled = true
	env.fog_light_color = Color("0d131a")
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0
	env_node.environment = env
	viewport.add_child(env_node)

	# 2. Camera: Heroic perspective at eye level with fuselage
	stage_camera = Camera3D.new()
	stage_camera.name = "StageCamera"
	viewport.add_child(stage_camera)
	stage_camera.position = Vector3(-0.75, 2.2, 8.9)
	stage_camera.look_at(Vector3(-0.75, 1.0, 0.0))
	stage_camera.fov = 31.0
	stage_camera.current = true

	# 3. Studio Directional Lights (Key, Left Fill, Back Rim)
	var key_light = DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-22)) * Basis(Vector3.RIGHT, deg_to_rad(-36)), Vector3(-2, 9, 6))
	key_light.light_color = Color("fff8ee")
	key_light.light_energy = 1.45
	key_light.shadow_enabled = true
	key_light.shadow_bias = 0.03
	key_light.directional_shadow_max_distance = 25.0
	viewport.add_child(key_light)

	var fill_light = DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(45)) * Basis(Vector3.RIGHT, deg_to_rad(-24)), Vector3(7, 6, 4))
	fill_light.light_color = Color("7a9db5")
	fill_light.light_energy = 0.50
	fill_light.shadow_enabled = false
	viewport.add_child(fill_light)

	var rim_light = DirectionalLight3D.new()
	rim_light.name = "RimLight"
	rim_light.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-145)) * Basis(Vector3.RIGHT, deg_to_rad(-28)), Vector3(-5, 8, -6))
	rim_light.light_color = Color("a0c4dc")
	rim_light.light_energy = 0.70
	rim_light.shadow_enabled = false
	viewport.add_child(rim_light)

	# 4. Hangar Ground Floor & Military Environment
	_build_hangar_environment(viewport)

	# Turntable Pivot centered horizontally in open showroom area
	turntable_root = Node3D.new()
	turntable_root.name = "Turntable"
	turntable_root.position = Vector3(-0.75, 0, 0)
	viewport.add_child(turntable_root)

	# Subtle flush deck seam ring (grounded flush with tarmac, non-distracting)
	pedestal_ring = MeshInstance3D.new()
	pedestal_ring.visible = false
	turntable_root.add_child(pedestal_ring)

	# 5. Helicopter 3D Model Instance
	var player_src = load("res://scenes/player/player.tscn").instantiate()
	heli_model = player_src.get_node("Visuals").duplicate()
	player_src.free()
	heli_model.name = "ShowcaseHelicopter"

	var apache_inner = heli_model.find_child("ApacheModel", true, false)
	if apache_inner:
		apache_inner.position.z -= 1.005

	# Initial scale and position: wheels rest squarely on tarmac (y = 0)
	var initial_scale = 0.38
	heli_model.position = Vector3(0, 2.20 * initial_scale, 0)
	heli_model.rotation.y = deg_to_rad(150.0) # Matches reference mockup horizontal 3/4 angle
	heli_model.scale = Vector3.ONE * initial_scale
	turntable_root.add_child(heli_model)

	for light_name in ["NavLightLeft", "NavLightRight", "AirframeFillLight", "TailStrobe", "SearchLight", "CockpitLight"]:
		var l = heli_model.find_child(light_name, true, false)
		if l:
			l.visible = false

	_build_showcase_landing_gear(heli_model)

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

func _build_hangar_environment(viewport: SubViewport) -> void:
	# 1. Hangar Tarmac Concrete Floor
	var floor_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(100, 100)
	floor_mesh.mesh = plane
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color("1e242a")
	floor_mat.roughness = 0.52
	floor_mat.metallic = 0.16
	floor_mesh.material_override = floor_mat
	floor_mesh.position = Vector3(-0.75, 0.0, -5.0)
	viewport.add_child(floor_mesh)

	# Concrete panel expansion seams (subtle dark lines creating realistic tarmac slabs)
	var seam_mat = StandardMaterial3D.new()
	seam_mat.albedo_color = Color("101418")
	seam_mat.roughness = 0.90
	for x_seam in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		var s_mesh = MeshInstance3D.new()
		var sm = BoxMesh.new()
		sm.size = Vector3(0.04, 0.002, 50.0)
		s_mesh.mesh = sm
		s_mesh.material_override = seam_mat
		s_mesh.position = Vector3(x_seam, 0.001, -5.0)
		viewport.add_child(s_mesh)

	for z_seam in [4.0, 0.0, -4.0, -8.0, -12.0, -16.0, -20.0]:
		var s_mesh_z = MeshInstance3D.new()
		var sm_z = BoxMesh.new()
		sm_z.size = Vector3(50.0, 0.002, 0.04)
		s_mesh_z.mesh = sm_z
		s_mesh_z.material_override = seam_mat
		s_mesh_z.position = Vector3(-0.75, 0.001, z_seam)
		viewport.add_child(s_mesh_z)

	# Ground contact shadow directly underneath helicopter resting zone
	var contact_shadow = MeshInstance3D.new()
	var c_mesh = BoxMesh.new()
	c_mesh.size = Vector3(5.6, 0.002, 3.2)
	contact_shadow.mesh = c_mesh
	var shadow_mat = StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0, 0, 0, 0.40)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.roughness = 1.0
	contact_shadow.material_override = shadow_mat
	contact_shadow.position = Vector3(-0.75, 0.0015, 0.0)
	viewport.add_child(contact_shadow)

	# 2. Painted Yellow Taxiway & Apron Guide Lines
	var yellow_mat = StandardMaterial3D.new()
	yellow_mat.albedo_color = Color("e09c15")
	yellow_mat.roughness = 0.48
	yellow_mat.metallic = 0.04

	# Diagonal taxiway centerline stripe (angled across the hangar floor towards the left background)
	var center_stripe = MeshInstance3D.new()
	var cs_mesh = BoxMesh.new()
	cs_mesh.size = Vector3(0.24, 0.005, 32.0)
	center_stripe.mesh = cs_mesh
	center_stripe.material_override = yellow_mat
	center_stripe.position = Vector3(0.8, 0.003, -2.0)
	center_stripe.rotation.y = deg_to_rad(-24.0)
	viewport.add_child(center_stripe)

	# Parallel taxiway guide line
	var parallel_stripe = MeshInstance3D.new()
	var ps_mesh = BoxMesh.new()
	ps_mesh.size = Vector3(0.16, 0.005, 28.0)
	parallel_stripe.mesh = ps_mesh
	parallel_stripe.material_override = yellow_mat
	parallel_stripe.position = Vector3(1.7, 0.003, -1.5)
	parallel_stripe.rotation.y = deg_to_rad(-24.0)
	viewport.add_child(parallel_stripe)

	# Transverse stop bar in front of parking bay
	var stop_line = MeshInstance3D.new()
	var sl_mesh = BoxMesh.new()
	sl_mesh.size = Vector3(4.2, 0.005, 0.24)
	stop_line.mesh = sl_mesh
	stop_line.material_override = yellow_mat
	stop_line.position = Vector3(-0.75, 0.003, -2.6)
	viewport.add_child(stop_line)

	# Diagonal safety hashes along left apron boundary
	for i in range(10):
		var hash_mark_l = MeshInstance3D.new()
		var hm_mesh_l = BoxMesh.new()
		hm_mesh_l.size = Vector3(0.18, 0.005, 2.2)
		hash_mark_l.mesh = hm_mesh_l
		hash_mark_l.material_override = yellow_mat
		hash_mark_l.position = Vector3(-3.8 - i * 0.35, 0.003, 1.8 - i * 1.35)
		hash_mark_l.rotation.y = deg_to_rad(-36.0)
		viewport.add_child(hash_mark_l)

	# Diagonal safety hashes along right apron boundary
	for i in range(8):
		var hash_mark_r = MeshInstance3D.new()
		var hm_mesh_r = BoxMesh.new()
		hm_mesh_r.size = Vector3(0.18, 0.005, 2.2)
		hash_mark_r.mesh = hm_mesh_r
		hash_mark_r.material_override = yellow_mat
		hash_mark_r.position = Vector3(4.2 + i * 0.35, 0.003, 1.0 - i * 1.5)
		hash_mark_r.rotation.y = deg_to_rad(36.0)
		viewport.add_child(hash_mark_r)

	# 3. Hangar Wall & Steel Structure in Background (Z = -14.0 is directly behind the helicopter in camera view!)
	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color("14181f")
	wall_mat.roughness = 0.70
	wall_mat.metallic = 0.40

	var back_wall = MeshInstance3D.new()
	var bw_mesh = BoxMesh.new()
	bw_mesh.size = Vector3(50.0, 13.0, 0.5)
	back_wall.mesh = bw_mesh
	back_wall.material_override = wall_mat
	back_wall.position = Vector3(-0.75, 6.5, -14.0)
	viewport.add_child(back_wall)

	# Lower steel kickplate / bumper curb along base of back wall
	var base_curb = MeshInstance3D.new()
	var bc_mesh = BoxMesh.new()
	bc_mesh.size = Vector3(50.0, 0.8, 0.3)
	base_curb.mesh = bc_mesh
	var curb_mat = StandardMaterial3D.new()
	curb_mat.albedo_color = Color("1b2128")
	curb_mat.metallic = 0.60
	curb_mat.roughness = 0.40
	base_curb.material_override = curb_mat
	base_curb.position = Vector3(-0.75, 0.4, -13.7)
	viewport.add_child(base_curb)

	var steel_mat = StandardMaterial3D.new()
	steel_mat.albedo_color = Color("1a2026")
	steel_mat.metallic = 0.75
	steel_mat.roughness = 0.35

	# Steel I-beam structural columns along the back wall
	for x_pos in [-12.0, -6.5, -1.0, 4.5, 10.0]:
		var col = MeshInstance3D.new()
		var col_mesh = BoxMesh.new()
		col_mesh.size = Vector3(0.55, 13.0, 0.55)
		col.mesh = col_mesh
		col.material_override = steel_mat
		col.position = Vector3(x_pos, 6.5, -13.6)
		viewport.add_child(col)

		# Column footing base plate
		var footing = MeshInstance3D.new()
		var foot_mesh = BoxMesh.new()
		foot_mesh.size = Vector3(1.0, 0.30, 1.0)
		footing.mesh = foot_mesh
		footing.material_override = steel_mat
		footing.position = Vector3(x_pos, 0.15, -13.45)
		viewport.add_child(footing)

		# Front flange lip of the I-beam
		var flange = MeshInstance3D.new()
		var fl_mesh = BoxMesh.new()
		fl_mesh.size = Vector3(0.75, 13.0, 0.08)
		flange.mesh = fl_mesh
		flange.material_override = steel_mat
		flange.position = Vector3(x_pos, 6.5, -13.3)
		viewport.add_child(flange)

	# Warm incandescent workshop lamp fixtures mounted on columns
	for x_pos in [-6.5, -1.0, 4.5]:
		var lamp_arm = MeshInstance3D.new()
		var la_mesh = BoxMesh.new()
		la_mesh.size = Vector3(0.12, 0.12, 0.45)
		lamp_arm.mesh = la_mesh
		lamp_arm.material_override = steel_mat
		lamp_arm.position = Vector3(x_pos, 5.0, -13.0)
		viewport.add_child(lamp_arm)

		var lamp_shade = MeshInstance3D.new()
		var shade_mesh = CylinderMesh.new()
		shade_mesh.top_radius = 0.08
		shade_mesh.bottom_radius = 0.28
		shade_mesh.height = 0.18
		lamp_shade.mesh = shade_mesh
		lamp_shade.material_override = steel_mat
		lamp_shade.position = Vector3(x_pos, 4.88, -12.8)
		viewport.add_child(lamp_shade)

		var lamp_bulb = MeshInstance3D.new()
		var b_cyl = CylinderMesh.new()
		b_cyl.top_radius = 0.14
		b_cyl.bottom_radius = 0.14
		b_cyl.height = 0.04
		lamp_bulb.mesh = b_cyl
		var glow_mat = StandardMaterial3D.new()
		glow_mat.albedo_color = Color("ffaa33")
		glow_mat.emission_enabled = true
		glow_mat.emission = Color("ffaa33")
		glow_mat.emission_energy_multiplier = 2.5
		lamp_bulb.material_override = glow_mat
		lamp_bulb.position = Vector3(x_pos, 4.80, -12.8)
		viewport.add_child(lamp_bulb)

		var lamp_spot = SpotLight3D.new()
		lamp_spot.light_color = Color("ff9922")
		lamp_spot.light_energy = 2.6
		lamp_spot.spot_range = 14.0
		lamp_spot.spot_angle = 55.0
		lamp_spot.spot_attenuation = 1.15
		lamp_spot.position = Vector3(x_pos, 4.75, -12.8)
		lamp_spot.rotation_degrees = Vector3(-75.0, 0.0, 0.0)
		viewport.add_child(lamp_spot)

	# Horizontal steel crane support girder spanning the back wall
	var girder = MeshInstance3D.new()
	var g_mesh = BoxMesh.new()
	g_mesh.size = Vector3(50.0, 0.45, 0.45)
	girder.mesh = g_mesh
	girder.material_override = steel_mat
	girder.position = Vector3(-0.75, 6.2, -13.4)
	viewport.add_child(girder)

	# Overhead ceiling cross beam
	var ceiling_beam = MeshInstance3D.new()
	var cb_mesh = BoxMesh.new()
	cb_mesh.size = Vector3(42.0, 0.50, 0.50)
	ceiling_beam.mesh = cb_mesh
	ceiling_beam.material_override = steel_mat
	ceiling_beam.position = Vector3(-0.75, 8.2, -7.5)
	viewport.add_child(ceiling_beam)

	# 4. Stacked Military Cargo Crates & Shelving in Left Background (Positioned at Z = -4.5 to -7.5)
	var crate_olive = StandardMaterial3D.new()
	crate_olive.albedo_color = Color("222b1e")
	crate_olive.roughness = 0.82
	crate_olive.metallic = 0.12

	var crate_grey = StandardMaterial3D.new()
	crate_grey.albedo_color = Color("1c2228")
	crate_grey.roughness = 0.78
	crate_grey.metallic = 0.20

	var strap_mat = StandardMaterial3D.new()
	strap_mat.albedo_color = Color("12161a")
	strap_mat.metallic = 0.85
	strap_mat.roughness = 0.35

	var crate1 = MeshInstance3D.new()
	var c1_mesh = BoxMesh.new()
	c1_mesh.size = Vector3(2.2, 1.25, 1.6)
	crate1.mesh = c1_mesh
	crate1.material_override = crate_olive
	crate1.position = Vector3(-5.2, 0.625, -4.8)
	crate1.rotation.y = deg_to_rad(14.0)
	viewport.add_child(crate1)

	for sy in [0.35, 0.90]:
		var c1_strap = MeshInstance3D.new()
		var st_mesh = BoxMesh.new()
		st_mesh.size = Vector3(2.23, 0.06, 1.63)
		c1_strap.mesh = st_mesh
		c1_strap.material_override = strap_mat
		c1_strap.position = Vector3(-5.2, sy, -4.8)
		c1_strap.rotation.y = deg_to_rad(14.0)
		viewport.add_child(c1_strap)

	var crate2 = MeshInstance3D.new()
	var c2_mesh = BoxMesh.new()
	c2_mesh.size = Vector3(1.8, 1.15, 1.4)
	crate2.mesh = c2_mesh
	crate2.material_override = crate_grey
	crate2.position = Vector3(-6.9, 0.575, -4.2)
	crate2.rotation.y = deg_to_rad(-8.0)
	viewport.add_child(crate2)

	var crate3 = MeshInstance3D.new()
	var c3_mesh = BoxMesh.new()
	c3_mesh.size = Vector3(1.6, 0.95, 1.3)
	crate3.mesh = c3_mesh
	crate3.material_override = crate_olive
	crate3.position = Vector3(-5.4, 1.725, -4.9)
	crate3.rotation.y = deg_to_rad(8.0)
	viewport.add_child(crate3)

	var crate4 = MeshInstance3D.new()
	var c4_mesh = BoxMesh.new()
	c4_mesh.size = Vector3(2.4, 1.35, 1.7)
	crate4.mesh = c4_mesh
	crate4.material_override = crate_grey
	crate4.position = Vector3(-4.0, 0.675, -7.5)
	crate4.rotation.y = deg_to_rad(20.0)
	viewport.add_child(crate4)

	# Industrial metal storage rack frame on far left
	for rx in [-7.2, -9.4]:
		for rz in [-6.2, -7.0]:
			var post = MeshInstance3D.new()
			var p_mesh = BoxMesh.new()
			p_mesh.size = Vector3(0.08, 3.8, 0.08)
			post.mesh = p_mesh
			post.material_override = steel_mat
			post.position = Vector3(rx, 1.9, rz)
			viewport.add_child(post)

	for sy in [0.8, 1.9, 3.0]:
		var shelf = MeshInstance3D.new()
		var sh_mesh = BoxMesh.new()
		sh_mesh.size = Vector3(2.4, 0.06, 0.9)
		shelf.mesh = sh_mesh
		shelf.material_override = steel_mat
		shelf.position = Vector3(-8.3, sy, -6.6)
		viewport.add_child(shelf)

	var shelf_box = MeshInstance3D.new()
	var sb_mesh = BoxMesh.new()
	sb_mesh.size = Vector3(0.8, 0.55, 0.6)
	shelf_box.mesh = sb_mesh
	shelf_box.material_override = crate_olive
	shelf_box.position = Vector3(-8.1, 2.22, -6.6)
	shelf_box.rotation.y = deg_to_rad(6.0)
	viewport.add_child(shelf_box)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var controls = get_node_or_null("/root/InputManager")
	if preview_hint:
		preview_hint.text = "RIGHT STICK ROTATE / LT-RT ZOOM / A SELECT / B BACK" if controls and controls.controller_active else "DRAG TO ROTATE   /   SCROLL TO ZOOM"
	if controls and controls.controller_active and not is_deploying:
		var stick: Vector2 = controls.aim_stick()
		if turntable_root and absf(stick.x) > 0.01:
			if _selection_tween and _selection_tween.is_running(): _selection_tween.kill()
			rot_velocity = 0.0
			turntable_root.rotate_y(-stick.x * delta * 2.0)
			if stage_viewport: stage_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		var zoom: float = Input.get_action_strength("paint_salvo") - Input.get_action_strength("fire_primary")
		target_fov = clampf(target_fov + zoom * delta * 24.0, MIN_FOV, MAX_FOV)

	# Redraw the isolated preview only while it changes, rather than rendering
	# the static hangar continuously (including while an ancestor is hidden).
	var changing := is_dragging or absf(rot_velocity) > 0.0005
	changing = changing or (_selection_tween != null and _selection_tween.is_running())
	changing = changing or (stage_camera != null and absf(stage_camera.fov - target_fov) > 0.05)
	if changing and stage_viewport:
		stage_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	# Turntable inertial rotation
	if not is_dragging and abs(rot_velocity) > 0.0005 and turntable_root:
		turntable_root.rotate_y(rot_velocity * delta)
		rot_velocity = lerp(rot_velocity, 0.0, delta * 5.0)

	# Smooth camera FOV zoom
	if stage_camera and abs(stage_camera.fov - target_fov) > 0.05:
		stage_camera.fov = lerp(stage_camera.fov, target_fov, delta * 8.0)

# ------------------------------------------------------------------------------
# UI Layout Construction (Pixel-Faithful, Aligned Grid & Responsive)
# ------------------------------------------------------------------------------
func _build_ui_layout() -> void:
	var pixel_font = preload("res://src/effects/floating_text.gd").get_pixel_font()
	var background := ColorRect.new()
	background.name = "HangarBackdrop"
	background.color = Color("070d13")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	stage_container = SubViewportContainer.new()
	stage_container.name = "StageContainer"
	stage_container.stretch = true
	stage_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage_container)
	var layout := Control.new()
	layout.name = "UIOverlay"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layout)

	var header := VBoxContainer.new()
	header.name = "HeaderBox"
	header.position = Vector2(24, 25)
	header.size = Vector2(744, 70)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)
	header.add_child(_menu_label("SELECT AIRCRAFT", 24, Color("f0f3ed")))
	header.add_child(_menu_label("TACTICAL AIR COMMAND / SORTIE PREPARATION", 10, Color("83a1ac")))

	var wallet := PanelContainer.new()
	wallet.name = "TopRightStatus"
	wallet.position = Vector2(792, 24)
	wallet.size = Vector2(464, 70)
	wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet.add_theme_stylebox_override("panel", _create_rounded_panel(Color("0e1821"), Color("293b48"), 1, 5))
	layout.add_child(wallet)
	var wallet_margin := _menu_margin(16, 12)
	wallet.add_child(wallet_margin)
	var wallet_grid := HBoxContainer.new()
	wallet_grid.add_theme_constant_override("separation", 18)
	wallet_margin.add_child(wallet_grid)
	for item in [["CREDITS", "wallet"], ["SALVAGE", "salvage"], ["HIGH SCORE", "record"]]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 8)
		wallet_grid.add_child(column)
		column.add_child(_menu_label(item[0], 8, Color("8da5b2")))
		var value := _menu_label("0", 11, Color("ffd451") if item[1] == "wallet" else Color("e7f2ef"))
		column.add_child(value)
		match item[1]:
			"wallet": wallet_label = value
			"salvage": salvage_label = value
			"record": record_label = value

	var preview_frame := PanelContainer.new()
	preview_frame.name = "PreviewFrame"
	preview_frame.position = Vector2(24, 116)
	preview_frame.size = Vector2(744, 464)
	preview_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.add_theme_stylebox_override("panel", _create_rounded_panel(Color.TRANSPARENT, Color("293b48"), 1, 5))
	layout.add_child(preview_frame)
	var preview_caption := _menu_label("AIRFRAME PREVIEW", 9, Color("9ab6be"))
	preview_caption.position = Vector2(44, 136)
	layout.add_child(preview_caption)
	var hint := _menu_label("DRAG TO ROTATE   /   SCROLL TO ZOOM", 9, Color("a5bbc2"))
	preview_hint = hint
	hint.position = Vector2(44, 551)
	layout.add_child(hint)

	var dossier := PanelContainer.new()
	dossier.name = "RightDossierCard"
	dossier.position = Vector2(792, 116)
	dossier.size = Vector2(464, 512)
	dossier.add_theme_stylebox_override("panel", _create_rounded_panel(Color("0d1720"), Color("293e4c"), 1, 5))
	layout.add_child(dossier)
	var padding := _menu_margin(20, 18)
	dossier.add_child(padding)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 12)
	padding.add_child(details)
	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", 10)
	details.add_child(identity)
	aircraft_title = _menu_label("AH-64 APACHE", 20, Color.WHITE)
	identity.add_child(aircraft_title)
	aircraft_role = _menu_label("", 9, Color("ffd451"))
	identity.add_child(aircraft_role)
	aircraft_status = _menu_label("", 9, Color("62c5b7"))
	aircraft_status.hide()
	identity.add_child(aircraft_status)
	aircraft_doctrine = _menu_label("", 10, Color("a6bac4"))
	aircraft_doctrine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aircraft_doctrine.custom_minimum_size.y = 32
	identity.add_child(aircraft_doctrine)
	details.add_child(HSeparator.new())
	var stats := VBoxContainer.new()
	stats.name = "PerformanceRows"
	stats.add_theme_constant_override("separation", 10)
	details.add_child(stats)
	var rows := [
		["CRUISE SPEED", Color("38c6d4")], ["HULL", Color("e67e6a")],
		["FUEL", Color("659bde")], ["TURN AGILITY", Color("52cda3")],
		["WEAPON DAMAGE", Color("dfc674")]
	]
	var controls: Array[Dictionary] = []
	for row in rows:
		controls.append(_create_stat_row(stats, pixel_font, row[0], row[1]))
	speed_label = controls[0].label
	speed_bar = controls[0].bar
	hull_label = controls[1].label
	hull_bar = controls[1].bar
	fuel_label = controls[2].label
	fuel_bar = controls[2].bar
	handling_label = controls[3].label
	handling_bar = controls[3].bar
	damage_label = controls[4].label
	damage_bar = controls[4].bar
	details.add_child(HSeparator.new())
	var loadout := GridContainer.new()
	loadout.name = "LoadoutGrid"
	loadout.columns = 2
	loadout.add_theme_constant_override("h_separation", 14)
	loadout.add_theme_constant_override("v_separation", 9)
	details.add_child(loadout)
	primary_val = _add_grid_loadout_row(loadout, pixel_font, "PRIMARY", "", Color("e6eeed"))
	secondary_val = _add_grid_loadout_row(loadout, pixel_font, "ORDNANCE", "", Color("e6eeed"))
	special_val = _add_grid_loadout_row(loadout, pixel_font, "SPECIAL", "", Color("68cbbb"))
	super_val = _add_grid_loadout_row(loadout, pixel_font, "SUPER", "", Color("ffd451"))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(spacer)
	biome_selector = OptionButton.new()
	biome_selector.name = "SortieBiomeSelector"
	biome_selector.add_item("TOWN / Heavy Gunship")
	biome_selector.add_item("DESERT CANYON / Mega Crawler")
	biome_selector.add_item("HARBOR NIGHT / Airborne Titan")
	biome_selector.add_theme_font_size_override("font_size", 13)
	biome_selector.custom_minimum_size.y = 34
	var biome_ids := ["town", "desert", "harbor"]
	biome_selector.select(maxi(0, biome_ids.find(get_node("/root/GameManager").selected_biome)))
	biome_selector.item_selected.connect(func(index: int): get_node("/root/GameManager").selected_biome = biome_ids[index])
	details.add_child(biome_selector)
	deploy_btn = _menu_button("LAUNCH SORTIE   [F]", 14, Color("f5c747"), Color("121b20"))
	deploy_btn.name = "DeployBtn"
	deploy_btn.custom_minimum_size.y = 48
	deploy_btn.pressed.connect(_on_deploy_pressed)
	details.add_child(deploy_btn)

	var carousel := HBoxContainer.new()
	carousel.name = "BottomRow"
	carousel.position = Vector2(24, 600)
	carousel.size = Vector2(744, 96)
	carousel.add_theme_constant_override("separation", 8)
	layout.add_child(carousel)
	prev_btn = _menu_button("<", 12)
	prev_btn.custom_minimum_size.x = 32
	prev_btn.pressed.connect(_on_prev_pressed)
	carousel.add_child(prev_btn)
	card_buttons.clear()
	card_names.clear()
	card_tags.clear()
	var cards := [
		["AH-64 APACHE", "BALANCED", "res://assets/ui/thumb_apache.png"],
		["RAH-66 NIGHTHAWK", "FAST / STEALTH", "res://assets/ui/thumb_nighthawk.png"],
		["MI-28 WARLOCK", "HEAVY / ARMORED", "res://assets/ui/thumb_warlock.png"]
	]
	for i in range(cards.size()):
		var card := _menu_button("", 9)
		card.name = "Card_" + str(i)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		carousel.add_child(card)
		var inner := MarginContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right"]:
			inner.add_theme_constant_override("margin_" + side, 8)
		card.add_child(inner)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		inner.add_child(row)
		var thumbnail := TextureRect.new()
		thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumbnail.custom_minimum_size = Vector2(42, 38)
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(cards[i][2]):
			thumbnail.texture = load(cards[i][2])
		row.add_child(thumbnail)
		var text := VBoxContainer.new()
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		text.add_theme_constant_override("separation", 10)
		row.add_child(text)
		var name_label := _menu_label(cards[i][0], 9, Color("e4eef0"))
		name_label.clip_text = true
		text.add_child(name_label)
		card_names.append(name_label)
		var tag := _menu_label(cards[i][1], 8, Color("8ba9b4"))
		text.add_child(tag)
		card_tags.append(tag)
		card.pressed.connect(select_aircraft.bind(i))
		card.focus_entered.connect(select_aircraft.bind(i))
		card_buttons.append(card)
	next_btn = _menu_button(">", 12)
	next_btn.custom_minimum_size.x = 32
	next_btn.pressed.connect(_on_next_pressed)
	carousel.add_child(next_btn)
	var utilities := HBoxContainer.new()
	utilities.name = "UtilityButtons"
	utilities.position = Vector2(792, 648)
	utilities.size = Vector2(464, 48)
	utilities.add_theme_constant_override("separation", 12)
	layout.add_child(utilities)
	back_btn = _menu_button("BACK [ESC]", 10)
	back_btn.name = "BackBtn"
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(_on_back_pressed)
	utilities.add_child(back_btn)
	armory_btn = _menu_button("UPGRADE HANGAR [H]", 10)
	armory_btn.name = "ArmoryBtn"
	armory_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	armory_btn.pressed.connect(_on_armory_pressed)
	utilities.add_child(armory_btn)
	_update_wallet_display()
	_setup_focus_navigation()
	resized.connect(_fit_aircraft_layout)
	_fit_aircraft_layout()

func _fit_aircraft_layout() -> void:
	var layout := get_node_or_null("UIOverlay") as Control
	if not layout:
		return
	var fit := minf(size.x / 1280.0, size.y / 720.0)
	layout.size = Vector2(1280, 720)
	layout.scale = Vector2.ONE * fit
	layout.position = (size - Vector2(1280, 720) * fit) * 0.5
	stage_container.position = layout.position + Vector2(24, 116) * fit
	stage_container.size = Vector2(744, 464) * fit
	if stage_viewport:
		stage_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func _menu_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", preload("res://src/effects/floating_text.gd").get_pixel_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _menu_margin(horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, horizontal)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, vertical)
	return margin

func _menu_button(text: String, font_size: int, fill: Color = Color("10202a"), ink: Color = Color("dce9eb")) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", preload("res://src/effects/floating_text.gd").get_pixel_font())
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_stylebox_override("normal", _create_rounded_panel(fill, Color("344b58"), 1, 5))
	button.add_theme_stylebox_override("hover", _create_rounded_panel(fill.lightened(0.12), Color("84b8bf"), 1, 5))
	button.add_theme_stylebox_override("pressed", _create_rounded_panel(fill.darkened(0.12), Color("ffd451"), 1, 5))
	button.add_theme_stylebox_override("focus", _create_rounded_panel(Color.TRANSPARENT, Color("ffd451"), 2, 5))
	return button

func _add_grid_loadout_row(parent: GridContainer, _font: Font, label_text: String, default_val: String, val_color: Color, tag_color: Color = Color("8da6b2")) -> Label:
	var tag := _menu_label(label_text, 9, tag_color)
	tag.custom_minimum_size.x = 80
	parent.add_child(tag)
	var value := _menu_label(default_val, 9, val_color)
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(value)
	return value

func _create_stat_row(parent: VBoxContainer, _font: Font, label_text: String, fill_color: Color) -> Dictionary:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)
	var row := HBoxContainer.new()
	section.add_child(row)
	var title := _menu_label(label_text, 9, Color("9ab4be"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var value := _menu_label("---", 10, Color("eef4ed"))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 5
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("1c2b35")
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override("fill", fill)
	section.add_child(bar)
	return {"label": value, "bar": bar}

func _setup_focus_navigation() -> void:
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
		btn.focus_neighbor_bottom = biome_selector.get_path()

	prev_btn.focus_neighbor_right = card_buttons[0].get_path()
	prev_btn.focus_neighbor_bottom = deploy_btn.get_path()
	next_btn.focus_neighbor_left = card_buttons[card_buttons.size() - 1].get_path()
	next_btn.focus_neighbor_right = back_btn.get_path()

	back_btn.focus_neighbor_left = next_btn.get_path()
	back_btn.focus_neighbor_right = armory_btn.get_path()
	back_btn.focus_neighbor_top = deploy_btn.get_path()

	armory_btn.focus_neighbor_left = back_btn.get_path()
	armory_btn.focus_neighbor_top = deploy_btn.get_path()

	biome_selector.focus_neighbor_top = card_buttons[current_aircraft_idx].get_path()
	biome_selector.focus_neighbor_bottom = deploy_btn.get_path()
	deploy_btn.focus_neighbor_top = biome_selector.get_path()
	deploy_btn.focus_neighbor_bottom = back_btn.get_path()

# Direct GUI input on main VehicleSelectionMenu for rotating and zooming 3D showroom
func _handle_mouse_drag_motion(diff_x: float) -> void:
	if turntable_root:
		turntable_root.rotate_y(diff_x * 0.010)
		var dt = maxf(get_process_delta_time(), 0.001)
		rot_velocity = (diff_x * 0.010) / dt

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			is_dragging = true
			if _selection_tween and _selection_tween.is_valid():
				_selection_tween.kill()
			drag_start_x = event.position.x
			rot_velocity = 0.0
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_fov = clampf(target_fov - 2.5, MIN_FOV, MAX_FOV)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_fov = clampf(target_fov + 2.5, MIN_FOV, MAX_FOV)
			accept_event()
	elif event is InputEventMouseMotion and is_dragging:
		_handle_mouse_drag_motion(event.relative.x)
		accept_event()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if is_dragging and event is InputEventMouseMotion:
		_handle_mouse_drag_motion(event.relative.x)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		is_dragging = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible or (has_node("/root/UIFlow") and get_node("/root/UIFlow").busy):
		return

	if is_dragging and event is InputEventMouseMotion:
		_handle_mouse_drag_motion(event.relative.x)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			is_dragging = true
			if _selection_tween and _selection_tween.is_valid():
				_selection_tween.kill()
			drag_start_x = event.position.x
			rot_velocity = 0.0
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_fov = clampf(target_fov - 2.5, MIN_FOV, MAX_FOV)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_fov = clampf(target_fov + 2.5, MIN_FOV, MAX_FOV)
			get_viewport().set_input_as_handled()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			_on_deploy_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_H:
			_on_armory_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_on_back_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_A or event.keycode == KEY_LEFT:
			_on_prev_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			_on_next_pressed()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_on_prev_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_on_next_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _create_rounded_panel(bg: Color, border: Color, width: int = 1, radius: int = 4) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	return sb

func _create_panel_style(bg: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	return _create_rounded_panel(bg, border, width, 2)

func _create_line_style(color: Color) -> StyleBoxLine:
	var sl = StyleBoxLine.new()
	sl.color = color
	sl.thickness = 1
	return sl
