extends SceneTree
var failed := false
func _init() -> void:
    call_deferred("run")
func check(condition: bool, description: String) -> void:
    print("PASS: " if condition else "FAIL: ", description)
    failed = failed or not condition
func run() -> void:
    seed(961)
    var game = load("res://scenes/main_game.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    var player = game.get_node("PlayerHelicopter")
    player.is_invulnerable = true
    await create_timer(0.2).timeout
    var start: Vector3 = player.position
    Input.action_press("thrust_forward")
    await create_timer(1.1).timeout
    Input.action_release("thrust_forward")
    check(player.position.distance_to(start) > 25.0, "Live forward flight covers the battlefield")
    await create_timer(0.8).timeout
    var weapons = player.get_node("Weapons")
    var ammo_before: int = weapons.weapon_states[0].ammo
    Input.action_press("fire_primary")
    await create_timer(0.6).timeout
    Input.action_release("fire_primary")
    check(weapons.weapon_states[0].ammo < ammo_before, "Live firing consumes machine gun ammunition")
    check(game.get_node("EnemySpawner")._get_active_enemy_count() >= 3, "Procedural opening cohort enters during gameplay")
    var camera = player.get_node("PlayerCamera")
    var point: Vector2 = camera.unproject_position(player.global_position)
    check(root.get_visible_rect().has_point(point), "Aircraft remains framed after flight and combat")
    if DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://artifacts/strike_meadow_live.png")
    print("LIVE STRIKE CHECKS: ", "FAILED" if failed else "4/4")
    quit(1 if failed else 0)
