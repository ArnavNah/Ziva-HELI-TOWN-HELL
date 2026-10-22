extends SceneTree
func _init() -> void:
    call_deferred("run")

func run() -> void:
    seed(1337)
    var game = load("res://scenes/main_game.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    root.get_node("CombatDirector").is_wave_active = false
    var player = game.get_node("PlayerHelicopter")
    player.is_invulnerable = true
    player.set_physics_process(false)
    var spawner = game.get_node("EnemySpawner")
    for item in [["rocket_buggy", Vector3(-2, 0.1, -30)], ["flame_tank", Vector3(2, 0.1, -49)], ["rail_crawler", Vector3(-3, 0.1, -68)], ["hunter_drone", Vector3(-16, 20, -30)], ["torpedo_vtol", Vector3(20, 26, -48)], ["escort_fighter", Vector3(26, 28, -69)]]:
        var unit = spawner.spawn_enemy_type(item[0], item[1])
        unit.set_physics_process(false)
    var camera = player.get_node("PlayerCamera")
    camera.init_camera(player)
    await create_timer(0.6).timeout
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://artifacts/strike_meadow_gameplay.png")
    var city = game.get_node("CityGenerator")
    var nearest_knoll: Node3D = null
    for feature in city.get_node("FieldDressing").get_children():
        if feature is StaticBody3D and (nearest_knoll == null or feature.position.length() < nearest_knoll.position.length()):
            nearest_knoll = feature
    if nearest_knoll:
        player.position = nearest_knoll.position + Vector3(0, 14, 16)
        camera.init_camera(player)
    await create_timer(0.6).timeout
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://artifacts/strike_meadow_landscape.png")
    print("Saved gameplay and landscape previews")
    quit()
