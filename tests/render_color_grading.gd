extends SceneTree
var failed := false
var checks := 0
func _init() -> void:
    call_deferred("run")
func check(condition: bool, label: String) -> void:
    checks += 1
    failed = failed or not condition
    print("PASS: " if condition else "FAIL: ", label)
func difference(a: Color, b: Color) -> float:
    return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
func capture(path: String) -> Image:
    await RenderingServer.frame_post_draw
    var frame := root.get_texture().get_image()
    frame.save_png(path)
    return frame
func run() -> void:
    seed(1337)
    var game = load("res://scenes/main_game.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    root.get_node("CombatDirector").stop_wave_director()
    root.get_node("GameManager").set_process(false)
    var player = game.get_node("PlayerHelicopter")
    player.set_physics_process(false)
    player.set_process(false)
    var weather = game.get_node("WeatherSystem")
    var rect = weather.get_node("BattlefieldGrade/GradeRect")
    await create_timer(0.8).timeout
    var day: Image = await capture("res://artifacts/color_grade_day.png")
    rect.visible = false
    var bypass: Image = await capture("res://artifacts/color_grade_bypass.png")
    check(difference(day.get_pixel(640, 650), bypass.get_pixel(640, 650)) > 0.01, "Grade visibly affects the rendered battlefield")
    check(difference(day.get_pixel(60, 65), bypass.get_pixel(60, 65)) < 0.001, "HUD health bar keeps its original color")
    rect.visible = true
    weather._on_wave_started(8, "Night Surge", 30)
    await create_timer(3.15).timeout
    var night: Image = await capture("res://artifacts/color_grade_night.png")
    check(night.get_pixel(640, 650).get_luminance() < day.get_pixel(640, 650).get_luminance(), "Night transition produces a distinct darker battlefield")
    check(difference(day.get_pixel(60, 65), night.get_pixel(60, 65)) < 0.001, "Night grading keeps the HUD readable")
    weather._on_wave_started(9, "Storm Surge", 30)
    await create_timer(2.2).timeout
    var storm: Image = await capture("res://artifacts/color_grade_storm.png")
    check(difference(storm.get_pixel(640, 650), night.get_pixel(640, 650)) > 0.01, "Storm transitions change the lighting and grade")
    weather._on_wave_started(11, "Normal", 30)
    await create_timer(2.65).timeout
    var restored: Image = await capture("res://artifacts/color_grade_restored.png")
    check(difference(restored.get_pixel(640, 650), day.get_pixel(640, 650)) < 0.025, "Returning to daylight restores the intended palette")
    print("COLOR GRADE RENDER CHECKS: ", checks, "/", checks if not failed else 0)
    quit(1 if failed else 0)
