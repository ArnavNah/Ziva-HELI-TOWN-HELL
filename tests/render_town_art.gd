extends SceneTree
var checks := 0
var failures := 0
const OUT := "res://artifacts/town-art-pass-20261017/"

func _init() -> void:
	call_deferred("run")

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", text)

func capture(name: String) -> Image:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	frame.save_png(OUT + name + ".png")
	return frame

func changed_pixels(a: Image, b: Image) -> int:
	var total := 0
	for y in range(60, 660, 4):
		for x in range(20, 1260, 4):
			var ca := a.get_pixel(x,y)
			var cb := b.get_pixel(x,y)
			if absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b) > 0.04: total += 1
	return total

func hud_unchanged(a: Image, b: Image) -> bool:
	var glyph_pixels := 0
	for y in range(680, 704):
		for x in range(20, 1260):
			var pixel := a.get_pixel(x, y)
			if pixel.r > 0.95 and pixel.g > 0.95 and pixel.b > 0.95:
				glyph_pixels += 1
				if pixel != b.get_pixel(x, y): return false
	return glyph_pixels > 300

func run() -> void:
	DisplayServer.window_move_to_foreground()
	var scene = load("res://scenes/world/town_art_review.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var player = scene.player
	player.set_physics_process(false)
	player.set_process(false)
	var camera = player.get_node("PlayerCamera")
	camera.set_process(false)
	camera.init_camera(player)
	await create_timer(0.5).timeout
	var smooth: Image = await capture("review_day")
	root.get_node("ShaderManager").set_dithering_enabled(true)
	var dithered: Image = await capture("review_dither")
	check(changed_pixels(smooth, dithered) > 100, "F9 dithering changes the rendered world")
	root.get_node("ShaderManager").set_dithering_enabled(false)
	root.get_node("ShaderManager").set_outlines_enabled(false)
	var unoutlined: Image = await capture("review_no_outlines")
	check(changed_pixels(smooth, unoutlined) > 0, "F6 outlines change the aircraft silhouette")
	root.get_node("ShaderManager").set_outlines_enabled(true)
	root.get_node("ShaderManager").set_toon_shading_enabled(true)
	var stepped: Image = await capture("review_stepped")
	check(changed_pixels(smooth, stepped) > 150, "F7 lighting changes visible painted surfaces")
	root.get_node("ShaderManager").set_toon_shading_enabled(false)
	root.get_node("ShaderManager").set_vertex_snapping_enabled(true)
	var snapped: Image = await capture("review_snap")
	check(changed_pixels(smooth, snapped) > 20, "F10 snapping changes projected town geometry")
	root.get_node("ShaderManager").set_vertex_snapping_enabled(false)
	root.get_node("ShaderManager").set_pixelation_mode(1)
	var blocks: Image = await capture("review_screen_blocks")
	check(changed_pixels(smooth, blocks) > 100, "F8 screen resampling remains visible through the existing grade")
	check(hud_unchanged(smooth, blocks), "Review HUD stays outside screen resampling")
	root.get_node("ShaderManager").set_pixelation_mode(0)
	player.position = scene.house.position + Vector3(0, 10, 23)
	camera.init_camera(player)
	var intact: Image = await capture("house_intact")
	var house = scene.house
	var material_before = house.mesh_instance.get_active_material(0)
	var affinity: float = GameConstants.DAMAGE_AFFINITY_MATRIX[GameConstants.WeaponType.ROCKET][GameConstants.TargetAffinity.STRUCTURE]
	house.damage_receiver.take_damage(DamageData.new(house.max_building_health * 0.65 / affinity, GameConstants.WeaponType.ROCKET))
	await create_timer(1.5).timeout
	var damaged: Image = await capture("house_damaged")
	check(house.current_stage == 1 and changed_pixels(intact, damaged) > 100, "Actual combat damage makes a visible missing roof/wall section")
	check(house.mesh_instance.get_active_material(0) != material_before and material_before.get_shader_parameter("damage_amount") == 0.0, "Damage leaves the shared intact material untouched")
	house.damage_receiver.take_damage(DamageData.new(house.max_building_health * 2.0, GameConstants.WeaponType.ROCKET))
	await create_timer(4.0).timeout
	var collapsed: Image = await capture("house_collapsed")
	check(house.current_stage == 2 and changed_pixels(damaged, collapsed) > 100, "Collapse produces a visible low rubble shell")
	check(is_equal_approx(house.collision_shape.shape.size.y, 3.5), "Collapsed flight clearance stays at 3.5m")
	var weather = scene.get_node("WeatherSystem")
	weather._on_wave_started(8, "Night Surge", 30)
	await create_timer(3.15).timeout
	await capture("review_night")
	weather._on_wave_started(9, "Storm Surge", 30)
	await create_timer(2.2).timeout
	await capture("review_storm")
	print("TOWN ART RENDER CHECKS: ", checks-failures, "/", checks)
	quit(1 if failures else 0)
