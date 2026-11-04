extends SceneTree
const Bounds = preload("res://src/ui/vehicle_bounds.gd")
var checks := 0
var failures := 0
var inputs: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func axis(x: float, y: float, device: int = 7, right: bool = false) -> void:
	for pair in [[JOY_AXIS_RIGHT_X if right else JOY_AXIS_LEFT_X,x],[JOY_AXIS_RIGHT_Y if right else JOY_AXIS_LEFT_Y,y]]:
		var event := InputEventJoypadMotion.new()
		event.device = device
		event.axis = pair[0]
		event.axis_value = pair[1]
		Input.parse_input_event(event)
	await process_frame
	await process_frame
func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var p = load("res://scenes/player/player.tscn").instantiate()
	world.add_child(p)
	p.position = Vector3(0,40,0)
	p.debug_invulnerable = true
	p.set_process(false)
	p.set_physics_process(false)
	var cam: Camera3D = p.get_node("PlayerCamera")
	cam.set_process(false)
	cam.init_camera(p)
	inputs = root.get_node("InputManager")
	inputs.set_process(false)
	inputs._set_controller_mode(true,7)
	var gm := root.get_node("GameManager")
	gm.current_state = gm.RunState.ACTIVE
	root.get_node("CombatDirector").set_process(false)
	root.get_node("UIFlow").input_armed = true
	for noise in [Vector2(0.1,0),Vector2(0.1,-0.1),Vector2(0.17,0)]:
		await axis(noise.x,noise.y)
		check(inputs.get_flight_input().move_world.is_zero_approx(),"final flight command rejects radial noise " + str(noise))
		for i in 60: p._process_flight_physics(1.0/60.0)
		check(p.velocity.length()<0.01,"noise cannot accelerate helicopter")
	await axis(0,0)
	await axis(0.1,0,1)
	check(inputs.active_joypad==7 and inputs.get_flight_input().move_world.is_zero_approx(),"inactive pad cannot leak into keyboard fallback")
	await axis(0,0,1)
	await axis(0.8,0)
	await axis(0.5,0,7,true)
	await axis(0,0,7,true)
	var jitter := InputEventMouseMotion.new()
	jitter.relative = Vector2(3,0)
	Input.parse_input_event(jitter)
	await process_frame
	check(inputs.uses_controller_aim(),"small mouse jitter preserves controller aim")
	var deliberate := InputEventMouseMotion.new()
	deliberate.relative = Vector2(40,20)
	Input.parse_input_event(deliberate)
	await process_frame
	check(not inputs.uses_controller_aim() and inputs.get_flight_input().direct_move,"mouse aim and pad movement have independent ownership")
	check(inputs.get_flight_input().move_world.x>0.7,"mouse aim preserves pad movement magnitude")
	await axis(0,0,7,true)
	check(not inputs.uses_controller_aim(),"neutral right-stick packets do not steal deliberate mouse aim")
	await axis(0.6,-0.1,7,true)
	check(inputs.uses_controller_aim(),"right-stick intent restores directional auto aim")
	await axis(0,0,7,true)
	await axis(0,0)
	# The original bypass reproduction also runs through normal physics frames.
	await axis(0.1,0)
	var start: Vector3 = p.position
	p.set_physics_process(true)
	p.set_process(true)
	inputs.set_process(true)
	for i in 60: await physics_frame
	check(p.position.distance_to(start)<0.01 and p.velocity.length()<0.01,"normal scene-tree processing remains stationary inside deadzone")
	p.set_physics_process(false)
	p.set_process(false)
	inputs.set_process(false)
	await axis(0,0)
	# Offset, rotated, scaled and compound collider coordinates.
	var target := Node3D.new()
	target.position = Vector3(0,40,-20)
	world.add_child(target)
	for offset in [Vector3(8,1,0),Vector3(-2,0,0)]:
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D" if offset.x>0 else "WingCollider"
		col.shape = BoxShape3D.new()
		col.shape.size = Vector3(4,2,6)
		col.position = offset
		target.add_child(col)
	var box := Bounds.local_bounds(target)
	check(box.has_point(Vector3(10,1,0)) and box.has_point(Vector3(-4,0,0)),"envelope includes offset hull and additional compound collider")
	target.get_node("WingCollider").position.x = -7
	check(Bounds.local_bounds(target).position.x < -8.9,"bounds follow changed transforms without a stale AABB cache")
	var col: CollisionShape3D = target.get_node("CollisionShape3D")
	col.rotation.y = PI/2
	col.scale = Vector3.ONE*1.2
	check(Bounds.local_bounds(target).end.x > 11.5,"bounds respect collider rotation and scale")
	target.global_position = cam.global_position
	var envelope := Bounds.screen_envelope(cam,target,Vector2(640,360))
	check(envelope.position.is_finite() and envelope.size.is_finite() and envelope.size.x<=1280,"near-plane clipping produces bounded finite UI")
	# Cached impact and actual firing direction agree after the presentation pose.
	p.pitch_angle = deg_to_rad(-18)
	p.bank_angle = deg_to_rad(15)
	p._process(1.0/60.0)
	check(p.turret.actual_aim_direction.angle_to(p.turret.get_aim_direction())<0.0001,"aim cache uses the current animated muzzle pose")
	var toggle: bool = p.turret.current_muzzle_toggle
	Bounds.local_bounds(p)
	check(toggle==p.turret.current_muzzle_toggle,"presentation queries never advance weapon outlets")
	p.pitch_angle = 0
	p.bank_angle = 0
	p.is_landed = true
	for i in 120:
		p.flight_time += 1.0/60.0
		p._update_helicopter_visuals(0,0,1.0/60.0)
	check(p.visual_hull.position.length()<0.001,"landed aircraft settles without hover bob")
	p.is_landed = false
	var peak := 0.0
	for i in 600:
		p.flight_time += 1.0/60.0
		p._update_helicopter_visuals(0,0,1.0/60.0)
		peak = maxf(peak,p.visual_hull.position.length())
	check(peak<0.15,"idle visual motion stays within fifteen centimeters")
	var phases: Array[float] = []
	for hz in [30,60,120]:
		p._rotor_phase = 0
		p._tail_phase = 0
		p.rotor_rpm_ratio = 0
		p.velocity = Vector3.ZERO
		p.last_thrust_input = 0
		var shaft: Vector3 = p.main_rotor.global_position
		for i in hz: p._animate_rotors(1.0/float(hz))
		phases.append(p._rotor_phase)
		check(p.main_rotor.global_position.distance_to(shaft)<0.0001,"rotor shaft stays fixed at "+str(hz)+" FPS")
	check(phases.max()-phases.min()<0.0001,"rotor spool phase agrees at 30/60/120 FPS")
	for id in ["apache","nighthawk","warlock"]:
		p.aircraft_type = id
		p._apply_aircraft_baseline()
		var specs: Dictionary = AircraftSpecs.get_specs(id)
		check(p.get_node("CollisionShape3D").shape.size.is_equal_approx(Vector3(3.6,2.5,11.5)*float(specs.scale_mult)),id+" hull collider follows configured scale exactly once")
		p._apply_aircraft_baseline()
		check(p.get_node("CollisionShape3D").shape.size.is_equal_approx(Vector3(3.6,2.5,11.5)*float(specs.scale_mult)),id+" repeated configuration never compounds scale")
		cam.init_camera(p)
		check(cam.base_distance>37 and cam.base_distance<43,id+" camera has calibrated combat framing")
	var store := root.get_node("SettingsStore")
	store.set_value("hud_scale",1.25)
	store.flush()
	store.load_settings()
	check(is_equal_approx(float(store.values.hud_scale),1.25),"HUD readability preference persists")
	store.set_value("hud_scale",1.0)
	await axis(0.8,0)
	inputs._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	root.get_node("UIFlow").input_armed = true
	check(inputs.get_flight_input().move_world.is_zero_approx(),"focus loss clears cached movement safely")
	gm.current_state = gm.RunState.MENU
	print("PRESENTATION_COMPLETION ",checks-failures,"/",checks)
	quit(1 if failures else 0)
