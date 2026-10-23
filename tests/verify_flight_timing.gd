extends SceneTree
var failures: Array[String] = []
var checks := 0
const HUD = preload("res://src/ui/survival_hud.gd")
var player: CharacterBody3D
func advance_simulated(seconds: float) -> void:
    var manager = root.get_node("GameManager")
    var director = root.get_node("CombatDirector")
    var remaining := seconds
    while remaining > 0.000001:
        var step := minf(remaining, 0.05)
        manager._process(step)
        director._process(step)
        remaining -= step
func _init() -> void:
    call_deferred("run")
func check(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        failures.append(description)
        push_error(description)
func neutral() -> void:
    for action in ["thrust_forward", "thrust_backward", "strafe_left", "strafe_right", "yaw_left", "yaw_right"]:
        Input.action_release(action)
func reset_flight() -> void:
    neutral()
    player.position = Vector3(0, 40, 0)
    player.rotation = Vector3.ZERO
    player.velocity = Vector3.ZERO
    player.angular_velocity = 0.0
    player.reset_physics_interpolation()
func ticks(count: int) -> void:
    for i in count:
        await physics_frame
func run() -> void:
    var game = load("res://scenes/main_game.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    while not game.session_started:
        await process_frame
    var manager = root.get_node("GameManager")
    var director = root.get_node("CombatDirector")
    var flow = root.get_node("UIFlow")
    flow.busy = false
    flow.input_armed = true
    manager.change_state(manager.RunState.ACTIVE)
    manager.set_process(false)
    director.set_process(false)
    director.stop_wave_director()
    player = game.get_node("PlayerHelicopter")
    player.is_invulnerable = true
    reset_flight()
    Input.action_press("thrust_forward")
    await ticks(12)
    var initial_speed := Vector2(player.velocity.x, player.velocity.z).length()
    check(initial_speed > 10 and initial_speed < 30, "Acceleration builds over several frames instead of snapping to cruise")
    await ticks(48)
    var straight_speed := Vector2(player.velocity.x, player.velocity.z).length()
    check(straight_speed > 34 and straight_speed <= 36.1, "Forward flight settles at controlled cruise speed")
    await ticks(60)
    straight_speed = Vector2(player.velocity.x, player.velocity.z).length()
    Input.action_press("strafe_right")
    await ticks(60)
    check(Vector2(player.velocity.x, player.velocity.z).length() <= straight_speed + 0.5, "Diagonal flight cannot exceed straight-line cruise")
    check(player.velocity.x > 15 and player.velocity.z < -20, "Diagonal controls still combine forward and lateral movement")
    neutral()
    await ticks(36)
    check(Vector2(player.velocity.x, player.velocity.z).length() < 2, "Releasing movement returns smoothly to hover")
    reset_flight()
    player.velocity = Vector3(0, 0, -36)
    Input.action_press("thrust_backward")
    await ticks(36)
    check(player.velocity.z > 15, "Reverse input crosses through braking into backward flight")
    reset_flight()
    Input.action_press("strafe_left")
    await ticks(45)
    check(player.position.x < -12 and absf(player.rotation.y) < 0.01, "Strafing moves sideways without changing heading")
    reset_flight()
    Input.action_press("yaw_left")
    await ticks(45)
    check(player.rotation.y > 0.8 and Vector2(player.position.x, player.position.z).length() < 0.1, "Yaw turns in place without unwanted translation")
    neutral()
    await ticks(30)
    var camera = player.get_node("PlayerCamera")
    camera.init_camera(player)
    camera.update_camera(0.016)
    var direction: Vector3 = camera.current_look_target - camera.global_position
    var angle := rad_to_deg(atan2(-direction.y, Vector2(direction.x, direction.z).length()))
    check(angle > 32 and angle < 48, "Camera looks diagonally across the battlefield rather than straight down")
    check(camera.global_position.distance_to(player.global_position) < 52, "Follow camera stays close to the aircraft")
    director.start_wave_director()
    manager.run_time = 0
    advance_simulated(1.25)
    check(is_equal_approx(manager.run_time, 1.25) and is_equal_approx(director.wave_timer, 43.75), "Run and wave clocks use the same elapsed time")
    manager.change_state(manager.RunState.PAUSED)
    manager._process(2)
    director._process(2)
    check(is_equal_approx(manager.run_time, 1.25) and is_equal_approx(director.wave_timer, 43.75), "Pause freezes elapsed and remaining time")
    manager.change_state(manager.RunState.ACTIVE)
    director.wave_timer = 0.1
    director._process(0.1)
    check(not director.is_wave_active and director.transition_timer == 3, "Wave completion starts a visible three-second intermission")
    manager.change_state(manager.RunState.UPGRADE_CHOICE)
    director._process(4)
    check(director.current_wave == 1 and director.transition_timer == 3, "Upgrade pause freezes the next-wave transition")
    manager.change_state(manager.RunState.ACTIVE)
    advance_simulated(1)
    check(is_equal_approx(director.transition_timer, 2), "Intermission resumes with its remaining time")
    advance_simulated(2.001)
    check(director.current_wave == 2 and director.is_wave_active, "Intermission advances exactly one wave")
    director.wave_timer = 0.1
    director._process(0.1)
    manager.change_state(manager.RunState.MENU)
    director._process(10)
    check(not director.is_wave_active and director.transition_timer == 0 and director.current_wave == 2, "Returning to menu cancels pending wave progression")
    check(HUD.clock_text(44.99, true) == "0:45" and HUD.clock_text(0.01, true) == "0:01", "Countdown rounds up until each second expires")
    check(HUD.clock_text(59.99) == "0:59" and HUD.clock_text(60.01) == "1:00", "Elapsed timer changes minutes without skipped seconds")
    paused = false
    print("FLIGHT AND TIMING CHECKS: ", checks - failures.size(), "/", checks)
    await load("res://tests/runtime_cleanup.gd").finish(self, 0 if failures.is_empty() else 1)
