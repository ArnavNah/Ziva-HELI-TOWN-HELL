class_name CombatHUD
extends CanvasLayer

## CombatHUD â€” Layered combat interface implementing survival, task, and run progress layers (Page 24).
## Displays real-time reticle, survival telemetry, missile lock warnings, and mission tracking.

@export var player_helicopter: CharacterBody3D

# Survival Layer
@onready var hull_bar: ProgressBar = get_node_or_null("SurvivalLayer/HullBar")
@onready var fuel_bar: ProgressBar = get_node_or_null("SurvivalLayer/FuelBar")
@onready var ammo_label: Label = get_node_or_null("SurvivalLayer/AmmoLabel")
@onready var flare_label: Label = get_node_or_null("SurvivalLayer/FlareLabel")
@onready var super_bar: ProgressBar = get_node_or_null("SurvivalLayer/SuperBar")

# Task Layer
@onready var mission_label: Label = get_node_or_null("TaskLayer/MissionLabel")
@onready var cargo_label: Label = get_node_or_null("TaskLayer/CargoLabel")

# Run Progress Layer
@onready var wave_label: Label = get_node_or_null("ProgressLayer/WaveLabel")
@onready var score_label: Label = get_node_or_null("ProgressLayer/ScoreLabel")
@onready var combo_label: Label = get_node_or_null("ProgressLayer/ComboLabel")
@onready var credits_label: Label = get_node_or_null("ProgressLayer/CreditsLabel")

# Dynamic Tactical Elements
var lock_warning_banner: Label
var border_warning_banner: VBoxContainer
var reticle_widget: Control
var is_turret_in_arc: bool = true
var is_turret_blocked: bool = false
var barrel_screen_pos: Vector2 = Vector2.ZERO
var has_barrel_pos: bool = false
var targeting_overlay: Control
var alert_flash_timer: float = 0.0
var is_border_warning: bool = false
var border_edge_dist: float = 0.0
var telemetry_timer: float = 0.0
var survival_overlay: Control

# Tactical Low-Health & Hit Trauma Blood Vignette Overlay
var blood_overlay: ColorRect
var blood_material: ShaderMaterial
var blood_intensity: float = 0.0
var target_blood_intensity: float = 0.0
var hit_flash_intensity: float = 0.0
var blood_pulse_speed: float = 3.8
var debug_telemetry: Control = null
var damage_indicator: Control
var missile_scan_timer := 0.0
var missile_alarm_timer := 0.0
var incoming_missiles := 0
var missile_urgent := false
var controller_hint: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_survival_hud()
	controller_hint = Label.new()
	controller_hint.name = "ControllerHint"
	controller_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controller_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controller_hint.offset_top = -24
	controller_hint.offset_bottom = -5
	controller_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controller_hint.add_theme_font_size_override("font_size", 12)
	controller_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	controller_hint.add_theme_constant_override("outline_size", 3)
	add_child(controller_hint)
	_setup_tactical_overlays()
	damage_indicator = preload("res://src/ui/damage_indicator.gd").new()
	damage_indicator.player = player_helicopter
	add_child(damage_indicator)
	add_child(preload("res://src/ui/boss_tracker.gd").new())
	_apply_label_outlines()
	debug_telemetry = preload("res://src/ui/debug_telemetry_overlay.gd").new()
	add_child(debug_telemetry)
	if has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		bus.border_warning_changed.connect(_on_border_warning_changed)
		bus.player_damaged.connect(_on_player_damaged)
		bus.player_healed.connect(_on_player_healed)
		bus.player_died.connect(_on_player_died)

func _apply_label_outlines() -> void:
	var labels: Array[Label] = [
		ammo_label, flare_label, mission_label, cargo_label,
		wave_label, score_label, combo_label, credits_label
	]
	for l in labels:
		if l and is_instance_valid(l):
			l.add_theme_constant_override("outline_size", 2)
			l.add_theme_color_override("font_outline_color", Color(0.08, 0.10, 0.14, 0.95))

func _setup_tactical_overlays() -> void:
	# 0. Professional Tactical Blood Vignette Overlay (Low Health & Hit Trauma)
	blood_overlay = ColorRect.new()
	blood_overlay.name = "BloodVignetteOverlay"
	blood_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blood_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	blood_overlay.offset_left = 0
	blood_overlay.offset_top = 0
	blood_overlay.offset_right = 0
	blood_overlay.offset_bottom = 0
	
	var blood_shader = preload("res://src/shaders/blood_vignette.gdshader")
	blood_material = ShaderMaterial.new()
	blood_material.shader = blood_shader
	blood_material.set_shader_parameter("blood_intensity", 0.0)
	blood_material.set_shader_parameter("pulse_speed", 3.8)
	blood_material.set_shader_parameter("hit_flash", 0.0)
	blood_overlay.material = blood_material
	blood_overlay.visible = false
	add_child(blood_overlay)
	move_child(blood_overlay, 0) # Keep behind HUD text, crosshairs, and radar

	# 1. In-World Target Lock Bracket Overlay (Slice B)
	targeting_overlay = Control.new()
	targeting_overlay.name = "TargetingOverlay"
	targeting_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	targeting_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	targeting_overlay.draw.connect(_on_targeting_overlay_draw)
	add_child(targeting_overlay)

	# 2. Missile Alert Warning Banner
	lock_warning_banner = Label.new()
	lock_warning_banner.name = "LockWarningBanner"
	lock_warning_banner.text = "[ ! WARNING: SAM MISSILE LOCK DETECTED â€” DEPLOY FLARES (F/C) ! ]"
	lock_warning_banner.add_theme_font_size_override("font_size", 12)
	lock_warning_banner.add_theme_font_override("font", preload("res://src/effects/floating_text.gd").get_pixel_font())
	lock_warning_banner.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
	lock_warning_banner.add_theme_color_override("font_outline_color", Color("10191f"))
	lock_warning_banner.add_theme_constant_override("outline_size", 4)
	lock_warning_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_warning_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lock_warning_banner.offset_top = 92.0
	lock_warning_banner.offset_bottom = 118.0
	lock_warning_banner.visible = false
	add_child(lock_warning_banner)

	# 3. Airspace Boundary Warning Banner (Slice A)
	border_warning_banner = VBoxContainer.new()
	border_warning_banner.name = "BorderWarningBanner"
	border_warning_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	border_warning_banner.offset_left = -260.0
	border_warning_banner.offset_right = 260.0
	border_warning_banner.offset_top = 90.0
	border_warning_banner.offset_bottom = 135.0
	border_warning_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	border_warning_banner.visible = false

	var b_title = Label.new()
	b_title.name = "Title"
	b_title.text = "[ ! ] WARNING: RESTRICTED AIRSPACE [ ! ]"
	b_title.add_theme_font_size_override("font_size", 12)
	b_title.add_theme_font_override("font", preload("res://src/effects/floating_text.gd").get_pixel_font())
	b_title.add_theme_color_override("font_color", Color(1.0, 0.65, 0.1, 1.0))
	b_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	border_warning_banner.add_child(b_title)

	var b_sub = Label.new()
	b_sub.name = "Subtitle"
	b_sub.text = "RETURN TO COMBAT ZONE"
	b_sub.add_theme_font_size_override("font_size", 9)
	b_sub.add_theme_font_override("font", preload("res://src/effects/floating_text.gd").get_pixel_font())
	b_sub.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
	b_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	border_warning_banner.add_child(b_sub)

	add_child(border_warning_banner)

	# 4. Dynamic Chin-Turret Crosshair Reticle
	reticle_widget = Control.new()
	reticle_widget.name = "ReticleWidget"
	reticle_widget.custom_minimum_size = Vector2(32, 32)
	reticle_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle_widget.draw.connect(_on_reticle_draw)
	add_child(reticle_widget)

func _on_border_warning_changed(is_warning: bool, _return_dir: Vector3, distance_to_edge: float) -> void:
	is_border_warning = is_warning
	border_edge_dist = distance_to_edge

func _on_player_damaged(curr: float, max_hp: float, dmg: float) -> void:
	# Instant hit flash trauma kick on taking impact or weapon damage
	var flash_kick = clampf((dmg / max(1.0, max_hp)) * 3.5 + 0.35, 0.4, 1.0)
	hit_flash_intensity = maxf(hit_flash_intensity, flash_kick)
	var safe_curr = maxf(0.0, curr)
	if hull_bar:
		hull_bar.max_value = max_hp
		hull_bar.value = safe_curr
	if survival_overlay:
		if survival_overlay.hp_label:
			survival_overlay.hp_label.text = "%d/%d" % [maxi(0, int(safe_curr)), int(max_hp)]
		if survival_overlay.hull_bar:
			survival_overlay.hull_bar.max_value = max_hp
			survival_overlay.hull_bar.value = safe_curr

func _on_player_healed(curr: float, max_hp: float) -> void:
	# Instantly clear hit flash trauma on repair
	hit_flash_intensity = 0.0
	var safe_curr = maxf(0.0, curr)
	if hull_bar:
		hull_bar.max_value = max_hp
		hull_bar.value = safe_curr
	if survival_overlay:
		if survival_overlay.hp_label:
			survival_overlay.hp_label.text = "%d/%d" % [maxi(0, int(safe_curr)), int(max_hp)]
		if survival_overlay.hull_bar:
			survival_overlay.hull_bar.max_value = max_hp
			survival_overlay.hull_bar.value = safe_curr

func _on_player_died(_cause: String) -> void:
	if hull_bar:
		hull_bar.value = 0.0
	if survival_overlay:
		if survival_overlay.hp_label:
			survival_overlay.hp_label.text = "0/%d" % int(hull_bar.max_value if hull_bar else 100)
		if survival_overlay.hull_bar:
			survival_overlay.hull_bar.value = 0.0

func _on_reticle_draw() -> void:
	var center = Vector2(16, 16)
	var p = get_tree().get_first_node_in_group("player")
	var has_target_lock: bool = false
	if p and is_instance_valid(p) and "turret" in p and p.turret:
		has_target_lock = is_instance_valid(p.turret.current_target_node)

	var col = Color(0.2, 1.0, 0.4, 0.85)
	if not is_turret_in_arc or is_turret_blocked:
		col = Color(1.0, 0.65, 0.15, 0.90) # Out of arc amber
	elif has_target_lock:
		col = Color(1.0, 0.35, 0.2, 0.95) # Locked target red/orange
	
	# Tactical 4-bracket crosshair
	if is_turret_in_arc:
		reticle_widget.draw_line(center + Vector2(-12, 0), center + Vector2(-4, 0), col, 2.0)
		reticle_widget.draw_line(center + Vector2(4, 0), center + Vector2(12, 0), col, 2.0)
		reticle_widget.draw_line(center + Vector2(0, -12), center + Vector2(0, -4), col, 2.0)
		reticle_widget.draw_line(center + Vector2(0, 4), center + Vector2(0, 12), col, 2.0)
		reticle_widget.draw_circle(center, 2.0, col)
		if has_target_lock:
			# Target lock indicator diamond pips
			reticle_widget.draw_arc(center, 14.0, 0.0, TAU, 16, col, 1.5)
	else:
		# Out-of-arc cue: corner brackets with center slash
		reticle_widget.draw_line(center + Vector2(-12, -8), center + Vector2(-8, -8), col, 1.5)
		reticle_widget.draw_line(center + Vector2(-12, -8), center + Vector2(-12, -4), col, 1.5)
		reticle_widget.draw_line(center + Vector2(12, -8), center + Vector2(8, -8), col, 1.5)
		reticle_widget.draw_line(center + Vector2(12, -8), center + Vector2(12, -4), col, 1.5)
		reticle_widget.draw_line(center + Vector2(-12, 8), center + Vector2(-8, 8), col, 1.5)
		reticle_widget.draw_line(center + Vector2(-12, 8), center + Vector2(-12, 4), col, 1.5)
		reticle_widget.draw_line(center + Vector2(12, 8), center + Vector2(8, 8), col, 1.5)
		reticle_widget.draw_line(center + Vector2(12, 8), center + Vector2(12, 4), col, 1.5)
		reticle_widget.draw_line(center + Vector2(-3, -3), center + Vector2(3, 3), col, 1.5)
		reticle_widget.draw_line(center + Vector2(3, -3), center + Vector2(-3, 3), col, 1.5)

	# When out of arc, draw an indicator dot at the real barrel aim position relative to reticle
	if has_barrel_pos:
		var rel_barrel = barrel_screen_pos - reticle_widget.position
		reticle_widget.draw_circle(rel_barrel, 4.0, Color(1.0, 0.35, 0.2, 0.95))
		reticle_widget.draw_line(center, rel_barrel, Color(1.0, 0.65, 0.2, 0.45), 1.2)

func _process(delta: float) -> void:
	telemetry_timer -= delta
	if telemetry_timer <= 0:
		telemetry_timer = 0.1
		_update_survival_layer()
		_update_task_layer()
		_update_progress_layer()
	_update_blood_vignette(delta)
	_update_missile_warnings(delta)
	_update_border_warnings()
	_update_reticle()
	if targeting_overlay:
		targeting_overlay.queue_redraw()

func _update_blood_vignette(delta: float) -> void:
	if not blood_overlay or not blood_material:
		return

	if get_viewport():
		var vp_size = get_viewport().get_visible_rect().size
		if blood_overlay.size != vp_size:
			blood_overlay.size = vp_size

	# Decay hit flash trauma kick
	if hit_flash_intensity > 0.0:
		hit_flash_intensity = maxf(0.0, hit_flash_intensity - delta * 3.2)

	# Calculate current health ratio
	var hp_ratio = 1.0
	if not player_helicopter or not is_instance_valid(player_helicopter):
		player_helicopter = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player_helicopter and is_instance_valid(player_helicopter):
		if player_helicopter.max_hull > 0.0:
			hp_ratio = clampf(player_helicopter.current_hull / player_helicopter.max_hull, 0.0, 1.0)

	# Professional tactical blood vignette activates below 35% health
	if hp_ratio < 0.35:
		target_blood_intensity = clampf((0.35 - hp_ratio) / 0.35, 0.0, 1.0)
		# Cardiac pulse rate increases as health reaches critical levels (3.8Hz to 8.5Hz)
		blood_pulse_speed = lerpf(3.8, 8.5, 1.0 - (hp_ratio / 0.35))
	else:
		target_blood_intensity = 0.0
		blood_pulse_speed = 3.8

	# Smoothly interpolate blood intensity
	blood_intensity = lerpf(blood_intensity, target_blood_intensity, 1.0 - exp(-7.0 * delta))

	var is_active = (blood_intensity > 0.002 or hit_flash_intensity > 0.002)
	blood_overlay.visible = is_active
	if is_active:
		var reduced: bool = has_node("/root/AudioManager") and get_node("/root/AudioManager").reduce_flashes
		blood_material.set_shader_parameter("blood_intensity", blood_intensity * (0.20 if reduced else 0.38))
		blood_material.set_shader_parameter("pulse_speed", 1.0 if reduced else blood_pulse_speed)
		blood_material.set_shader_parameter("hit_flash", 0.0 if reduced else hit_flash_intensity * 0.25)

func _update_reticle() -> void:
	var controls = get_node("/root/InputManager")
	if controller_hint:
		controller_hint.visible = controls.controller_active or controls.notice_timer > 0.0
		controller_hint.text = controls.controller_notice if controls.notice_timer > 0.0 else "RS AIM  /  RT FIRE  /  LT SALVO  /  L3-R3 WEAPONS  /  VIEW MISSIONS  /  START PAUSE"
	has_barrel_pos = false
	is_turret_blocked = false
	if reticle_widget:
		var mouse_pos: Vector2 = get_node("/root/InputManager").get_aim_screen_position()
		reticle_widget.position = mouse_pos - Vector2(16, 16)
		
		var p = get_tree().get_first_node_in_group("player")
		if p and is_instance_valid(p) and "turret" in p and p.turret:
			is_turret_in_arc = p.turret.is_aim_in_arc if "is_aim_in_arc" in p.turret else true
			is_turret_blocked = p.turret.is_aim_blocked
			var cam = get_viewport().get_camera_3d()
			if cam:
				var muzzle_tf = p.turret.get_current_muzzle_transform()
				var aim_point_3d = p.turret.actual_impact_point if ("actual_impact_point" in p.turret and not p.turret.actual_impact_point.is_zero_approx()) else (muzzle_tf.origin + p.turret.get_aim_direction() * 50.0)
				if not cam.is_position_behind(aim_point_3d):
					barrel_screen_pos = cam.unproject_position(aim_point_3d)
					has_barrel_pos = true
				else:
					has_barrel_pos = false
		reticle_widget.queue_redraw()

func _update_missile_warnings(delta: float) -> void:
	if get_tree().paused:
		return
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.current_state not in [gm.RunState.ACTIVE, gm.RunState.EXTRACTION, gm.RunState.TUTORIAL]:
		if lock_warning_banner: lock_warning_banner.hide()
		return
	missile_scan_timer -= delta
	missile_alarm_timer = maxf(0.0, missile_alarm_timer - delta)
	if missile_scan_timer <= 0.0 and is_instance_valid(player_helicopter):
		missile_scan_timer = 0.10
		incoming_missiles = 0
		missile_urgent = false
		for missile in get_tree().get_nodes_in_group("combat_projectiles"):
			if missile.is_queued_for_deletion() or not missile.is_homing or missile.target_node != player_helicopter:
				continue
			incoming_missiles += 1
			var distance: float = missile.global_position.distance_to(player_helicopter.global_position)
			var closing: float = maxf(1.0, (missile.velocity - player_helicopter.velocity).dot((player_helicopter.global_position - missile.global_position).normalized()))
			missile_urgent = missile_urgent or distance <= 25.0 or distance / closing <= 1.0
			damage_indicator._on_threat_warning(missile.global_position, "INCOMING MISSILE", 0.25)
		if incoming_missiles > 0 and missile_alarm_timer <= 0.0:
			missile_alarm_timer = 0.30 if missile_urgent else 0.85
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("lock_beep", 1.35 if missile_urgent else 1.0)
	alert_flash_timer += delta * 6.0
	var is_under_sam_lock = false
	var sam_sites = get_tree().get_nodes_in_group("sam_sites")
	for s in sam_sites:
		if is_instance_valid(s) and s.get("current_state") == 2: # SAMState.LOCKING
			is_under_sam_lock = true
			break

	if lock_warning_banner:
		var mortal_alarm: bool = is_instance_valid(player_helicopter) and player_helicopter.mortal_alarm_timer > 0.0
		lock_warning_banner.text = "EMERGENCY / HULL CRITICAL / EVADE" if mortal_alarm else ("MISSILE INBOUND / DEPLOY FLARES" if incoming_missiles > 0 else "RADAR LOCK / BREAK LINE OF SIGHT")
		if is_under_sam_lock or incoming_missiles > 0 or mortal_alarm:
			lock_warning_banner.visible = mortal_alarm or incoming_missiles > 0 or fmod(alert_flash_timer, 2.0) < 1.3
		else:
			lock_warning_banner.visible = false

func _update_border_warnings() -> void:
	if border_warning_banner:
		if is_border_warning:
			border_warning_banner.visible = fmod(alert_flash_timer, 1.6) < 1.15
			var sub = border_warning_banner.get_node_or_null("Subtitle") as Label
			if sub:
				sub.text = "AIRFRAME HAZARD DAMAGE ACTIVE! / %dm TO BARRIER" % int(border_edge_dist)
				sub.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25) if fmod(alert_flash_timer, 0.8) < 0.4 else Color(1.0, 0.85, 0.4))
		else:
			border_warning_banner.visible = false

# ------------------------------------------------------------------------------
# Targeting Overlay Drawing (Slice B: In-World Brackets & Salvo Lock Pips)
# ------------------------------------------------------------------------------
func _on_targeting_overlay_draw() -> void:
	if not player_helicopter or not is_instance_valid(player_helicopter):
		return

	var camera: Camera3D = player_helicopter.camera if "camera" in player_helicopter else null
	if not camera or not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var vp_rect = get_viewport().get_visible_rect()
	var default_font = preload("res://src/effects/floating_text.gd").get_pixel_font()

	# 1. Chin-Turret Current Target Bracket
	var turret = player_helicopter.get("turret") if "turret" in player_helicopter else null
	if turret and is_instance_valid(turret):
		var target_candidate = turret.get("current_target_node")
		if target_candidate and is_instance_valid(target_candidate) and not target_candidate.is_queued_for_deletion() and target_candidate is Node3D:
			var target: Node3D = target_candidate
			var rec = target.get_node_or_null("DamageReceiver")
			if rec == null or not rec.is_dead:
				var world_pos = target.global_position + Vector3(0, 1.0, 0)
				if not camera.is_position_behind(world_pos):
					var screen_pos = camera.unproject_position(world_pos)
					if vp_rect.has_point(screen_pos):
						var is_manual: bool = ("hovered_enemy" in turret and is_instance_valid(turret.hovered_enemy))
						_draw_target_bracket(screen_pos, target, rec, is_manual, default_font)

	# 2. Salvo Painted Locks Brackets
	var salvo = player_helicopter.get_node_or_null("Salvo")
	if salvo and is_instance_valid(salvo) and salvo.current_locks.size() > 0:
		var lock_counts: Dictionary = {}
		for l in salvo.current_locks:
			if l and is_instance_valid(l) and not l.is_queued_for_deletion() and l is Node3D:
				lock_counts[l] = lock_counts.get(l, 0) + 1

		for l_node in lock_counts.keys():
			if l_node and is_instance_valid(l_node) and not l_node.is_queued_for_deletion() and l_node is Node3D:
				var rec = l_node.get_node_or_null("DamageReceiver")
				if rec == null or not rec.is_dead:
					var world_pos = l_node.global_position + Vector3(0, 1.4, 0)
					if not camera.is_position_behind(world_pos):
						var screen_pos = camera.unproject_position(world_pos)
						if vp_rect.has_point(screen_pos):
							_draw_salvo_bracket(screen_pos, lock_counts[l_node], default_font)

func _draw_target_bracket(pos: Vector2, target: Node3D, rec: Node, is_manual: bool, font: Font) -> void:
	var box_size: float = 46.0
	var half_s: float = box_size * 0.5
	var corner_len: float = 10.0
	var line_w: float = 2.0

	var bracket_col = Color(0.15, 1.0, 0.45, 0.95) if is_manual else Color(1.0, 0.82, 0.2, 0.9)
	var top_left = pos + Vector2(-half_s, -half_s)
	var top_right = pos + Vector2(half_s, -half_s)
	var bot_left = pos + Vector2(-half_s, half_s)
	var bot_right = pos + Vector2(half_s, half_s)

	# Corner brackets
	targeting_overlay.draw_line(top_left, top_left + Vector2(corner_len, 0), bracket_col, line_w)
	targeting_overlay.draw_line(top_left, top_left + Vector2(0, corner_len), bracket_col, line_w)

	targeting_overlay.draw_line(top_right, top_right + Vector2(-corner_len, 0), bracket_col, line_w)
	targeting_overlay.draw_line(top_right, top_right + Vector2(0, corner_len), bracket_col, line_w)

	targeting_overlay.draw_line(bot_left, bot_left + Vector2(corner_len, 0), bracket_col, line_w)
	targeting_overlay.draw_line(bot_left, bot_left + Vector2(0, -corner_len), bracket_col, line_w)

	targeting_overlay.draw_line(bot_right, bot_right + Vector2(-corner_len, 0), bracket_col, line_w)
	targeting_overlay.draw_line(bot_right, bot_right + Vector2(0, -corner_len), bracket_col, line_w)

	# Center dot
	targeting_overlay.draw_circle(pos, 2.0, bracket_col)

	# Mini Health Bar (above bracket)
	if rec:
		var max_hp: float = 100.0
		if "max_health" in rec:
			max_hp = rec.max_health
		elif "max_hull" in rec:
			max_hp = rec.max_hull

		var cur_hp: float = max_hp
		if "current_health" in rec:
			cur_hp = rec.current_health
		elif "current_hull" in rec:
			cur_hp = rec.current_hull
		if max_hp > 0.0:
			var hp_ratio = clampf(cur_hp / max_hp, 0.0, 1.0)
			var bar_w = 40.0
			var bar_h = 4.0
			var bar_pos = pos + Vector2(-bar_w * 0.5, -half_s - 9.0)
			targeting_overlay.draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.1, 0.1, 0.1, 0.75), true)
			var hp_col = Color(0.2, 0.9, 0.3, 0.95) if hp_ratio > 0.4 else Color(0.95, 0.25, 0.2, 0.95)
			targeting_overlay.draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_ratio, bar_h)), hp_col, true)
			targeting_overlay.draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.4, 0.4, 0.4, 0.6), false, 1.0)

	# Target Tag & Distance (below bracket)
	if font:
		var mode_tag = "LOCK" if is_manual else "TRACK"
		var dist_m = int(player_helicopter.global_position.distance_to(target.global_position))
		var v_name = target.get("variant_id") if "variant_id" in target else target.name
		v_name = str(v_name).to_upper().replace("_", " ")

		var label_str = "%s %s (%dm)" % [mode_tag, v_name, dist_m]
		var text_pos = pos + Vector2(-half_s, half_s + 14.0)
		targeting_overlay.draw_string(font, text_pos, label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, bracket_col)

func _draw_salvo_bracket(pos: Vector2, lock_count: int, font: Font) -> void:
	var salvo_col = Color(1.0, 0.35, 0.15, 0.95) # Tactical orange-crimson
	var radius: float = 28.0
	var line_w: float = 2.0

	var pulse = 1.0 + sin(alert_flash_timer * 1.5) * 0.08
	var r = radius * pulse
	var top = pos + Vector2(0, -r)
	var right = pos + Vector2(r, 0)
	var bottom = pos + Vector2(0, r)
	var left = pos + Vector2(-r, 0)

	targeting_overlay.draw_line(top, right, salvo_col, line_w)
	targeting_overlay.draw_line(right, bottom, salvo_col, line_w)
	targeting_overlay.draw_line(bottom, left, salvo_col, line_w)
	targeting_overlay.draw_line(left, top, salvo_col, line_w)

	if font:
		var badge_str = "MISSILE x%d" % lock_count
		var text_pos = pos + Vector2(-30.0, -r - 6.0)
		targeting_overlay.draw_string(font, text_pos, badge_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, salvo_col)

	var pip_spacing = 9.0
	var start_x = -(float(lock_count - 1) * pip_spacing * 0.5)
	for i in range(lock_count):
		var pip_pos = pos + Vector2(start_x + (float(i) * pip_spacing), r + 8.0)
		targeting_overlay.draw_circle(pip_pos, 3.0, salvo_col)

func _update_survival_layer() -> void:
	if player_helicopter and is_instance_valid(player_helicopter):
		if hull_bar:
			hull_bar.max_value = player_helicopter.max_hull
			hull_bar.value = player_helicopter.current_hull
		if fuel_bar:
			fuel_bar.max_value = player_helicopter.max_fuel
			fuel_bar.value = player_helicopter.current_fuel

		if ammo_label and player_helicopter.has_node("Weapons"):
			var wp = player_helicopter.get_node("Weapons")
			var st = wp.weapon_states[wp.current_weapon_idx]
			var w_name = GameConstants.WEAPONS[wp.current_weapon_idx]["name"]
			var reload_str = " (RELOADING)" if st["is_reloading"] else ""
			var max_ammo = wp.get_max_ammo(wp.current_weapon_idx) if wp.has_method("get_max_ammo") else GameConstants.WEAPONS[wp.current_weapon_idx]["ammo_max"]
			ammo_label.text = "%s: %d / %d%s" % [w_name, st["ammo"], max_ammo, reload_str]

		if flare_label and player_helicopter.has_node("Countermeasures"):
			var cm = player_helicopter.get_node("Countermeasures")
			flare_label.text = "FLARES: %d / %d" % [cm.current_charges, cm.max_charges]

		if super_bar and player_helicopter.has_node("DevastationSuper"):
			var ds = player_helicopter.get_node("DevastationSuper")
			super_bar.value = ds.current_charge

func _update_task_layer() -> void:
	# 1. Tactical Mission Tracking
	var mission_mgr = get_tree().get_first_node_in_group("mission_manager")
	if not mission_mgr:
		mission_mgr = get_parent().get_parent().get_node_or_null("MissionManager")
	
	if mission_label:
		mission_label.visible = mission_mgr == null or not mission_mgr.has_node("MissionTracker")
		if mission_mgr and mission_mgr.get("is_mission_active"):
			var m_data = mission_mgr.get("active_mission_data")
			var m_name = m_data.get("name", "TACTICAL OBJECTIVE")
			var m_reward = m_data.get("credits", 300)
			mission_label.text = "[ ] %s (+%d)" % [m_name.to_upper(), m_reward]
		else:
			mission_label.text = "[ ] AIR DEFENSE PATROL"

	# 2. Cargo Contract Tracking
	var cargo_mgr = get_tree().get_first_node_in_group("cargo_manager")
	if not cargo_mgr:
		cargo_mgr = get_parent().get_parent().get_node_or_null("CargoManager")
	
	if cargo_label:
		if cargo_mgr and cargo_mgr.get("current_state") != 0: # Not IDLE
			var c_state = cargo_mgr.get("current_state")
			var c_data = cargo_mgr.get("current_contract")
			var c_type = c_data.get("type", "Cargo").to_upper()
			var c_pay = c_data.get("base_price", 320)
			match c_state:
				1: # OFFERED
					cargo_label.text = "CONTRACT: %s -> LZ A (REWARD: %d CR)" % [c_type, c_pay]
				2, 3: # LOADING
					cargo_label.text = "LOADING: %s AT LZ (HOLD POSITION)" % [c_type]
				4: # CARRYING
					cargo_label.text = "IN TRANSIT: %s -> UNLOAD AT LZ B" % [c_type]
				5: # UNLOADING
					cargo_label.text = "DELIVERING: %s AT LZ B (HOLD POSITION)" % [c_type]
				_:
					cargo_label.text = "CARGO: CONTRACT COMPLETED"
		else:
			cargo_label.text = "CARGO: NO ACTIVE CONTRACT"

func _update_progress_layer() -> void:
	if survival_overlay:
		survival_overlay.refresh(get_node_or_null("/root/GameManager"), player_helicopter)

func _build_survival_hud() -> void:
	for path in ["SurvivalLayer", "TaskLayer", "ProgressLayer"]:
		var legacy := get_node_or_null(path)
		if legacy:
			legacy.hide()
	survival_overlay = preload("res://src/ui/survival_hud.gd").new()
	add_child(survival_overlay)
	hull_bar = survival_overlay.hull_bar
	fuel_bar = survival_overlay.fuel_bar
	super_bar = survival_overlay.super_bar
	ammo_label = survival_overlay.ammo_label
	flare_label = survival_overlay.flare_label
	mission_label = survival_overlay.mission_label
	cargo_label = survival_overlay.cargo_label
	var radar := get_node_or_null("TacticalRadar") as Control
	if radar:
		radar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		radar.offset_left = -194
		radar.offset_right = -20
		radar.offset_top = 76
		radar.offset_bottom = 250
		radar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		radar.grow_vertical = Control.GROW_DIRECTION_END
