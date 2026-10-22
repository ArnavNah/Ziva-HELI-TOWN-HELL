class_name BossDecisionDialog
extends Control

## BossDecisionDialog — Climax decision modal appearing upon Wave 10 Boss defeat (Page 22 & 23).
## Allows pilot to either extract safely with full wallet, or continue into Endless Overdrive.

@onready var title_label: Label
@onready var details_label: Label
@onready var extract_btn: Button
@onready var overdrive_btn: Button

var reward_granted: bool = false
var decision_made: bool = false
var pending: bool = false

func _ready() -> void:
	theme = preload("res://src/ui/menus/menu_theme.gd").create()
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui_layout()
	_connect_event_bus()
	get_node("/root/EventBus").run_state_changed.connect(func(state, _previous):
		if state == get_node("/root/GameManager").RunState.ACTIVE and pending:
			_on_boss_defeated.call_deferred()
	)

func _build_ui_layout() -> void:
	for child in get_children():
		child.queue_free()

	# Dark tactical overlay
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.1, 0.92)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 360)
	panel.set_anchors_preset(PRESET_CENTER)
	panel.offset_left = -270
	panel.offset_top = -180
	panel.offset_right = 270
	panel.offset_bottom = 180
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	title_label = Label.new()
	title_label.text = "★ HOSTILE COMMAND GUNSHIP ELIMINATED ★"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	vbox.add_child(title_label)

	var separator = HSeparator.new()
	vbox.add_child(separator)

	details_label = Label.new()
	details_label.text = "TACTICAL SECTOR SECURED!\n\n" \
		+ "• Boss Neutralization Bounty: +1,000 CR\n" \
		+ "• Strategic Salvage Recovered: +10 Salvage\n" \
		+ "• Emergency Field Repairs: +40 Hull Restored\n\n" \
		+ "TACTICAL DIRECTIVE:\n" \
		+ "Extract now to bank all earnings and secure your victory,\n" \
		+ "or enter ENDLESS OVERDRIVE (Wave 11+) for escalating combat pay and higher threat rewards!"
	details_label.add_theme_font_size_override("font_size", 14)
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(details_label)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_hbox)

	extract_btn = Button.new()
	extract_btn.text = "SECURE EXTRACTION (VICTORY)"
	extract_btn.custom_minimum_size = Vector2(230, 48)
	extract_btn.pressed.connect(_on_extract_pressed)
	btn_hbox.add_child(extract_btn)

	overdrive_btn = Button.new()
	overdrive_btn.text = "ENTER ENDLESS OVERDRIVE"
	overdrive_btn.custom_minimum_size = Vector2(230, 48)
	overdrive_btn.pressed.connect(_on_overdrive_pressed)
	btn_hbox.add_child(overdrive_btn)

func _connect_event_bus() -> void:
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").boss_defeated.connect(_on_boss_defeated)

func _on_boss_defeated() -> void:
	var manager = get_node("/root/GameManager")
	if decision_made or (visible and reward_granted) or manager.current_state == manager.RunState.RESULTS:
		return
	var upgrade = get_parent().get_node_or_null("UpgradeDialog")
	var draft = get_parent().get_node_or_null("LevelUpUi")
	var xp = get_node_or_null("/root/XpManager")
	if (upgrade and upgrade.visible) or (draft and draft.is_choosing) or (xp and xp.has_pending_level_ups()):
		pending = true
		manager.change_state(manager.RunState.UPGRADE_CHOICE)
		return
	pending = false
	# Show modal and pause action
	visible = true
	get_tree().paused = true
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.change_state(gm.RunState.BOSS_DECISION)
		# HeavyGunshipBoss settles its bounty, salvage and repair once on destruction.
		# Presenting/reopening the decision is not a second reward source.
		reward_granted = true
	if extract_btn:
		extract_btn.grab_focus()

func _on_extract_pressed() -> void:
	if decision_made or not visible:
		return
	decision_made = true
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("ui_click")
	visible = false
	get_tree().paused = false
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.settle_extraction(true, "Flagship Boss Destroyed")

func _on_overdrive_pressed() -> void:
	if decision_made or not visible:
		return
	decision_made = true
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("ui_click")
	visible = false
	get_tree().paused = false
	var overdrive = get_tree().get_first_node_in_group("endless_overdrive")
	if not overdrive:
		var parent = get_parent()
		if parent:
			overdrive = parent.get_node_or_null("EndlessOverdrive")
	if overdrive and overdrive.has_method("activate_endless_overdrive"):
		overdrive.activate_endless_overdrive()
	elif has_node("/root/CombatDirector"):
		get_node("/root/CombatDirector")._setup_wave(11)
	get_node("/root/GameManager").change_state(get_node("/root/GameManager").RunState.ACTIVE)
	get_node("/root/UIFlow").block_held_input()
	var draft = get_parent().get_node_or_null("LevelUpUi")
	if draft:
		draft._present_pending.call_deferred()
