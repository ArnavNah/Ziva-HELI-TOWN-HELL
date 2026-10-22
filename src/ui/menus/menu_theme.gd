extends RefCounted
static func create() -> Theme:
	var result := Theme.new()
	result.default_font_size = 17
	for type in ["Button", "OptionButton", "CheckBox"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("183239")
			style.border_color = Color("3e6970")
			if state == "hover":
				style.bg_color = Color("284c52")
			if state == "pressed":
				style.bg_color = Color("33665d")
			if state == "disabled":
				style.bg_color = Color("1c282c")
			if state == "focus":
				style.bg_color = Color.TRANSPARENT
				style.border_color = Color("ffd275")
			style.set_border_width_all(2)
			style.content_margin_left = 12
			style.content_margin_right = 12
			style.content_margin_top = 8
			style.content_margin_bottom = 8
			result.set_stylebox(state, type, style)
		result.set_color("font_color", type, Color("e1ece2"))
		result.set_color("font_disabled_color", type, Color("71888d"))
		result.set_color("font_focus_color", type, Color("fff0c5"))
	result.set_color("font_color", "Label", Color("e1ece2"))
	return result
