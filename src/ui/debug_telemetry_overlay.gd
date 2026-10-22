class_name DebugTelemetryOverlay
extends Control

## DebugTelemetryOverlay — Section 8 Development Debug View & Telemetry
## Toggleable with F3 to inspect live encounter states, not-firing reasons, slot leases, and cumulative counters.

var is_overlay_visible: bool = false
var panel: PanelContainer
var content_label: Label
var update_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	# Build semi-transparent dark panel in top-left
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 16.0
	panel.offset_top = 16.0
	panel.offset_right = 380.0
	panel.offset_bottom = 540.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.10, 0.88)
	style.border_color = Color(0.2, 0.6, 0.9, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_top = 12.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	content_label = Label.new()
	content_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_label.add_theme_font_size_override("font_size", 12)
	content_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(content_label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			toggle_overlay()

func toggle_overlay() -> void:
	is_overlay_visible = not is_overlay_visible
	visible = is_overlay_visible
	if is_overlay_visible:
		_refresh_telemetry()

func _process(delta: float) -> void:
	if not is_overlay_visible:
		return

	update_timer -= delta
	if update_timer <= 0.0:
		update_timer = 0.10 # 10 Hz refresh
		_refresh_telemetry()

func _refresh_telemetry() -> void:
	var director = get_node_or_null("/root/CombatDirector")
	var fps = Engine.get_frames_per_second()
	var frame_ms = 1000.0 / maxf(float(fps), 1.0)

	var enemies = get_tree().get_nodes_in_group("enemies")
	var total_enemies = 0

	# Behavior State Counts
	var state_counts = {
		"ENTER": 0,
		"PURSUE": 0,
		"POSITION": 0,
		"WINDUP": 0,
		"FIRE": 0,
		"RECOVER": 0,
		"DEAD": 0
	}

	# Not-Firing Reason Counts
	var reason_counts = {
		"OUT_OF_RANGE": 0,
		"BLOCKED_SHOT": 0,
		"TURNING": 0,
		"COOLDOWN": 0,
		"ENTERING": 0,
		"NO_TARGET": 0,
		"WAITING_PERMISSION": 0,
		"NO_REACHABLE_POSITION": 0,
		"OK_FIRING": 0
	}

	for e in enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			total_enemies += 1
			if "behavior_state" in e:
				match e.behavior_state:
					0: state_counts["ENTER"] += 1
					1: state_counts["PURSUE"] += 1
					2: state_counts["POSITION"] += 1
					3: state_counts["WINDUP"] += 1
					4: state_counts["FIRE"] += 1
					5: state_counts["RECOVER"] += 1
					6: state_counts["DEAD"] += 1
			if "not_firing_reason" in e:
				var r: String = str(e.not_firing_reason)
				if reason_counts.has(r):
					reason_counts[r] += 1
				else:
					reason_counts[r] = 1

	# Format text
	var text = "=== [F3] ENCOUNTER TELEMETRY ===\n"
	text += "Perf: %3d FPS (%4.1f ms) | Units: %2d\n\n" % [fps, frame_ms, total_enemies]

	if director and "fast_wallet" in director:
		var d_mult: float = director.get_difficulty_multiplier() if director.has_method("get_difficulty_multiplier") else 1.0
		var theme_name: String = str(director.active_theme)
		var active_mins: float = director.active_combat_time / 60.0
		text += "-- DIRECTOR ECONOMY (D: %.2f) --\n" % [d_mult]
		text += "Wave: %d (%s) | Seed: %d | Time: %.1fm\n" % [
			director.current_wave, theme_name, director.encounter_seed, active_mins
		]
		text += "Fast: %4.1f / %-4.1f cr | Slow: %4.1f / %-4.1f cr\n" % [
			director.fast_wallet, director.fast_wallet_cap,
			director.slow_wallet, director.slow_wallet_cap
		]
		text += "Pop: %d act + %d res / %d tgt (max %d)\n" % [
			total_enemies, director.reserved_population, director.target_population, director.MAX_ACTIVE_POPULATION
		]
		text += "Spawns: %d (F:%d, S:%d) | Rej: %d | Ref: %d\n" % [
			director.cumulative_spawns, director.telemetry_purchases_fast,
			director.telemetry_purchases_slow, director.telemetry_rejections,
			director.telemetry_refunds
		]
		text += "Retirements: %d | Sector: %.1f deg | Dist: %.1fm\n\n" % [
			director.telemetry_retirements, rad_to_deg(director.telemetry_last_sector),
			director.telemetry_last_distance
		]

	text += "-- BEHAVIOR STATES --\n"
	text += "ENTER: %-2d | PURSUE: %-2d | POSITION: %-2d\n" % [
		state_counts["ENTER"], state_counts["PURSUE"], state_counts["POSITION"]
	]
	text += "WINDUP: %-2d | FIRE: %-2d | RECOVER: %-2d | DEAD: %-2d\n\n" % [
		state_counts["WINDUP"], state_counts["FIRE"], state_counts["RECOVER"], state_counts["DEAD"]
	]

	text += "-- NOT-FIRING REASONS --\n"
	text += "OUT_OF_RANGE: %-2d | BLOCKED_SHOT: %-2d\n" % [reason_counts["OUT_OF_RANGE"], reason_counts["BLOCKED_SHOT"]]
	text += "TURNING:      %-2d | COOLDOWN:     %-2d\n" % [reason_counts["TURNING"], reason_counts["COOLDOWN"]]
	text += "ENTERING:     %-2d | NO_TARGET:    %-2d\n" % [reason_counts["ENTERING"], reason_counts["NO_TARGET"]]
	text += "WAITING_PERM: %-2d | NO_REACHABLE: %-2d\n" % [reason_counts["WAITING_PERMISSION"], reason_counts["NO_REACHABLE_POSITION"]]
	text += "OK_FIRING:    %-2d\n\n" % [reason_counts["OK_FIRING"]]

	# Lease holders
	text += "-- ACTIVE ATTACK LEASES --\n"
	if director:
		var air_count = director.current_air_attackers.size()
		var heavy_count = director.current_heavy_attackers.size()
		text += "Air Slots:   %d / %d  | Heavy Slots: %d / %d\n" % [
			air_count, director.max_air_slots, heavy_count, director.max_heavy_slots
		]
		for a in director.current_air_attackers:
			if is_instance_valid(a):
				var v_id = a.variant_id if "variant_id" in a else a.name
				text += "  [AIR] %s\n" % [v_id]
		for h in director.current_heavy_attackers:
			if is_instance_valid(h):
				var v_id = h.variant_id if "variant_id" in h else h.name
				text += "  [HVY] %s\n" % [v_id]
	else:
		text += "CombatDirector: Offline\n"
	text += "\n"

	# Cumulative Counters
	text += "-- CUMULATIVE COUNTERS --\n"
	if director:
		text += "Spawns:         %d\n" % [director.cumulative_spawns]
		text += "Shots Emitted:  %d\n" % [director.cumulative_shots_emitted]
		text += "Damage Landed:  %.1f\n" % [director.cumulative_damage_landed]
		text += "Stuck Recoveries: %d\n" % [director.cumulative_stuck_recoveries]

	content_label.text = text
