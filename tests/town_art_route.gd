extends SceneTree
## Same saved camera, seed and route for before/after art comparisons.
var label := "before"
var game: Node3D
var player: Node3D
var camera: Camera3D

func _init() -> void:
    call_deferred("run")

func capture(name: String) -> void:
    for i in 30:
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://artifacts/town-art-pass-20261017/" + label + "_" + name + ".png")

func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--label="):
            label = arg.trim_prefix("--label=")
    seed(811)
    game = load("res://scenes/main_game.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    root.get_node("CombatDirector").stop_wave_director()
    root.get_node("GameManager").set_process(false)
    player = game.get_node("PlayerHelicopter")
    player.is_invulnerable = true
    player.set_physics_process(false)
    camera = player.get_node("PlayerCamera")
    camera.init_camera(player)
    await capture("takeoff")
    # A reproducible move and turn through the streets, using the real follow camera.
    for frame in 120:
        player.position = Vector3(0, 14, -float(frame) * 0.6)
        await process_frame
    await capture("street")
    for frame in 90:
        player.rotation.y = -float(frame) * PI / 180.0
        player.position = Vector3(float(frame) * 0.6, 14, -72)
        await process_frame
    await capture("turn")
    var weather = game.get_node("WeatherSystem")
    weather._on_wave_started(8, "Night Surge", 30)
    await create_timer(3.15).timeout
    await capture("night")
    weather._on_wave_started(9, "Storm Surge", 30)
    await create_timer(2.2).timeout
    await capture("storm")
    print("ART ROUTE COMPLETE: ", label, "; aircraft meshes: ", player.visual_hull.find_children("*", "MeshInstance3D", true, false).size())
    quit()
