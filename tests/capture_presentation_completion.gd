extends SceneTree
const Bounds = preload("res://src/ui/vehicle_bounds.gd")
const OUT := "res://artifacts/presentation-fixes-2026-11-04/"
const ROLES := ["scout_buggy","assault_apc","rail_crawler","siege_tank","gatling_heavy","raptor_raider","desert_barrage_rover","attack_gunship","rocket_gunship","interceptor","escort_fighter","attack_wing","heavy_bomber","torpedo_vtol","stealth_vtol","minelayer"]
var game: Node3D
var player: Node3D
var rows: Array = []
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func capture(label: String) -> void:
	await frames(3)
	RenderingServer.force_draw(false)
	var error := root.get_texture().get_image().save_png(OUT+label+".png")
	if error != OK:
		printerr("FAIL capture ",label," error=",error)
		quit(1)
func record(actor: Node3D, id: String, camera: Camera3D) -> void:
	var hull := Bounds.local_bounds(actor)
	var envelope := Bounds.screen_envelope(camera,actor,camera.unproject_position(actor.global_position))
	rows.append({"role":id,"hull_size":str(hull.size),"hull_center":str(hull.get_center()),"all_mesh_bounds":str(Bounds.local_bounds(actor,true).size),"root_scale":str(actor.scale),"screen_size":str(envelope.size)})
	print("SCALE ",rows.back())
func run() -> void:
	if DisplayServer.get_name()=="headless" or OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var gm := root.get_node("GameManager")
	gm.selected_biome = "town"
	game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 2400:
		await process_frame
		if game.is_prepared: break
	if not game.is_prepared:
		quit(1)
		return
	player = game.get_node("PlayerHelicopter")
	player.debug_invulnerable = true
	gm.score = 1234567
	gm.coins_collected = 999999
	gm.kills_count = 9999
	player.position = Vector3(0,30,0)
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	player.set_process(false)
	var camera: Camera3D = player.get_node("PlayerCamera")
	camera.init_camera(player)
	var director := root.get_node("CombatDirector")
	director.set_process(false)
	director.current_wave = 20
	var spawner := game.get_node("EnemySpawner")
	spawner.set_process(false)
	for actor in get_nodes_in_group("enemies"): actor.queue_free()
	await frames(3)
	for id in ["apache","nighthawk","warlock"]:
		player.aircraft_type = id
		player._apply_aircraft_baseline()
		player.visual_hull.transform = player._visual_rest
		record(player,id,camera)
	player.aircraft_type = "apache"
	player._apply_aircraft_baseline()
	camera.init_camera(player)
	for id in ROLES:
		var actor = spawner.spawn_enemy_type(id,Vector3(9,33,-18),true)
		if not actor:
			print("FAIL spawn ",id)
			quit(1)
			return
		actor.set_process(false)
		actor.set_physics_process(false)
		record(actor,id,camera)
		actor.queue_free()
		await frames(1)
	# Use the real director routes for all bosses, rather than ordinary admission.
	for biome in ["town","desert","harbor"]:
		gm.selected_biome = biome
		director.current_wave = 10
		director.wave_boss_spawned = false
		director._check_wave_10_boss()
		var bosses := get_nodes_in_group("bosses")
		if bosses.is_empty():
			print("FAIL boss route ",biome)
			quit(1)
			return
		var boss: Node3D = bosses[0]
		boss.set_process(false)
		boss.set_physics_process(false)
		boss.global_position = Vector3(-16,33,-18)
		record(boss,biome+"_boss",camera)
		player.mortal_alarm_timer = 10
		var boss_hud := game.get_node("UI/CombatHUD")
		boss_hud._on_border_warning_changed(true,Vector3.ZERO,20)
		await frames(12)
		boss_hud.alert_flash_timer = 0
		boss_hud._update_border_warnings()
		boss_hud.set_process(false)
		await capture("boss-"+biome)
		var panel: Control = boss_hud.get_node("BossTracker")
		if not panel.visible or panel.size.y<=0 or panel.get_global_rect().intersects(boss_hud.border_warning_banner.get_global_rect()):
			print("FAIL boss and warning overlap")
			quit(1)
			return
		boss_hud.set_process(true)
		boss.queue_free()
		await frames(3)
	gm.selected_biome = "town"
	player.mortal_alarm_timer = 0
	game.get_node("UI/CombatHUD")._on_border_warning_changed(false,Vector3.ZERO,0)
	director.current_wave = 20
	var actor = spawner.spawn_enemy_type("attack_gunship",Vector3(9,33,-18),true)
	actor.set_process(false)
	actor.set_physics_process(false)
	player.turret.current_target_node = actor
	gm.score = 1234567
	gm.coins_collected = 999999
	gm.kills_count = 9999
	var store := root.get_node("SettingsStore")
	var hud := game.get_node("UI/CombatHUD")
	for factor in [1.0,1.25]:
		store.set_value("hud_scale",factor)
		for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1024,768),Vector2i(2560,1080)]:
			root.size = dimensions
			await capture("hud-"+str(dimensions.x)+"x"+str(dimensions.y)+"-"+str(factor))
			var overlay: Control = hud.survival_overlay
			var stats: Control = overlay.elapsed_label.get_parent().get_parent()
			var overlap := stats.get_global_rect().intersects(overlay.stage_timer.get_global_rect())
			print("HUD_LAYOUT ",dimensions," scale=",factor," overlap=",overlap)
			if overlap:
				quit(1)
				return
	root.size = Vector2i(1280,720)
	store.set_value("hud_scale",1.0)
	# Actual physics/process-driven maneuver with independent pad aim and firing.
	var inputs := root.get_node("InputManager")
	inputs._set_controller_mode(true,7)
	root.get_node("UIFlow").input_armed = true
	player.set_process(true)
	player.set_physics_process(true)
	var samples: Array = []
	for i in 36:
		var angle := float(i)/36.0*TAU
		for pair in [[JOY_AXIS_LEFT_X,sin(angle)],[JOY_AXIS_LEFT_Y,-cos(angle)],[JOY_AXIS_RIGHT_X,0.45],[JOY_AXIS_RIGHT_Y,-0.7],[JOY_AXIS_TRIGGER_RIGHT,1.0]]:
			var event := InputEventJoypadMotion.new()
			event.device = 7
			event.axis = pair[0]
			event.axis_value = pair[1]
			Input.parse_input_event(event)
		await frames(5)
		var command: Dictionary = inputs.get_flight_input()
		samples.append({"angle":angle,"velocity":str(player.velocity),"command":str(command.get("move_world")),"bank":player.bank_angle,"pitch":player.pitch_angle})
		if i%3==0: await capture("flight-%02d"%[i/3])
	print("LIVE_MOTION samples=",samples.size()," distance=",player.position.distance_to(Vector3(0,30,0)))
	var output := FileAccess.open(OUT+"scale-and-motion.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"vehicles":rows,"motion":samples},"\t"))
	print("PRESENTATION_CAPTURE_COMPLETE roles=",rows.size())
	gm.current_state = gm.RunState.MENU
	quit()
