extends SceneTree
const ROLES := ["attack_gunship","rocket_gunship","interceptor","escort_fighter","attack_wing","heavy_bomber","torpedo_vtol","stealth_vtol","minelayer"]
var checks := 0
var failures := 0
var stage: Node3D
var player: CharacterBody3D
var spawner: Node
var director: Node
var fired: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",label)
func tick(count: int) -> void:
	for i in count:
		await physics_frame
func record(node: Node) -> void:
	if node is Projectile: shot_ready.call_deferred(node)
func shot_ready(shot: Node) -> void:
	if not is_instance_valid(shot) or not shot.damage_data: return
	var source = shot.damage_data.attacker
	if is_instance_valid(source): fired[source.get_instance_id()] = true
func spawn(id: String, position: Vector3) -> BaseEnemy:
	var unit = spawner.spawn_enemy_type(id,position,true)
	unit.modifier = 0
	return unit
func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	Engine.time_scale = 8
	Engine.physics_ticks_per_second = 480
	Engine.max_fps = 0
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	player = CharacterBody3D.new()
	player.add_to_group("player")
	player.position = Vector3(0,30,0)
	stage.add_child(player)
	spawner = preload("res://src/enemies/enemy_spawner.gd").new()
	stage.add_child(spawner)
	spawner.set_process(false)
	director = root.get_node("CombatDirector")
	director.set_process(false)
	director.current_wave = 20
	director.is_wave_active = true
	director.max_air_slots = 4
	director.max_heavy_slots = 3
	var gm := root.get_node("GameManager")
	gm.current_state = gm.RunState.ACTIVE
	node_added.connect(record)
	for role in ROLES:
		var unit := spawn(role,Vector3(0,30,35))
		unit.set_physics_process(false)
		unit.rotation = Vector3(0,PI,0)
		unit.velocity = Vector3.ZERO
		for i in 60: unit.steer_air_unit(Vector3.ZERO,18,52,1.0/60.0,player.position)
		var to_player: Vector3 = (player.position-unit.position).normalized()
		check((-unit.global_basis.z).dot(to_player)>.95,role+" tracks the player while hovering from an opposite heading")
		if role in ["attack_gunship","interceptor"]:
			unit.rotation = Vector3(0,PI,0)
			unit.set_behavior_state(BaseEnemy.BehaviorState.FIRE)
			if role == "attack_gunship":
				unit.attack_fire_timer = 0
				unit.attack_shots_fired = 0
			else:
				unit.strafe_state = 1
				unit.strafe_vector = Vector3.FORWARD
				unit.burst_shots_remaining = 6
				unit.gun_timer = 0
				unit.cached_aim_point = player.position
			unit._custom_process(1.0/60.0)
			var remaining_ok: bool = unit.attack_shots_fired==0 if role=="attack_gunship" else unit.burst_shots_remaining==6
			check(remaining_ok and unit.get_node("Visuals").outlet_index==0,role+" rejected sideways shots do not consume the burst")
		elif role in ["attack_wing","escort_fighter","stealth_vtol"]:
			unit.rotation = Vector3(0,PI,0)
			check(not unit._fire_single_shot(player.position) and unit.get_node("Visuals").outlet_index==0,role+" cannot fire fixed guns backwards")
		unit.queue_free()
		await tick(2)
	for role in ROLES:
		player.position = Vector3(0,30,0)
		var unit := spawn(role,Vector3(110,36,80))
		var initial := unit.position.distance_to(player.position)
		await tick(90)
		check(unit.position.distance_to(player.position)<initial-12,role+" closes distance during live entry pursuit")
		check((-unit.global_basis.z).dot((player.position-unit.position).normalized())>.55,role+" faces the player during pursuit")
		# Moving the target across the aircraft must restart useful pursuit.
		player.position = Vector3(-45,30,-45)
		var moved_distance := unit.position.distance_to(player.position)
		await tick(150)
		check(unit.position.distance_to(player.position)<moved_distance-12,role+" reacquires a moving player's new location")
		var closest := INF
		for i in 480:
			await physics_frame
			var offset: Vector3 = unit.position-player.position
			closest = minf(closest,Vector2(offset.x,offset.z).length())
		if role in ["heavy_bomber","minelayer"]:
			check(closest<18,role+" crosses the player's combat corridor rather than orbiting far away")
		var rig := unit.get_node("Visuals")
		var attacked: bool = int(rig.outlet_index)>0
		print("AIR_TRACE ",role," distance=",unit.position.distance_to(player.position)," state=",unit.behavior_state," reason=",unit.not_firing_reason," outlets=",rig.outlet_index)
		check(attacked,role+" completes a real attack after pursuit and warning")
		unit._release_all_slots()
		unit.queue_free()
		for shot in get_nodes_in_group("combat_projectiles"): shot.queue_free()
		await tick(2)
	gm.current_state = gm.RunState.MENU
	print("AIR_PURSUIT_AND_FACING ",checks-failures,"/",checks)
	quit(1 if failures else 0)
