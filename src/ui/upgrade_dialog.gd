class_name UpgradeDialog
extends Control

## UpgradeDialog — 3-card upgrade selection menu displayed on level up (Page 18).
## Features professional tactical aviation styling, reusable UpgradeCard controls,
## catalog-driven effective before/after previews, 1/2/3 hotkeys, and full gamepad navigation.

const UpgradeCatalog = preload("res://src/player/upgrade_catalog.gd")
const UpgradeCardClass = preload("res://src/ui/upgrade_card.gd")

@onready var vbox: VBoxContainer = $VBoxContainer
@onready var title_label: Label = $VBoxContainer/Title
@onready var hbox: HBoxContainer = $VBoxContainer/HBoxContainer
var button_1: Button
var button_2: Button
var button_3: Button

var cards: Array = []
var backdrop: ColorRect = null
var subtitle_label: Label = null
var offered_cards: Array[String] = []
var choosing: bool = false
var active_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("upgrade_dialog")
	visible = false
	theme = preload("res://src/ui/menus/menu_theme.gd").create()
	_setup_visual_elements()

func _setup_visual_elements() -> void:
	# 1. Darkened modal backdrop
	if not backdrop:
		backdrop = ColorRect.new()
		backdrop.name = "ModalBackdrop"
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.color = Color(0.02, 0.05, 0.08, 0.88)
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(backdrop)
		move_child(backdrop, 0) # Behind VBoxContainer

	# 2. Subtitle for level and queued indicators
	if vbox and not subtitle_label:
		subtitle_label = Label.new()
		subtitle_label.name = "Subtitle"
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle_label.add_theme_font_size_override("font_size", 12)
		subtitle_label.add_theme_color_override("font_color", Color(0.45, 0.85, 0.95))
		vbox.add_child(subtitle_label)
		vbox.move_child(subtitle_label, 1)

	# 3. Enhance container layout
	if vbox:
		vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		vbox.add_theme_constant_override("separation", 14)
	if hbox:
		hbox.add_theme_constant_override("separation", 18)

	if title_label:
		title_label.text = "/// TACTICAL AIRFRAME UPGRADE ///"
		title_label.add_theme_font_size_override("font_size", 22)
		title_label.add_theme_color_override("font_color", Color("ffd700"))
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 4. Replace old text buttons with reusable UpgradeCard controls
	if hbox and cards.is_empty():
		# Remove placeholder nodes from tscn
		for child in hbox.get_children():
			child.queue_free()

		for i in range(3):
			var card = UpgradeCardClass.new()
			card.name = "UpgradeCard%d" % (i + 1)
			card.card_selected.connect(_on_card_selected.bind(i))
			hbox.add_child(card)
			cards.append(card)

		button_1 = cards[0]
		button_2 = cards[1]
		button_3 = cards[2]

func show_choices(p_cards: Array[String]) -> void:
	_setup_visual_elements()
	offered_cards = p_cards.duplicate()
	choosing = false

	var player = get_tree().get_first_node_in_group("player")
	var prog = player.get_node_or_null("RunProgression") if player else null
	var lvl = prog.current_run_level if prog else 1
	var queued = prog.queued_level_ups if prog else 0

	if subtitle_label:
		if queued > 1:
			subtitle_label.text = "FIELD SELECTION // LEVEL %d  [+%d PENDING]  -- COMBAT PAUSED" % [lvl, queued - 1]
		else:
			subtitle_label.text = "FIELD SELECTION // LEVEL %d  [SELECT 1 AUGMENTATION]  -- COMBAT PAUSED" % lvl

	# Bind catalog data to each card
	for i in range(cards.size()):
		var card = cards[i]
		if i < offered_cards.size():
			card.visible = true
			card.disabled = false
			card.bind_catalog_data(offered_cards[i], i + 1, player, prog)
		else:
			card.visible = false
			card.disabled = true

	visible = not offered_cards.is_empty()
	if visible:
		# Restrained 180ms entrance animation
		if active_tween:
			active_tween.kill()
		if vbox:
			vbox.scale = Vector2(0.94, 0.94)
			vbox.modulate.a = 0.0
			vbox.pivot_offset = vbox.size * 0.5
			active_tween = create_tween()
			active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			active_tween.set_parallel(true)
			active_tween.tween_property(vbox, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			active_tween.tween_property(vbox, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		if not cards.is_empty() and cards[0].visible:
			cards[0].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or choosing or offered_cards.is_empty():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				_choose_card(0)
				get_viewport().set_input_as_handled()
			KEY_2, KEY_KP_2:
				_choose_card(1)
				get_viewport().set_input_as_handled()
			KEY_3, KEY_KP_3:
				_choose_card(2)
				get_viewport().set_input_as_handled()

func _on_card_selected(_card_id: String, idx: int) -> void:
	_choose_card(idx)

func _on_card_1_selected() -> void:
	_choose_card(0)

func _on_card_2_selected() -> void:
	_choose_card(1)

func _on_card_3_selected() -> void:
	_choose_card(2)

func _choose_card(idx: int) -> void:
	if choosing or not visible or idx < 0 or idx >= offered_cards.size():
		return

	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.has_node("RunProgression"):
		return

	var chosen: String = offered_cards[idx]
	var prog = player.get_node("RunProgression")

	# Safe input release
	if get_viewport():
		get_viewport().set_input_as_handled()

	choosing = true
	visible = false
	offered_cards.clear()

	# Transactional apply
	prog.apply_upgrade_choice(chosen)
