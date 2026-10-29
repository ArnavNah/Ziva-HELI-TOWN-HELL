extends SceneTree
## Real nonzero-device joypad events, flight dynamics, targeting and hit feedback.
const PAD := 7
var checks := 0
var failures := 0
var player: Node3D
var inputs: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",label)
func axis(code: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = PAD
	event.axis = code
	event.axis_value = value
	Input.parse_input_event(event)
	await process_frame
	await process_frame
func simulate(frames: int) -> void:
	for i in frames: player._process_flight_physics(1.0/60.0)
func reset_player() -> void:
	player.position = Vector3(0,30,0)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.angular_velocity = 0.0
	player.lateral_acceleration = 0.0
	player.bank_angle = 0.0
	player.bank_velocity = 0.0
func make_target(parent: Node, position: Vector3) -> Node3D:
	var enemy := StaticBody3D.new()
	enemy.position = position
	enemy.collision_layer = 4
	enemy.collision_mask = 0
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := SphereShape3D.new()
	shape.radius = 2
	col.shape = shape
	enemy.add_child(col)
	var rec := DamageReceiver.new()
	rec.name = "DamageReceiver"
	enemy.add_child(rec)
	parent.add_child(enemy)
	enemy.add_to_group("enemies")
	return enemy
func aim_at(camera: Camera3D, turret: Node, target: Node3D, error_degrees: float = 0) -> void:
	var direction := (camera.unproject_position(target.global_position)-camera.unproject_position(player.global_position)).normalized().rotated(deg_to_rad(error_degrees))
	await axis(JOY_AXIS_RIGHT_X,direction.x)
	await axis(JOY_AXIS_RIGHT_Y,direction.y)
	inputs.advance_controller_aim(.016,Vector2(1280,720),Vector2(640,200))
	for i in 8: turret.update_aim(camera, inputs.get_aim_screen_position(), player, .016)
func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	player = preload("res://scenes/player/player.tscn").instantiate()
	player.position = Vector3(0,30,0)
	world.add_child(player)
	player.debug_invulnerable = true
	player.set_physics_process(false)
	player.set_process(false)
	var camera: Camera3D = player.get_node("PlayerCamera")
	camera.set_process(false)
	camera.init_camera(player)
	var gm := root.get_node("GameManager")
	gm.current_state = gm.RunState.ACTIVE
	root.get_node("CombatDirector").set_process(false)
	inputs = root.get_node("InputManager")
	inputs.set_process(false)
	root.get_node("UIFlow").input_armed = true
	await axis(JOY_AXIS_LEFT_X,1)
	var flight: Dictionary = inputs.get_flight_input()
	print("INITIAL_FLIGHT ",flight," camera=",camera.global_basis," player=",player.rotation)
	check(flight.strafe > .95 and flight.yaw == 0, "left stick requests translation without yaw")
	simulate(21)
	var right_speed: float = player.velocity.x
	print("INITIAL_SPEED ",right_speed," cruise=",player.cruise_speed)
	check(right_speed > player.cruise_speed * .65 and absf(player.rotation.y) < .01, "right movement accelerates promptly without spinning the helicopter")
	await axis(JOY_AXIS_LEFT_X,-1)
	simulate(15)
	check(player.velocity.x < 0, "left input reverses rightward motion within 250 ms")
	reset_player()
	simulate(21)
	check(absf(-player.velocity.x-right_speed) < .1, "left and right have symmetric movement response")
	await axis(JOY_AXIS_LEFT_X,0)
	simulate(30)
	check(absf(player.velocity.x)<.5, "releasing movement arrests sideways drift")
	reset_player()
	await axis(JOY_AXIS_LEFT_X,1)
	await axis(JOY_AXIS_LEFT_Y,-1)
	simulate(60)
	check(Vector2(player.velocity.x,player.velocity.z).length() <= player.cruise_speed+.1, "diagonal movement cannot exceed cruise cap")
	await axis(JOY_AXIS_LEFT_Y,0)
	reset_player()
	player.rotation.y = PI/2
	flight = inputs.get_flight_input()
	var desired: Vector3 = -player.global_basis.z*flight.thrust+player.global_basis.x*flight.strafe
	check(desired.x>.95 and absf(desired.z)<.01, "movement stays camera-relative when hull heading changes")
	await axis(JOY_AXIS_LEFT_X,0)
	reset_player()
	camera.init_camera(player)
	var turret := player.get_node("Turret")
	var left := make_target(world,Vector3(-16,25,-32))
	var right := make_target(world,Vector3(18,25,-34))
	await physics_frame
	await physics_frame
	var muzzle_toggle: bool = turret.current_muzzle_toggle
	await aim_at(camera,turret,left,12)
	check(turret.current_target_node == left, "right stick locks a visible enemy by direction despite imprecise aim")
	check(inputs.get_aim_screen_position().distance_to(camera.unproject_position(left.global_position))<1, "reticle follows actual assisted target for gun and salvo")
	check(turret.current_muzzle_toggle == muzzle_toggle, "aim assist never advances firing barrels")
	await aim_at(camera,turret,right)
	check(turret.current_target_node == right, "sweeping right stick switches targets")
	await axis(JOY_AXIS_RIGHT_X,0)
	await axis(JOY_AXIS_RIGHT_Y,0)
	right.position.x += 2
	turret.update_aim(camera,inputs.get_aim_screen_position(),player,.1)
	check(turret.current_target_node == right and turret.target_world_pos.is_equal_approx(right.global_position), "neutral stick retains and tracks the selected moving target")
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	wall.position = (turret.get_next_muzzle_transform().origin + right.global_position)*.5
	var wall_col := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(8,10,4)
	wall_col.shape = wall_shape
	wall.add_child(wall_col)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	turret.update_aim(camera,inputs.get_aim_screen_position(),player,.1)
	check(turret.current_target_node == null, "directional assist refuses an enemy behind a building")
	wall.queue_free()
	right.get_node("DamageReceiver").is_dead = true
	await physics_frame
	turret.update_aim(camera,inputs.get_aim_screen_position(),player,.1)
	check(turret.current_target_node == null, "dead targets release immediately")
	var pulses: Array = []
	inputs.damage_rumble_requested.connect(func(device,weak,strong,duration): pulses.append([device,weak,strong,duration]))
	inputs.rumble_enabled = true
	player.debug_invulnerable = false
	player.spawn_grace_timer = 0
	player.evasion_chance = 0
	player.shield_timer = 0
	player.take_damage(5.0)
	check(pulses.size()==1 and pulses[0][0]==PAD and pulses[0][3]>.1 and pulses[0][3]<=.28, "accepted player hit requests bounded rumble on active controller")
	player.spawn_grace_timer = 1
	player.take_damage(5.0)
	check(pulses.size()==1, "protected hits do not rumble")
	player.spawn_grace_timer = 0
	player.shield_timer = 5
	player.shield_capacity = 20
	player.take_damage(5.0)
	check(pulses.size()==2, "shield absorption gives a hit pulse")
	inputs.rumble_enabled = false
	player.take_damage(5.0)
	check(pulses.size()==2, "rumble preference disables hit feedback")
	inputs.rumble_enabled = true
	paused = true
	inputs.play_damage_rumble(10)
	check(pulses.size()==2, "paused gameplay cannot start rumble")
	paused = false
	inputs.stop_damage_rumble()
	check(inputs._rumble_device == -1, "rumble stop clears active device")
	var settings := root.get_node("SettingsStore")
	settings.set_value("pad_rumble",false)
	settings.flush()
	settings.load_settings()
	check(not settings.values.pad_rumble and not inputs.rumble_enabled, "rumble preference saves and applies")
	settings.set_value("pad_rumble",true)
	gm.current_state = gm.RunState.MENU
	print("CONTROLLER_HANDLING: ",checks-failures,"/",checks," passed")
	quit(1 if failures else 0)
