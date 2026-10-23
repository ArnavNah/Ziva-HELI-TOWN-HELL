extends Node



## ShaderManager â€” Manages retro visual style shaders per technical spec:

## 1. Nearest texture sampling: ON (material filter hints & project setting)

## 2. Selective silhouette outlines: ON for player helicopter, hostiles, and hazards

## 3. Toon shading: Optional comparison (smooth Lambert vs 3-tier stepped quantization)

## 4. Screen resampling: optional 2x / 3x pixel blocks; 3D still renders at native resolution

## 5. Vertex snapping: OFF by default (optional toggle)

## 6. Color quantization / dithering: OFF initially (optional toggle)

## 7. Hotkeys F6 - F10 for instantaneous in-game testing and comparison.



const OutlineShader = preload("res://src/shaders/unit_silhouette_outline.gdshader")

const ToonShader = preload("res://src/shaders/tactical_toon.gdshader")

const PixelationShader = preload("res://src/shaders/retro_pixelation.gdshader")



# Configuration States

var nearest_sampling_enabled: bool = true

var outlines_enabled: bool = true

var outline_width: float = 0.008

var outline_color: Color = Color(0.12, 0.14, 0.16, 0.70)



var toon_shading_enabled: bool = false

var pixelation_mode: int = 0 # 0: Native, 1: 2x screen blocks, 2: 3x screen blocks

var dithering_enabled: bool = false

var vertex_snapping_enabled: bool = false



# Tracked materials for live toggling

var _tracked_outline_materials: Array[WeakRef] = []

var _tracked_toon_materials: Array[ShaderMaterial] = []

var _shared_outline_mat: ShaderMaterial = null



func _get_shared_outline_mat() -> ShaderMaterial:

	if not _shared_outline_mat:

		_shared_outline_mat = ShaderMaterial.new()

		_shared_outline_mat.shader = OutlineShader

		_shared_outline_mat.set_shader_parameter("outline_color", outline_color)

		_shared_outline_mat.set_shader_parameter("outline_width", outline_width)

		_shared_outline_mat.set_shader_parameter("outline_enabled", outlines_enabled)

	return _shared_outline_mat



# Post-process canvas layer for world pixelation (sits below 2D UI)

var post_process_layer: CanvasLayer = null

var post_process_rect: ColorRect = null

var post_process_mat: ShaderMaterial = null



# Toast HUD notification

var toast_label: Label = null

var toast_tween: Tween = null



func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS

	_setup_post_process_layer()

	_setup_toast_label()



func _setup_post_process_layer() -> void:

	if post_process_layer and is_instance_valid(post_process_layer):

		return



	# Layer 0 renders between the 3D world (default) and the 2D CombatHUD (layer 1+)

	# This ensures the 3D world is pixelated while the 2D UI stays razor sharp!

	post_process_layer = CanvasLayer.new()

	post_process_layer.name = "WorldRetroPostProcess"

	post_process_layer.layer = 0

	add_child(post_process_layer)



	post_process_rect = ColorRect.new()

	post_process_rect.name = "PixelationFilter"

	post_process_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	post_process_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE



	post_process_mat = ShaderMaterial.new()

	post_process_mat.shader = PixelationShader

	post_process_mat.set_shader_parameter("enable_pixelation", false)

	post_process_mat.set_shader_parameter("pixel_size", 2.0)

	post_process_mat.set_shader_parameter("enable_dither", false)

	post_process_mat.set_shader_parameter("color_depth", 32.0)

	post_process_rect.material = post_process_mat

	post_process_rect.visible = false

	post_process_layer.add_child(post_process_rect)



func _setup_toast_label() -> void:

	var toast_layer = CanvasLayer.new()

	toast_layer.name = "RetroShaderToastLayer"

	toast_layer.layer = 99

	add_child(toast_layer)



	toast_label = Label.new()

	toast_label.name = "ToastLabel"

	toast_label.set_anchors_preset(Control.PRESET_TOP_WIDE)

	toast_label.offset_top = 45.0

	toast_label.offset_bottom = 75.0

	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	toast_label.add_theme_font_size_override("font_size", 14)

	toast_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25, 1.0))

	toast_label.modulate.a = 0.0

	toast_layer.add_child(toast_label)



func show_toast(msg: String) -> void:

	if not toast_label:

		return

	toast_label.text = msg

	if toast_tween and toast_tween.is_valid():

		toast_tween.kill()

	toast_label.modulate.a = 1.0

	toast_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	toast_tween.tween_interval(1.8)

	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)



# --- Selective Silhouette Outline System ------------------------------------



func apply_selective_outline(root_node: Node3D, custom_width: float = -1.0, custom_color: Color = Color(-1, -1, -1)) -> void:

	if not root_node or not is_instance_valid(root_node):

		return



	var width = custom_width if custom_width > 0.0 else outline_width

	var color = custom_color if custom_color.r >= 0.0 else outline_color



	var meshes: Array[MeshInstance3D] = []

	_gather_meshes(root_node, meshes)



	for mesh_inst in meshes:

		_attach_outline_to_mesh(mesh_inst, width, color)



func _gather_meshes(node: Node, out_list: Array[MeshInstance3D]) -> void:

	if node is MeshInstance3D and node.visible:

		var n_lower = node.name.to_lower()

		# Do not outline transparent rotor discs or thin spinning rotor blades (prevents bloated geometry)

		if not n_lower.contains("rotordisc") and not n_lower.contains("rotor_disc") and not n_lower.contains("main_rotor") and not n_lower.contains("tail_rotor") and not n_lower.contains("rotor"):

			out_list.append(node)

	for child in node.get_children():

		_gather_meshes(child, out_list)



func _attach_outline_to_mesh(mesh_inst: MeshInstance3D, width: float, color: Color) -> void:

	if not mesh_inst or not mesh_inst.mesh:

		return

	var outline_mat := _get_shared_outline_mat()

	var had_override := mesh_inst.material_override != null

	for surface in range(1 if had_override else mesh_inst.mesh.get_surface_count()):

		var base_mat := mesh_inst.get_active_material(surface)

		if base_mat:

			if base_mat.next_pass == outline_mat:

				continue

			base_mat.next_pass = outline_mat

		elif had_override:

			mesh_inst.material_override = outline_mat

		else:

			mesh_inst.set_surface_override_material(surface, outline_mat)



func register_world_material(material: ShaderMaterial) -> void:

	if material in _tracked_toon_materials:

		return

	_tracked_toon_materials.append(material)

	material.set_shader_parameter("enable_toon_steps", toon_shading_enabled)

	material.set_shader_parameter("enable_vertex_snapping", vertex_snapping_enabled)



func set_outlines_enabled(enabled: bool) -> void:

	outlines_enabled = enabled

	if _shared_outline_mat:

		_shared_outline_mat.set_shader_parameter("outline_enabled", enabled)

	_clean_tracked_materials()

	for reference in _tracked_outline_materials:

		var mat = reference.get_ref()

		if mat:

			mat.set_shader_parameter("outline_enabled", enabled)



# --- Toon Shading & Vertex Snapping -----------------------------------------



func set_toon_shading_enabled(enabled: bool) -> void:

	toon_shading_enabled = enabled

	_clean_tracked_materials()

	for mat in _tracked_toon_materials:

		if is_instance_valid(mat):

			mat.set_shader_parameter("enable_toon_steps", enabled)



func set_vertex_snapping_enabled(enabled: bool) -> void:

	vertex_snapping_enabled = enabled

	_clean_tracked_materials()

	for mat in _tracked_toon_materials:

		if is_instance_valid(mat):

			mat.set_shader_parameter("enable_vertex_snapping", enabled)



# --- Screen Resampling & Dithering --------------------------------



func set_pixelation_mode(mode: int) -> void:

	pixelation_mode = mode

	if not post_process_mat:

		return

	if post_process_rect:
		post_process_rect.visible = (mode != 0 or dithering_enabled)

	match mode:

		0: # Native 1x

			post_process_mat.set_shader_parameter("enable_pixelation", false)

			post_process_mat.set_shader_parameter("pixel_size", 1.0)

		1: # 2x screen blocks; native 3D render resolution.

			post_process_mat.set_shader_parameter("enable_pixelation", true)

			post_process_mat.set_shader_parameter("pixel_size", 2.0)

		2: # 3x screen blocks; native 3D render resolution.

			post_process_mat.set_shader_parameter("enable_pixelation", true)

			post_process_mat.set_shader_parameter("pixel_size", 3.0)



func set_dithering_enabled(enabled: bool) -> void:

	dithering_enabled = enabled

	if post_process_mat:

		post_process_mat.set_shader_parameter("enable_dither", enabled)

	if post_process_rect:
		post_process_rect.visible = (pixelation_mode != 0 or enabled)



func _clean_tracked_materials() -> void:

	_tracked_outline_materials = _tracked_outline_materials.filter(func(m): return m.get_ref() != null)

	_tracked_toon_materials = _tracked_toon_materials.filter(func(m): return is_instance_valid(m))



# --- Interactive Evaluation Hotkeys -----------------------------------------



func _unhandled_input(event: InputEvent) -> void:

	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():

		return



	var key_event = event as InputEventKey

	match key_event.keycode:

		KEY_F6:

			set_outlines_enabled(!outlines_enabled)

			show_toast("[RETRO SHADERS] Selective Outlines: %s" % ("ENABLED" if outlines_enabled else "DISABLED"))

			get_viewport().set_input_as_handled()

		KEY_F7:

			set_toon_shading_enabled(!toon_shading_enabled)

			show_toast("[RETRO SHADERS] Town Stepped Lighting: %s" % ("ENABLED" if toon_shading_enabled else "DISABLED (Lambert)"))

			get_viewport().set_input_as_handled()

		KEY_F8:

			var next_mode = (pixelation_mode + 1) % 3

			set_pixelation_mode(next_mode)

			var labels = ["NATIVE", "2x SCREEN BLOCKS (native rendering)", "3x SCREEN BLOCKS (native rendering)"]

			show_toast("[RETRO SHADERS] Screen Resampling: %s" % labels[next_mode])

			get_viewport().set_input_as_handled()

		KEY_F9:

			set_dithering_enabled(!dithering_enabled)

			show_toast("[RETRO SHADERS] Bayer Dithering: %s" % ("ENABLED" if dithering_enabled else "DISABLED"))

			get_viewport().set_input_as_handled()

		KEY_F10:

			set_vertex_snapping_enabled(!vertex_snapping_enabled)

			show_toast("[RETRO SHADERS] Town Vertex Snapping: %s" % ("ENABLED" if vertex_snapping_enabled else "DISABLED"))

			get_viewport().set_input_as_handled()

