extends PanelContainer
var title: Label
var health: ProgressBar
var detail: Label
var refresh := 0.0
func _ready() -> void:
	name = "BossTracker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10202ae8")
	style.border_color = Color("dfae66")
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	column.add_child(title)
	health = ProgressBar.new()
	health.custom_minimum_size.y = 12
	health.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("e4b65c")
	var track := StyleBoxFlat.new()
	track.bg_color = Color("263b46")
	health.add_theme_stylebox_override("fill", fill)
	health.add_theme_stylebox_override("background", track)
	health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(health)
	detail = Label.new()
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 11)
	column.add_child(detail)
	hide()
func _process(delta: float) -> void:
	refresh -= delta
	if refresh > 0.0: return
	refresh = 0.1
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.current_state not in [gm.RunState.ACTIVE, gm.RunState.PAUSED, gm.RunState.UPGRADE_CHOICE]:
		hide()
		return
	var boss: Node = null
	for candidate in get_tree().get_nodes_in_group("bosses"):
		if not candidate.is_queued_for_deletion() and candidate.has_node("DamageReceiver") and not candidate.get_node("DamageReceiver").is_dead:
			boss = candidate
			break
	if boss == null:
		hide()
		return
	var width := minf(380, get_viewport_rect().size.x * 0.42)
	position = Vector2((get_viewport_rect().size.x - width) * 0.5, 112)
	size.x = width
	title.text = boss.boss_title if "boss_title" in boss else "HEAVY GUNSHIP"
	var receiver = boss.get_node("DamageReceiver")
	health.max_value = receiver.max_health
	health.value = receiver.current_health
	detail.text = "PHASE %d  /  CORE %d%%" % [4 - int(boss.current_stage), roundi(receiver.current_health / receiver.max_health * 100)]
	if boss.has_method("core_exposed"):
		detail.text += "  /  CORE EXPOSED" if boss.core_exposed() else ("  /  DESTROY ENGINES" if boss.fortress_kind == "air" else "  /  BATTERY + RADAR")
	show()
