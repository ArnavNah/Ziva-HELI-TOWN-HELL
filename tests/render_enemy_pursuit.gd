extends SceneTree

var game: Node3D
var player: Node3D
var sources: Dictionary = {}
var encounter: Array[BaseEnemy] = []
var failed := false
var air_fired := false
var ground_fired := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	seed(7119)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_move_to_foreground()
	else:
		Engine.time_scale = 4.0
		Engine.physics_ticks_per_second = 240
	game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	if not game.is_prepared:
		await game.scene_prepared
	game.activate_session()
	player = game.get_node("PlayerHelicopter")
	player.is_invulnerable = true
	player.position = Vector3(0, 14, 0)
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.get_node("PlayerCamera").init_camera(player)
	var director := root.get_node("CombatDirector")
	director._setup_wave(6)
	director.wave_timer = 40
	var spawner := game.get_node("EnemySpawner")
	spawner.set_process(false)
	for unit in get_nodes_in_group("enemies"):
		unit.queue_free()
	await physics_frame
	var formation := {
		"technical_truck": Vector3(0, 1, -85),
		"rocket_buggy": Vector3(1.8, 1, -105),
		"attack_gunship": Vector3(-14, 24, -90),
		"hunter_drone": Vector3(16, 24, -80)
	}
	for key in formation:
		var unit: BaseEnemy = spawner.spawn_enemy_type(key, formation[key])
		if not unit:
			failed = true
			continue
		encounter.append(unit)
	node_added.connect(_track_projectile)
	await create_timer(3.0).timeout
	await _capture("enemy_pursuit_approach")
	await create_timer(4.0).timeout
	await _capture("enemy_pursuit_combat")
	await create_timer(3.0).timeout
	for unit in encounter:
		if not is_instance_valid(unit):
			continue
		var fired := sources.has(unit.get_instance_id())
		print("LIVE UNIT: ", unit.variant_id, " pos=", unit.position, " state=", unit.behavior_state, " reason=", unit.not_firing_reason, " fired=", fired)
	failed = failed or not air_fired or not ground_fired
	print("LIVE PURSUIT: ground and air approached and fired: ", ground_fired and air_fired)
	quit(1 if failed else 0)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + label + ".png")

func _track_projectile(node: Node) -> void:
	if node is Projectile:
		_record_shot.call_deferred(node)

func _record_shot(projectile: Projectile) -> void:
	if not is_instance_valid(projectile) or not projectile.damage_data:
		return
	var source = projectile.damage_data.attacker
	if is_instance_valid(source) and source is BaseEnemy:
		if not sources.has(source.get_instance_id()):
			print("LIVE FIRST SHOT: ", source.variant_id, " distance=", source.position.distance_to(player.position), " grace=", source.entry_grace_timer)
			sources[source.get_instance_id()] = true
			air_fired = air_fired or source.is_air_unit
			ground_fired = ground_fired or not source.is_air_unit
