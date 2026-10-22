class_name UpgradeCardButton
extends Button

## UpgradeCardButton — Tactical military upgrade card control for the level-up selection modal.
## Features procedural vector iconography, category pills, dynamic before/after stat rows,
## and full keyboard/gamepad focus affordances (Spec Phase 3).

const UpgradeCatalog = preload("res://src/player/upgrade_catalog.gd")

signal card_selected(card_id: String)

var card_id: String = ""
var card_title: String = ""
var shortcut_index: int = 1
var is_card_focused: bool = false
var icon_type: String = "bullet"

# Child layout nodes
var main_margin: MarginContainer
var main_vbox: VBoxContainer
var header_hbox: HBoxContainer
var category_label: Label
var shortcut_label: Label
var title_label: Label
var scope_label: Label
var desc_label: Label
var stats_panel: PanelContainer
var stats_hbox: HBoxContainer
var stat_current_label: Label
var stat_arrow_label: Label
var stat_next_label: Label
var footer_label: Label
var icon_control: Control

func _init() -> void:
	custom_minimum_size = Vector2(290, 240)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	flat = true
	focus_mode = Control.FOCUS_ALL

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	pressed.connect(_on_pressed)
	_build_card_ui()

func _build_card_ui() -> void:
	if main_margin:
		return

	main_margin = MarginContainer.new()
	main_margin.name = "MainMargin"
	main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	main_margin.add_theme_constant_override("margin_left", 14)
	main_margin.add_theme_constant_override("margin_right", 14)
	main_margin.add_theme_constant_override("margin_top", 12)
	main_margin.add_theme_constant_override("margin_bottom", 12)
	add_child(main_margin)

	main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	main_vbox.add_theme_constant_override("separation", 6)
	main_margin.add_child(main_vbox)

	# 1. Header Row: Category Badge & Shortcut Tag
	header_hbox = HBoxContainer.new()
	header_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	main_vbox.add_child(header_hbox)

	category_label = Label.new()
	category_label.name = "CategoryLabel"
	category_label.text = "[ OFFENSE ]"
	category_label.add_theme_font_size_override("font_size", 10)
	category_label.add_theme_color_override("font_color", Color("ffd700"))
	header_hbox.add_child(category_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_PASS
	header_hbox.add_child(spacer)

	shortcut_label = Label.new()
	shortcut_label.name = "ShortcutLabel"
	shortcut_label.text = "[ 1 ]"
	shortcut_label.add_theme_font_size_override("font_size", 10)
	shortcut_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92, 0.85))
	header_hbox.add_child(shortcut_label)

	# 2. Icon + Title Row
	var title_row = HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	title_row.add_theme_constant_override("separation", 10)
	main_vbox.add_child(title_row)

	icon_control = Control.new()
	icon_control.name = "TacticalIcon"
	icon_control.custom_minimum_size = Vector2(36, 36)
	icon_control.mouse_filter = Control.MOUSE_FILTER_PASS
	icon_control.draw.connect(_on_draw_icon)
	title_row.add_child(icon_control)

	var title_vbox = VBoxContainer.new()
	title_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 1)
	title_row.add_child(title_vbox)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "OVERCLOCK ROUNDS"
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.95))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_vbox.add_child(title_label)

	scope_label = Label.new()
	scope_label.name = "ScopeLabel"
	scope_label.text = "PERMANENT // RANK 1/5"
	scope_label.add_theme_font_size_override("font_size", 9)
	scope_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.72))
	title_vbox.add_child(scope_label)

	# 3. Description
	desc_label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.text = "+15% Weapon Damage across all equipped ordnance."
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.82, 0.85, 0.88))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(0, 36)
	main_vbox.add_child(desc_label)

	# 4. Before -> After Stat Row
	stats_panel = PanelContainer.new()
	stats_panel.name = "StatsPanel"
	stats_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.08, 0.11, 0.75)
	sb.border_color = Color(0.18, 0.28, 0.35, 0.65)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	stats_panel.add_theme_stylebox_override("panel", sb)
	main_vbox.add_child(stats_panel)

	stats_hbox = HBoxContainer.new()
	stats_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_panel.add_child(stats_hbox)

	stat_current_label = Label.new()
	stat_current_label.text = "10.0 dmg"
	stat_current_label.add_theme_font_size_override("font_size", 11)
	stat_current_label.add_theme_color_override("font_color", Color(0.70, 0.75, 0.80))
	stats_hbox.add_child(stat_current_label)

	stat_arrow_label = Label.new()
	stat_arrow_label.text = "  →  "
	stat_arrow_label.add_theme_font_size_override("font_size", 11)
	stat_arrow_label.add_theme_color_override("font_color", Color("f4b653"))
	stats_hbox.add_child(stat_arrow_label)

	stat_next_label = Label.new()
	stat_next_label.text = "11.5 dmg"
	stat_next_label.add_theme_font_size_override("font_size", 11)
	stat_next_label.add_theme_color_override("font_color", Color("4deeea"))
	stats_hbox.add_child(stat_next_label)

	# 5. Selection Prompt Footer
	footer_label = Label.new()
	footer_label.name = "FooterLabel"
	footer_label.text = "[ PRESS ENTER OR CLICK TO CONFIRM ]"
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.add_theme_font_size_override("font_size", 9)
	footer_label.add_theme_color_override("font_color", Color("f4b653"))
	footer_label.modulate.a = 0.0 # Highlighted when focused/hovered
	main_vbox.add_child(footer_label)

func bind_catalog_data(identifier: String, p_index: int, player: Node3D, progression: Node) -> void:
	_build_card_ui()
	shortcut_index = p_index
	card_title = identifier
	var entry: Dictionary = UpgradeCatalog.get_entry(identifier)
	if entry.is_empty():
		# Fallback display for custom titles
		card_id = identifier
		title_label.text = identifier.to_upper()
		category_label.text = "[ TACTICAL ]"
		shortcut_label.text = "[ %d ]" % shortcut_index
		desc_label.text = "Field combat upgrade."
		scope_label.text = "AUGMENT"
		stat_current_label.text = "Standard"
		stat_next_label.text = "Upgraded"
		icon_type = "bullet"
		queue_redraw()
		return

	card_id = entry.get("id", "")
	var cat: String = entry.get("category", "OFFENSE")
	var rarity: String = entry.get("rarity", "COMMON")
	icon_type = entry.get("icon_key", "bullet")

	# Title & category
	title_label.text = entry.get("title", identifier).to_upper()
	category_label.text = "[ %s ]" % cat
	shortcut_label.text = "[ %d ]" % shortcut_index
	desc_label.text = entry.get("description", "")

	# Category colors
	match cat:
		"OFFENSE":
			category_label.add_theme_color_override("font_color", Color("e25344"))
		"DEFENSE":
			category_label.add_theme_color_override("font_color", Color("3ec6a6"))
		"MOBILITY":
			category_label.add_theme_color_override("font_color", Color("f4b653"))
		"TACTICAL":
			category_label.add_theme_color_override("font_color", Color("48b888"))
		"EVOLUTION":
			category_label.add_theme_color_override("font_color", Color("00e5ff"))
		"LEGENDARY":
			category_label.add_theme_color_override("font_color", Color("ffd700"))

	# Rank and scope
	var max_rank: int = entry.get("max_rank", 5)
	var cur_rank: int = progression.upgrade_stacks.get(card_id, 0) if progression and "upgrade_stacks" in progression else 0
	if max_rank > 1 and max_rank < 90:
		scope_label.text = "%s // RANK %d/%d" % [entry.get("scope", "PERMANENT"), cur_rank, max_rank]
	else:
		scope_label.text = "%s // %s" % [entry.get("scope", "PERMANENT"), rarity]

	# Preview values
	var preview: Dictionary = UpgradeCatalog.get_effective_preview(entry, player, cur_rank)
	stat_current_label.text = preview.get("current_text", "--")
	stat_next_label.text = preview.get("next_text", "--")
	text = "%s  [%s]\n%s" % [shortcut_label.text, cat, title_label.text]
	add_theme_color_override("font_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_focus_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))

	queue_redraw()
	if icon_control:
		icon_control.queue_redraw()

func _draw() -> void:
	# Tactical Aviation Panel Background & Border
	var rect = Rect2(Vector2.ZERO, size)
	var bg_color = Color(0.08, 0.11, 0.14, 0.94)
	var border_color = Color(0.24, 0.32, 0.38, 0.85)
	var border_width = 1.5

	if is_card_focused or has_focus():
		bg_color = Color(0.12, 0.16, 0.20, 0.97)
		border_color = Color("f4b653") # Tactical Alert Amber
		border_width = 2.5
	elif is_hovered():
		bg_color = Color(0.10, 0.14, 0.17, 0.96)
		border_color = Color(0.45, 0.70, 0.85, 0.95)
		border_width = 2.0

	draw_rect(rect, bg_color, true)
	draw_rect(rect, border_color, false, border_width)

	# Tactical corner markers
	var corner_len = 8.0
	var c_col = border_color
	# Top-left
	draw_line(Vector2(2, 2), Vector2(2 + corner_len, 2), c_col, 2.0)
	draw_line(Vector2(2, 2), Vector2(2, 2 + corner_len), c_col, 2.0)
	# Top-right
	draw_line(Vector2(size.x - 2, 2), Vector2(size.x - 2 - corner_len, 2), c_col, 2.0)
	draw_line(Vector2(size.x - 2, 2), Vector2(size.x - 2, 2 + corner_len), c_col, 2.0)
	# Bottom-left
	draw_line(Vector2(2, size.y - 2), Vector2(2 + corner_len, size.y - 2), c_col, 2.0)
	draw_line(Vector2(2, size.y - 2), Vector2(2, size.y - 2 - corner_len), c_col, 2.0)
	# Bottom-right
	draw_line(Vector2(size.x - 2, size.y - 2), Vector2(size.x - 2 - corner_len, size.y - 2), c_col, 2.0)
	draw_line(Vector2(size.x - 2, size.y - 2), Vector2(size.x - 2, size.y - 2 - corner_len), c_col, 2.0)

func _on_draw_icon() -> void:
	if not icon_control:
		return
	var rect = Rect2(Vector2.ZERO, icon_control.size)
	# Icon box background
	icon_control.draw_rect(rect, Color(0.04, 0.07, 0.10, 0.9), true)
	icon_control.draw_rect(rect, Color(0.25, 0.38, 0.45, 0.8), false, 1.0)

	var center = rect.get_center()
	var draw_col = Color("ffd700") if (is_card_focused or has_focus()) else Color(0.40, 0.85, 0.95)

	# Procedural tactical vector icon based on icon_type
	match icon_type:
		"bullet", "vulcan":
			# Heavy artillery bullet / rotary barrel
			icon_control.draw_rect(Rect2(center.x - 4, center.y - 6, 8, 14), draw_col, false, 1.5)
			icon_control.draw_line(Vector2(center.x - 4, center.y - 6), Vector2(center.x, center.y - 12), draw_col, 1.5)
			icon_control.draw_line(Vector2(center.x + 4, center.y - 6), Vector2(center.x, center.y - 12), draw_col, 1.5)
		"ammo":
			# Ammunition magazine box
			icon_control.draw_rect(Rect2(center.x - 8, center.y - 10, 16, 20), draw_col, false, 1.5)
			icon_control.draw_line(Vector2(center.x - 8, center.y - 2), Vector2(center.x + 8, center.y - 2), draw_col, 1.0)
			icon_control.draw_line(Vector2(center.x - 8, center.y + 4), Vector2(center.x + 8, center.y + 4), draw_col, 1.0)
		"shield", "aegis", "juggernaut":
			# Hexagonal tactical shield
			var pts = PackedVector2Array([
				Vector2(center.x, center.y - 12),
				Vector2(center.x + 10, center.y - 6),
				Vector2(center.x + 10, center.y + 5),
				Vector2(center.x, center.y + 12),
				Vector2(center.x - 10, center.y + 5),
				Vector2(center.x - 10, center.y - 6)
			])
			icon_control.draw_polyline(pts, draw_col, 1.5)
			icon_control.draw_line(pts[0], pts[5], draw_col, 1.5)
		"armor":
			# Angular armored composite plate
			icon_control.draw_rect(Rect2(center.x - 9, center.y - 9, 18, 18), draw_col, false, 1.5)
			icon_control.draw_rect(Rect2(center.x - 5, center.y - 5, 10, 10), draw_col, true)
		"reload", "trigger":
			# Circular cycle arrow
			icon_control.draw_arc(center, 9.0, 0.4, 5.8, 16, draw_col, 1.5)
			icon_control.draw_line(Vector2(center.x + 7, center.y + 5), Vector2(center.x + 11, center.y + 3), draw_col, 1.5)
		"salvo", "phantom":
			# Dual angled rockets
			for sx in [-4.0, 4.0]:
				icon_control.draw_line(Vector2(center.x + sx, center.y + 8), Vector2(center.x + sx, center.y - 8), draw_col, 2.0)
				icon_control.draw_line(Vector2(center.x + sx - 2, center.y + 6), Vector2(center.x + sx + 2, center.y + 6), draw_col, 1.0)
		"jet", "predator", "ghost":
			# Arrowhead jet delta-wing silhouette
			var pts = PackedVector2Array([
				Vector2(center.x, center.y - 11),
				Vector2(center.x + 11, center.y + 9),
				Vector2(center.x, center.y + 4),
				Vector2(center.x - 11, center.y + 9),
				Vector2(center.x, center.y - 11)
			])
			icon_control.draw_polyline(pts, draw_col, 1.5)
		"fuel":
			# Fuel container droplet
			icon_control.draw_circle(Vector2(center.x, center.y + 2), 6.5, draw_col)
			icon_control.draw_line(Vector2(center.x - 5, center.y + 1), Vector2(center.x, center.y - 8), draw_col, 1.5)
			icon_control.draw_line(Vector2(center.x + 5, center.y + 1), Vector2(center.x, center.y - 8), draw_col, 1.5)
		"repair":
			# Maintenance cross
			icon_control.draw_line(Vector2(center.x - 8, center.y), Vector2(center.x + 8, center.y), draw_col, 3.0)
			icon_control.draw_line(Vector2(center.x, center.y - 8), Vector2(center.x, center.y + 8), draw_col, 3.0)
		"airstrike", "skull":
			# Crosshair target circle
			icon_control.draw_circle(center, 3.0, draw_col)
			icon_control.draw_arc(center, 9.0, 0, TAU, 16, draw_col, 1.5)
			icon_control.draw_line(Vector2(center.x - 12, center.y), Vector2(center.x + 12, center.y), draw_col, 1.0)
			icon_control.draw_line(Vector2(center.x, center.y - 12), Vector2(center.x, center.y + 12), draw_col, 1.0)
		_:
			# Default diamond augment badge
			var pts = PackedVector2Array([
				Vector2(center.x, center.y - 9),
				Vector2(center.x + 9, center.y),
				Vector2(center.x, center.y + 9),
				Vector2(center.x - 9, center.y),
				Vector2(center.x, center.y - 9)
			])
			icon_control.draw_polyline(pts, draw_col, 1.5)

func _update_state_visuals() -> void:
	if footer_label:
		footer_label.modulate.a = 1.0 if (is_card_focused or has_focus() or is_hovered()) else 0.0
	queue_redraw()
	if icon_control:
		icon_control.queue_redraw()

func _on_mouse_entered() -> void:
	_update_state_visuals()

func _on_mouse_exited() -> void:
	_update_state_visuals()

func _on_focus_entered() -> void:
	is_card_focused = true
	_update_state_visuals()

func _on_focus_exited() -> void:
	is_card_focused = false
	_update_state_visuals()

func _on_pressed() -> void:
	card_selected.emit(card_id if not card_id.is_empty() else card_title)
