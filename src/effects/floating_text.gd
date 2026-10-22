class_name FloatingText
extends Label3D

## FloatingText — 3D billboarded floating combat text with arcade pixel typography,
## punchy scale bounce, clean vertical stack, and auto-cleanup.

enum TextType {
	DAMAGE_NORMAL,
	DAMAGE_CRIT,
	COMPLIMENT,
	BOUNTY
}

static var pixel_font: Font = null

static func get_pixel_font() -> Font:
	if pixel_font == null:
		var font_file = FontFile.new()
		var font_path = "res://src/effects/press_start_2p.ttf"
		if FileAccess.file_exists(font_path):
			var bytes = FileAccess.get_file_as_bytes(font_path)
			if bytes.size() > 0:
				font_file.data = bytes
				font_file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
				pixel_font = font_file
		if pixel_font == null:
			var sys = SystemFont.new()
			sys.font_names = PackedStringArray(["Impact", "Arial Black", "Sans-Serif"])
			sys.font_weight = 800
			pixel_font = sys
	return pixel_font

func setup(
	text_str: String,
	world_pos: Vector3,
	type: TextType = TextType.DAMAGE_NORMAL,
	custom_color: Color = Color.WHITE,
	duration: float = 0.85
) -> void:
	# Callers may defer adding labels during physics callbacks. Initialize transforms
	# and tweens only after the label has actually entered the scene tree.
	if not is_inside_tree():
		tree_entered.connect(setup.bind(text_str, world_pos, type, custom_color, duration), CONNECT_ONE_SHOT)
		return
	font = get_pixel_font()
	text = text_str
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	render_priority = 20
	outline_render_priority = 19
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line_spacing = 4
	global_position = world_pos
	rotation = Vector3.ZERO
	
	var peak_scale: float = 1.35
	var base_scale: float = 1.0
	var float_height: float = 2.0
	var outline_col: Color = Color.BLACK
	var main_col: Color = custom_color
	var pixel_sz: float = 0.022
	
	match type:
		TextType.DAMAGE_NORMAL:
			font_size = 24
			outline_size = 6
			pixel_sz = 0.030
			peak_scale = 1.35
			base_scale = 1.0
			float_height = 8.5
			main_col = Color(1.0, 0.90, 0.05, 1.0) if custom_color == Color.WHITE else custom_color
			duration = 1.05

		TextType.DAMAGE_CRIT:
			font_size = 32
			outline_size = 8
			pixel_sz = 0.034
			peak_scale = 1.55
			base_scale = 1.15
			float_height = 10.0
			main_col = Color(1.0, 0.92, 0.0, 1.0) if custom_color == Color.WHITE else custom_color
			duration = 1.15

		TextType.COMPLIMENT:
			font_size = 36
			outline_size = 9
			pixel_sz = 0.036
			peak_scale = 1.6
			base_scale = 1.2
			float_height = 11.5
			main_col = Color(1.0, 0.92, 0.1, 1.0) if custom_color == Color.WHITE else custom_color
			duration = 1.25

		TextType.BOUNTY:
			font_size = 24
			outline_size = 6
			pixel_sz = 0.028
			peak_scale = 1.3
			base_scale = 1.0
			float_height = 8.0
			main_col = Color(1.0, 0.88, 0.15, 1.0) if custom_color == Color.WHITE else custom_color
			duration = 0.95

	pixel_size = pixel_sz
	modulate = Color(1.4, 1.4, 1.4, 1.0)
	outline_modulate = outline_col

	scale = Vector3(0.1, 0.1, 0.1)

	var tween = create_tween()
	tween.set_parallel(true)

	# 0. Color flash from white to gold
	var flash_tween = create_tween()
	flash_tween.tween_interval(0.05)
	flash_tween.tween_property(self, "modulate", main_col, 0.07)

	# 1. Scale punch & settle
	var scale_tween = create_tween()
	scale_tween.tween_property(self, "scale", Vector3.ONE * peak_scale, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(self, "scale", Vector3.ONE * base_scale, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 2. Animate flying to the top (high upward trajectory towards sky/top of screen)
	tween.tween_property(self, "global_position:y", global_position.y + float_height, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 3. Fade out as it ascends to the top
	var hold_time = duration * 0.35
	var fade_time = duration - hold_time
	var fade_tween = create_tween()
	fade_tween.tween_interval(hold_time)
	fade_tween.tween_property(self, "modulate:a", 0.0, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var outline_fade = create_tween()
	outline_fade.tween_interval(hold_time)
	outline_fade.tween_property(self, "outline_modulate:a", 0.0, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 4. Auto free
	fade_tween.tween_callback(queue_free)
