extends SceneTree
## Regular-wave policy covers both directors, public spawning, and carrier scope.
const Data = preload("res://src/enemies/enemy_data.gd")
const Spawner = preload("res://src/enemies/enemy_spawner.gd")
const Catalog = preload("res://src/enemies/encounter/spawn_card_catalog.gd")
const EXCLUDED := ["hunter_drone", "scout_drone", "kamikaze_drone", "shield_drone", "repair_drone"]
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",description)
func clear_enemies() -> void:
	for actor in get_nodes_in_group("enemies"): actor.free()
func freeze_enemies() -> void:
	for actor in get_nodes_in_group("enemies"):
		actor.set_process(false)
		actor.set_physics_process(false)
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 2
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1500,1,1500)
	col.shape = box
	floor_body.position.y = -.5
	floor_body.add_child(col)
	stage.add_child(floor_body)
	var player := Node3D.new()
	player.position = Vector3(0,28,0)
	stage.add_child(player)
	player.add_to_group("player")
	var spawner := Spawner.new()
	stage.add_child(spawner)
	spawner.set_process(false)
	var director := root.get_node("CombatDirector")
	director.set_process(false)
	var gm := root.get_node("GameManager")
	gm.current_state = gm.RunState.ACTIVE
	gm.selected_biome = "town"
	director.current_wave = 20
	director.is_wave_active = true
	director.target_population = 30
	var catalog := Catalog.new()
	await physics_frame
	await physics_frame
	for role in EXCLUDED:
		check(Data.is_variant_enabled(role) and not Data.is_regular_wave_variant(role), role + " source preserved but excluded from regular waves")
		check(not director.can_spawn_variant(role), role + " director rejects normal admission")
		check(spawner.spawn_enemy_type(role,Vector3(80,28,80)) == null, role + " normal public spawn rejected")
		var actor = spawner.spawn_enemy_type(role,Vector3(80,28,80),true)
		check(actor != null, role + " explicit fixture remains available")
		if actor: actor.free()
	var active_air := 0
	var active_ground := 0
	for role in Data.VARIANTS:
		if not Data.is_regular_wave_variant(role): continue
		if Data.VARIANTS[role].family == "ground": active_ground += 1
		else: active_air += 1
	check(active_ground == 7 and active_air == 9, "regular roster retains seven ground vehicles and nine modeled aircraft roles")
	var clean_catalog := true
	var clean_compositions := true
	var clean_legacy := true
	for wave in range(1,26):
		director.current_wave = wave
		director._refresh_composition_pool()
		for role in director.composition_pool:
			if role in EXCLUDED: clean_compositions = false
		for theme in ["Normal","Swarm Tide","Armored Column","Night Surge","Storm Surge","Endless Overdrive"]:
			for stream in ["fast","slow"]:
				for card in catalog.get_affordable_eligible_cards(wave,theme,stream,1000,{},0,40,40):
					if card.variant_id in EXCLUDED: clean_catalog = false
			for draw in 20:
				var selected: String = spawner._choose_wave_variant(wave,theme)
				if selected.is_empty() or selected in EXCLUDED or int(Data.VARIANTS[selected].gate_wave) > wave: clean_legacy = false
	check(clean_catalog,"both credit streams exclude placeholders across waves 1–25 and all themes")
	check(clean_compositions,"composition pools never contain excluded drone roles")
	check(clean_legacy,"legacy wave sampler excludes placeholders and preserves unlock gates")
	director.current_wave = 20
	director.fast_wallet = 60
	director.slow_wallet = 120
	for card in director.catalog.get_all_cards():
		if card.variant_id not in EXCLUDED: continue
		var before: float = director.fast_wallet if "fast" in card.allowed_streams else director.slow_wallet
		var stream: String = "fast" if "fast" in card.allowed_streams else "slow"
		var units: Array = spawner.spawn_director_card(card,stream)
		var after: float = director.fast_wallet if stream == "fast" else director.slow_wallet
		check(units.is_empty() and before == after and director.reserved_population == 0,"manual ordinary purchase rejects " + card.card_id + " without spending credits")
	director.start_wave_director()
	director.fast_wallet = 60
	for evaluation in 10:
		director._evaluate_stream("fast")
		freeze_enemies()
	var opening := get_nodes_in_group("enemies")
	var only_buggies := opening.size() == 5
	for actor in opening:
		if actor.variant_id != "scout_buggy": only_buggies = false
	check(only_buggies,"wave 1 fills its five-unit target entirely with modeled Scout Buggies")
	check(director.reserved_population == 0 and director.spawn_transactions.is_empty(),"opening purchases settle every reservation")
	if not opening.is_empty(): opening[0].free()
	director.fast_wallet = 12
	director._evaluate_stream("fast")
	freeze_enemies()
	check(get_nodes_in_group("enemies").size() == 5,"ordinary replenishment replaces a missing opening vehicle")
	clear_enemies()
	director.difficulty_pop_factor = 1.5
	director._setup_wave(1)
	check(director.base_target_population == 5 and director.target_population == 5,"hard opening respects available roster capacity and the existing per-type cap")
	director.difficulty_pop_factor = 1
	director._setup_wave(2)
	var wing_eligible := false
	for card in catalog.get_affordable_eligible_cards(2,"Normal","fast",60,{},0,7,40):
		if card.variant_id == "attack_wing": wing_eligible = true
	check(wing_eligible and Data.has_regular_wave_air(2),"modeled Skyrunner still unlocks at wave 2")
	# Preserve the explicit Titan launch path; this is not regular replenishment.
	gm.selected_biome = "harbor"
	director.current_wave = 10
	director.wave_boss_spawned = false
	director.target_population = 30
	director.fast_wallet = 60
	director.slow_wallet = 120
	director._check_wave_10_boss()
	var bosses := get_nodes_in_group("bosses")
	check(bosses.size() == 1,"actual harbor boss route still creates a Titan")
	if not bosses.is_empty():
		var titan = bosses[0]
		titan.set_process(false)
		titan._summon_escort()
		var escorts: Array = []
		for actor in get_nodes_in_group("enemies"):
			if actor != titan: escorts.append(actor)
		check(escorts.size() == 1 and escorts[0].variant_id == "kamikaze_drone","Titan launch bay retains its explicit drone escort")
		for actor in escorts: actor.free()
		titan._summon_escort()
		escorts.clear()
		for actor in get_nodes_in_group("enemies"):
			if actor != titan: escorts.append(actor)
		check(escorts.size() == 1 and escorts[0].variant_id == "interceptor","Titan retains alternating interceptor launch")
		check(director.reserved_population == 0 and director.spawn_transactions.is_empty(),"carrier purchases still settle normally")
	clear_enemies()
	gm.current_state = gm.RunState.MENU
	print("REGULAR_WAVE_ROSTER: ",checks-failures,"/",checks," passed")
	quit(1 if failures else 0)
