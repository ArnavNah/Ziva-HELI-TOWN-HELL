class_name LevelUpUi
extends CanvasLayer

## LevelUpUi — Modal Control CanvasLayer that pauses gameplay upon level-up,
## calculates dynamic weighted rarity odds (modified by Luck Tomes),
## presents 3 distinct UpgradeCard choices, delivers payloads to PlayerSubsystemManager,
## and handles multi-level queue sequences.

const CardDatabase = preload("res://src/resources/upgrade_card_database.gd")

signal draft_completed(card: RefCounted)

@export var base_weights: Dictionary = {
	UpgradeCard.RarityTier.COMMON: 60.0,
	UpgradeCard.RarityTier.UNCOMMON: 25.0,
	UpgradeCard.RarityTier.RARE: 10.0,
	UpgradeCard.RarityTier.EPIC: 4.5,
	UpgradeCard.RarityTier.LEGENDARY: 0.5
}

var current_draft: Array = []
var card_buttons: Array[Button] = []
var is_choosing: bool = false
var active_tween: Tween = null
var displayed_level: int = 1
var resume_state: int = -1
const PRESENTATION_DELAY := 0.35
const COMBAT_BREATHER := 2.5
var presentation_delay_remaining: float = -1.0

func _can_present() -> bool:
	if not is_inside_tree() or get_tree().paused:
		return false
	var player = _get_player()
	if not is_instance_valid(player) or player.is_queued_for_deletion():
		return false
	if ("is_dying" in player and player.is_dying) or ("is_dashing" in player and player.is_dashing):
		return false
	var gm = get_node_or_null("/root/GameManager")
	return gm != null and gm.current_state in [gm.RunState.ACTIVE, gm.RunState.EXTRACTION, gm.RunState.TUTORIAL]

func _process(delta: float) -> void:
	if is_choosing:
		var player = _get_player()
		if not is_instance_valid(player) or ("is_dying" in player and player.is_dying):
			_reset_overlay()
		return
	if presentation_delay_remaining < 0.0 or is_choosing or not _can_present():
		return
	presentation_delay_remaining = maxf(0.0, presentation_delay_remaining - delta)
	if presentation_delay_remaining <= 0.0:
		presentation_delay_remaining = -1.0
		var xp = get_node_or_null("/root/XpManager")
		if xp and xp.has_pending_level_ups():
			open_draft(xp.current_level - xp.queued_level_ups + 1)

func _queue_presentation(delay: float) -> void:
	if presentation_delay_remaining < 0.0:
		presentation_delay_remaining = delay

# Child UI Nodes
var backdrop: ColorRect
var main_container: VBoxContainer
var title_label: Label
var subtitle_label: Label
var cards_hbox: HBoxContainer

func _ready() -> void:
	# Defensive Requirement 2: PROCESS_MODE_WHEN_PAUSED or ALWAYS so buttons accept input while paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100 # High display priority over gameplay HUD
	visible = false

	_build_ui_hierarchy()
	_connect_xp_manager()

func _connect_xp_manager() -> void:
	var xp_mgr = get_node_or_null("/root/XpManager")
	if xp_mgr and xp_mgr.has_signal("level_up"):
		xp_mgr.level_up.connect(_on_level_up)
		xp_mgr.run_reset.connect(_reset_overlay)
	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.run_state_changed.connect(_on_run_state_changed)

func _reset_overlay() -> void:
	presentation_delay_remaining = -1.0
	is_choosing = false
	visible = false
	current_draft.clear()
	if active_tween:
		active_tween.kill()
	if resume_state >= 0 and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.current_state == gm.RunState.UPGRADE_CHOICE:
			gm.change_state(resume_state)
	resume_state = -1

func _on_run_state_changed(state: int, _previous: int) -> void:
	if not is_inside_tree():
		return
	var gm = get_node("/root/GameManager")
	if state in [gm.RunState.MENU, gm.RunState.LOADING, gm.RunState.RESULTS]:
		_reset_overlay()
	elif state in [gm.RunState.ACTIVE, gm.RunState.EXTRACTION, gm.RunState.TUTORIAL]:
		_present_pending.call_deferred()

func _present_pending() -> void:
	if not is_inside_tree():
		return
	var xp = get_node_or_null("/root/XpManager")
	if xp and xp.has_pending_level_ups() and not is_choosing:
		_on_level_up(xp.current_level - xp.queued_level_ups + 1)

func _on_level_up(_new_level: int) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.current_state in [gm.RunState.MENU, gm.RunState.LOADING, gm.RunState.RESULTS, gm.RunState.BOSS_DECISION, gm.RunState.PAUSED]:
		return # Keep the earned choice queued until gameplay resumes.
	# If already showing modal, subsequent level-ups remain queued in XpManager
	if visible and is_choosing:
		_update_subtitle()
		return
	
	_queue_presentation(PRESENTATION_DELAY)

func open_draft(level: int = 1) -> void:
	if not _can_present():
		return
	var player = _get_player()
	var luck: float = 0.0
	if player and player.has_node("SubsystemManager"):
		var sm = player.get_node("SubsystemManager")
		if sm.has_method("get_luck_level"):
			luck = sm.get_luck_level()

	current_draft = generate_draft_picks(3, luck)
	if current_draft.is_empty():
		return
	displayed_level = level
	is_choosing = true
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.current_state in [gm.RunState.ACTIVE, gm.RunState.EXTRACTION, gm.RunState.TUTORIAL]:
		resume_state = gm.current_state
		gm.change_state(gm.RunState.UPGRADE_CHOICE)
	get_tree().paused = true
	_populate_card_buttons(current_draft)
	_update_subtitle(level)

	visible = true

	# Entry Animation (180ms cubic ease-out)
	if active_tween:
		active_tween.kill()
	main_container.scale = Vector2(0.92, 0.92)
	main_container.modulate.a = 0.0
	main_container.pivot_offset = main_container.size * 0.5
	active_tween = create_tween()
	active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	active_tween.set_parallel(true)
	active_tween.tween_property(main_container, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(main_container, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Focus first available card for gamepad & keyboard navigation
	if not card_buttons.is_empty():
		card_buttons[0].grab_focus.call_deferred()

	# Audio cue
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("upgrade_offer", 1.0, 1.0)

func generate_draft_picks(count: int = 3, luck_level: float = 0.0) -> Array:
	var master_deck = CardDatabase.get_eligible_cards(_get_player())
	var weights = get_dynamic_rarity_weights(luck_level)
	var picks: Array = []

	var attempts: int = 0
	while picks.size() < count and not master_deck.is_empty() and attempts < 100:
		attempts += 1
		# 1. Select tier based on weighted odds
		var rolled_tier = _roll_rarity_tier(weights)
		
		# 2. Filter deck for available cards in this tier not yet selected
		var candidates: Array = []
		for card in master_deck:
			if card.rarity == rolled_tier and not picks.has(card):
				candidates.append(card)

		# 3. If tier has no cards, fallback to any available non-picked card
		if candidates.is_empty():
			for card in master_deck:
				if not picks.has(card):
					candidates.append(card)

		if not candidates.is_empty():
			var chosen = candidates[randi() % candidates.size()]
			picks.append(chosen)
			master_deck.erase(chosen)

	return picks

func get_dynamic_rarity_weights(luck_level: float = 0.0) -> Dictionary:
	var w = base_weights.duplicate()
	if luck_level > 0.0:
		# Luck scales up higher tiers and trims Common
		var bonus_ratio = luck_level * 0.25
		w[UpgradeCard.RarityTier.LEGENDARY] *= (1.0 + bonus_ratio * 1.6)
		w[UpgradeCard.RarityTier.EPIC] *= (1.0 + bonus_ratio * 1.25)
		w[UpgradeCard.RarityTier.RARE] *= (1.0 + bonus_ratio * 0.8)
		w[UpgradeCard.RarityTier.UNCOMMON] *= (1.0 + bonus_ratio * 0.3)
		w[UpgradeCard.RarityTier.COMMON] = maxf(12.0, w[UpgradeCard.RarityTier.COMMON] - bonus_ratio * 12.0)
	return w

func _roll_rarity_tier(weights: Dictionary) -> int:
	var total_w: float = 0.0
	for tier in weights.keys():
		total_w += float(weights[tier])

	var roll = randf_range(0.0, total_w)
	var accum: float = 0.0
	for tier in [
		UpgradeCard.RarityTier.LEGENDARY,
		UpgradeCard.RarityTier.EPIC,
		UpgradeCard.RarityTier.RARE,
		UpgradeCard.RarityTier.UNCOMMON,
		UpgradeCard.RarityTier.COMMON
	]:
		accum += float(weights.get(tier, 0.0))
		if roll <= accum:
			return tier
	return UpgradeCard.RarityTier.COMMON

func _populate_card_buttons(picks: Array) -> void:
	for i in range(card_buttons.size()):
		var btn = card_buttons[i]
		if i < picks.size():
			btn.visible = true
			btn.disabled = false
			_format_card_button(btn, picks[i], i + 1)
		else:
			btn.visible = false
			btn.disabled = true

func _format_card_button(btn: Button, card: RefCounted, shortcut_idx: int) -> void:
	# Clear previous custom styling
	var rarity_col = card.get_rarity_color()
	btn.text = "" # Suppress default button label to show custom child controls

	var badge_lbl = btn.get_node_or_null("Margin/VBox/Header/Badge") as Label
	var shortcut_lbl = btn.get_node_or_null("Margin/VBox/Header/Shortcut") as Label
	var title_lbl = btn.get_node_or_null("Margin/VBox/Title") as Label
	var sub_lbl = btn.get_node_or_null("Margin/VBox/Subsystem") as Label
	var desc_lbl = btn.get_node_or_null("Margin/VBox/Desc") as Label
	var stats_lbl = btn.get_node_or_null("Margin/VBox/StatPanel/Stats") as Label
	var border_rect = btn.get_node_or_null("BorderRect") as ReferenceRect
	var icon = btn.get_node_or_null("Margin/VBox/Header/Icon") as TextureRect
	if icon:
		icon.texture = card.icon
	for state in ["normal", "hover", "focus", "pressed"]:
		var style = btn.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		if style:
			style.border_color = rarity_col if state == "normal" else rarity_col.lightened(0.25)
			btn.add_theme_stylebox_override(state, style)

	if badge_lbl:
		badge_lbl.text = "[ %s ]" % card.get_rarity_name()
		badge_lbl.add_theme_color_override("font_color", rarity_col)
	if shortcut_lbl:
		shortcut_lbl.text = "[ %d ]" % shortcut_idx
	if title_lbl:
		title_lbl.text = card.title.to_upper()
	if sub_lbl:
		sub_lbl.text = "%s // %s" % [card.get_subsystem_name(), card.get_rarity_name()]
		sub_lbl.add_theme_color_override("font_color", rarity_col.lerp(Color.WHITE, 0.25))
	if desc_lbl:
		desc_lbl.text = card.description
	if stats_lbl:
		stats_lbl.text = card.get_formatted_stats()
	if border_rect:
		border_rect.border_color = rarity_col

func _on_card_clicked(idx: int) -> void:
	if not is_choosing or idx < 0 or idx >= current_draft.size():
		return
	var player = _get_player()
	if not is_instance_valid(player) or ("is_dying" in player and player.is_dying):
		_reset_overlay()
		return

	var chosen_card = current_draft[idx]
	is_choosing = false

	# 1. Apply upgrade payload to player subsystem manager
	var sm = player.get_node_or_null("SubsystemManager") if player else null
	if not sm or not sm.apply_upgrade(chosen_card):
		is_choosing = true
		return

	# 2. Audio feedback
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("upgrade_applied", 1.05, 1.0)

	draft_completed.emit(chosen_card)

	# 3. Check for queued level-ups in XpManager (Defensive Checklist 3)
	var xp_mgr = get_node_or_null("/root/XpManager")
	if xp_mgr:
		xp_mgr.consume_pending_level_up()
	if xp_mgr and xp_mgr.has_pending_level_ups():
		_queue_presentation(COMBAT_BREATHER)
	visible = false
	var gm = get_node_or_null("/root/GameManager")
	if gm and resume_state >= 0 and gm.current_state == gm.RunState.UPGRADE_CHOICE:
		gm.change_state(resume_state)
	elif not gm or gm.current_state not in [gm.RunState.PAUSED, gm.RunState.BOSS_DECISION, gm.RunState.RESULTS, gm.RunState.LOADING]:
		get_tree().paused = false
	resume_state = -1
	if has_node("/root/UIFlow"):
		get_node("/root/UIFlow").block_held_input()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not is_choosing:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				_on_card_clicked(0)
				get_viewport().set_input_as_handled()
			KEY_2, KEY_KP_2:
				_on_card_clicked(1)
				get_viewport().set_input_as_handled()
			KEY_3, KEY_KP_3:
				_on_card_clicked(2)
				get_viewport().set_input_as_handled()

func _update_subtitle(level: int = -1) -> void:
	if not subtitle_label:
		return
	var xp_mgr = get_node_or_null("/root/XpManager")
	if level >= 0:
		displayed_level = level
	level = displayed_level
	var queued = maxi(0, xp_mgr.queued_level_ups - 1) if xp_mgr else 0
	if queued > 0:
		subtitle_label.text = "FIELD SELECTION // LEVEL %d  [+%d PENDING]  -- COMBAT PAUSED" % [level, queued]
	else:
		subtitle_label.text = "FIELD SELECTION // LEVEL %d  [SELECT 1 AUGMENTATION]  -- COMBAT PAUSED" % level

func _get_player() -> Node:
	if is_inside_tree():
		return get_tree().get_first_node_in_group("player")
	return null

func _build_ui_hierarchy() -> void:
	var root_control = Control.new()
	root_control.name = "RootControl"
	root_control.anchor_right = 1.0
	root_control.anchor_bottom = 1.0
	root_control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root_control.grow_vertical = Control.GROW_DIRECTION_BOTH
	root_control.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root_control)

	# Backdrop
	backdrop = ColorRect.new()
	backdrop.name = "ModalBackdrop"
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	backdrop.grow_vertical = Control.GROW_DIRECTION_BOTH
	backdrop.color = Color(0.02, 0.05, 0.08, 0.88)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(backdrop)

	# Main container centered
	main_container = VBoxContainer.new()
	main_container.name = "MainVBox"
	main_container.anchor_left = 0.5
	main_container.anchor_top = 0.5
	main_container.anchor_right = 0.5
	main_container.anchor_bottom = 0.5
	main_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	main_container.add_theme_constant_override("separation", 14)
	root_control.add_child(main_container)

	# Title
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "/// TACTICAL AIRFRAME UPGRADE ///"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color("ffd700"))
	main_container.add_child(title_label)

	# Subtitle
	subtitle_label = Label.new()
	subtitle_label.name = "Subtitle"
	subtitle_label.text = "SELECT 1 AUGMENTATION -- COMBAT PAUSED"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 12)
	subtitle_label.add_theme_color_override("font_color", Color(0.45, 0.85, 0.95))
	main_container.add_child(subtitle_label)

	# HBox for 3 cards
	cards_hbox = HBoxContainer.new()
	cards_hbox.name = "CardsHBox"
	cards_hbox.add_theme_constant_override("separation", 18)
	main_container.add_child(cards_hbox)

	# 3 Card Buttons
	for i in range(3):
		var btn = _create_card_button(i)
		cards_hbox.add_child(btn)
		card_buttons.append(btn)

func _create_card_button(idx: int) -> Button:
	var btn = Button.new()
	btn.name = "CardButton_%d" % (idx + 1)
	btn.custom_minimum_size = Vector2(290, 240)
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_card_clicked.bind(idx))

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.04, 0.08, 0.12, 0.95)
	style_normal.set_border_width_all(2)
	style_normal.border_color = Color(0.20, 0.35, 0.45, 0.8)
	style_normal.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_focus = StyleBoxFlat.new()
	style_focus.bg_color = Color(0.06, 0.12, 0.18, 0.98)
	style_focus.set_border_width_all(2)
	style_focus.border_color = Color(1.0, 0.84, 0.0, 1.0)
	style_focus.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("focus", style_focus)
	btn.add_theme_stylebox_override("hover", style_focus)

	var margin = MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	btn.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var header = HBoxContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(icon)

	var badge = Label.new()
	badge.name = "Badge"
	badge.text = "[ COMMON ]"
	badge.add_theme_font_size_override("font_size", 10)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(badge)

	var shortcut = Label.new()
	shortcut.name = "Shortcut"
	shortcut.text = "[ %d ]" % (idx + 1)
	shortcut.add_theme_font_size_override("font_size", 10)
	shortcut.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	header.add_child(shortcut)

	var title = Label.new()
	title.name = "Title"
	title.text = "UPGRADE TITLE"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var sub = Label.new()
	sub.name = "Subsystem"
	sub.text = "PRIMARY CANNON // COMMON"
	sub.add_theme_font_size_override("font_size", 9)
	vbox.add_child(sub)

	var desc = Label.new()
	desc.name = "Desc"
	desc.text = "Description of upgrade capability."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95))
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)

	var stat_panel = PanelContainer.new()
	stat_panel.name = "StatPanel"
	var sp_box = StyleBoxFlat.new()
	sp_box.bg_color = Color(0.02, 0.04, 0.06, 0.85)
	sp_box.set_corner_radius_all(3)
	stat_panel.add_theme_stylebox_override("panel", sp_box)
	vbox.add_child(stat_panel)

	var stats = Label.new()
	stats.name = "Stats"
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 11)
	stats.add_theme_color_override("font_color", Color(0.3, 0.95, 0.85))
	stat_panel.add_child(stats)

	return btn
