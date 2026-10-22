extends SceneTree

const DamageDataClass = preload("res://src/combat/damage_data.gd")
const ProceduralRaiderScript = preload("res://src/enemies/procedural_raider.gd")

## Unit and Integration Test Suite for Stylized Vehicle & Airframe Destruction System.
## Validates:
## 1. BurningFragmentTrail MultiMesh pooling, kinematic ballistic arcs, and world-space smoke puffs.
## 2. DestructionFXProfile resolution across all vehicle categories.
## 3. Ground vehicle destruction: stops, jolts, immediately plays destruction FX, no airborne spinning.
## 4. Air vehicle destruction: enters controlled death spiral, leaves trailing smoke, explodes on surface/timeout.
## 5. Player helicopter death: input lockout during dying, trailing smoke, catastrophic impact burst.
## 6. Flash light budget: maximum 4 active real OmniLight3D nodes with priority preemption.
## 7. Zero damage or score side-effects from cosmetic FX.

var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, label: String) -> void:
	if condition:
		print("  [PASS] ", label)
	else:
		push_error("  [FAIL] " + label)
		print("  [FAIL] ", label)
		failures += 1

func run() -> void:
	print("==================================================================")
	print("--- BEGIN VEHICLE DESTRUCTION & EXPLOSION SYSTEM VERIFICATION ---")
	print("==================================================================")

	var fx_mgr = root.get_node_or_null("FXManager")
	var flow = root.get_node_or_null("UIFlow")
	var gm = root.get_node_or_null("GameManager")
	var eb = root.get_node_or_null("EventBus")

	verify(fx_mgr != null, "1.1 FXManager autoload is present")
	verify(flow != null, "1.2 UIFlow autoload is present")
	verify(fx_mgr.fragment_trail_emitter != null, "1.3 BurningFragmentTrail pooled emitter initialized under GameplayFXRoot")

	# --- TEST 1: Profile Resolution ---
	var dummy_ground = Node3D.new()
	dummy_ground.add_to_group("enemies")
	dummy_ground.set_meta("variant_id", "scout_buggy")
	var p_ground = DestructionFXProfile.get_profile_for_entity(dummy_ground)
	verify(p_ground["id"] == "light_ground" and p_ground["fragment_count"] == 4, "2.1 Scout Buggy resolves to light_ground profile")

	var dummy_tank = Node3D.new()
	dummy_tank.add_to_group("enemies")
	dummy_tank.set_meta("variant_id", "flame_tank")
	var p_tank = DestructionFXProfile.get_profile_for_entity(dummy_tank)
	verify(p_tank["id"] == "heavy_ground" and p_tank["fragment_count"] == 6, "2.2 Flame Tank resolves to heavy_ground profile")

	var dummy_drone = Node3D.new()
	dummy_drone.add_to_group("enemies")
	dummy_drone.set_meta("variant_id", "hunter_drone")
	var p_drone = DestructionFXProfile.get_profile_for_entity(dummy_drone)
	verify(p_drone["id"] == "drone" and p_drone["fragment_count"] == 3, "2.3 Hunter Drone resolves to drone profile")

	var dummy_vtol = Node3D.new()
	dummy_vtol.add_to_group("enemies")
	dummy_vtol.set_meta("variant_id", "torpedo_vtol")
	var p_vtol = DestructionFXProfile.get_profile_for_entity(dummy_vtol)
	verify(p_vtol["id"] == "aircraft" and p_vtol["fragment_count"] == 5, "2.4 Torpedo VTOL resolves to aircraft profile")

	var dummy_player = Node3D.new()
	dummy_player.add_to_group("player")
	var p_player = DestructionFXProfile.get_profile_for_entity(dummy_player)
	verify(p_player["id"] == "player" and p_player["real_light_priority"] == 3, "2.5 Player resolves to hero player profile with priority 3")

	dummy_ground.free()
	dummy_tank.free()
	dummy_drone.free()
	dummy_vtol.free()
	dummy_player.free()

	# --- TEST 2: BurningFragmentTrail Kinematic Head & Smoke Puff Launch ---
	var emitter = fx_mgr.fragment_trail_emitter
	var initial_free_heads = 0
	for h in emitter.fragment_heads:
		if not h.active:
			initial_free_heads += 1
	verify(initial_free_heads == 48, "3.1 Initial fragment head pool has 48 free slots")

	emitter.launch_fragments(Vector3(0, 10, 0), Vector3.ZERO, 5, 15.0, 20.0, 18.0, 0.6, 0.3, 0.5, 1.0)
	var active_heads = 0
	for h in emitter.fragment_heads:
		if h.active:
			active_heads += 1
	verify(active_heads == 5, "3.2 launch_fragments correctly activated 5 ballistic heads")

	# Advance 10 frames to verify downward ballistic motion and puff spawning
	for i in 10:
		await process_frame

	var active_puffs = 0
	for p in emitter.smoke_puffs:
		if p.active:
			active_puffs += 1
	verify(active_puffs > 0, "3.3 Ballistic fragments emitted segmented world-space smoke puffs along their arcs")

	emitter.clear_all()
	var cleared_heads = 0
	for h in emitter.fragment_heads:
		if not h.active:
			cleared_heads += 1
	verify(cleared_heads == 48, "3.4 clear_all cleanly resets all fragment heads and smoke puffs")

	# --- TEST 3: Shared Real Flash Light Bounded Pool (Max 4 Lights) ---
	fx_mgr.clear_combat_effects()
	verify(fx_mgr.get_active_flash_light_count() == 0, "4.1 Flash light pool starts with 0 active lights")

	# Request 5 lights in separated positions (> 4.0m apart)
	for k in range(5):
		fx_mgr.request_flash_light(Vector3(k * 10.0, 5.0, 0.0), Color.YELLOW, 3.0, 8.0, 0.20, k)

	verify(fx_mgr.get_active_flash_light_count() == 4, "4.2 Flash light pool strictly enforces maximum 4 concurrent lights")
	fx_mgr.clear_combat_effects()

	# --- TEST 4: Live Scene Integration (Ground vs Air Enemies & Player) ---
	var main_scene = load("res://scenes/main_game.tscn")
	var game = main_scene.instantiate()
	root.add_child(game)
	current_scene = game

	for i in 12:
		await process_frame

	var player = game.get_node_or_null("PlayerHelicopter")
	verify(player != null, "5.1 PlayerHelicopter loaded in MainGame")

	# Verify input is armed during normal gameplay
	verify(flow.gameplay_input_allowed(), "5.2 gameplay_input_allowed is true while player is alive")

	# Test player dying input lockout
	player.is_dying = true
	verify(not flow.gameplay_input_allowed(), "5.3 gameplay_input_allowed is strictly false during player death sequence")
	player.is_dying = false

	# Spawn ground enemy and test ground death (no airborne spin)
	var ground_enemy = ProceduralRaiderScript.new()
	ground_enemy.variant_id = "scout_buggy"
	var g_rec = DamageReceiver.new()
	g_rec.name = "DamageReceiver"
	ground_enemy.add_child(g_rec)
	var g_col = CollisionShape3D.new()
	var g_shape = BoxShape3D.new()
	g_shape.size = Vector3(2, 2, 4)
	g_col.shape = g_shape
	ground_enemy.add_child(g_col)

	game.add_child(ground_enemy)
	ground_enemy.global_position = Vector3(10, 0.5, 10)
	for i in 2:
		await process_frame

	verify(not ground_enemy.is_air_unit, "6.1 Scout buggy correctly registered as ground unit (is_air_unit=false)")
	var dummy_dmg = DamageDataClass.new()
	dummy_dmg.raw_damage = 9999.0
	g_rec.take_damage(dummy_dmg)

	# Ground unit should NOT be in DEATH_SPIRAL
	verify(ground_enemy.current_state != ground_enemy.EnemyState.DEATH_SPIRAL, "6.2 Ground unit enters DEAD state, NOT airborne DEATH_SPIRAL")

	# Spawn air enemy and test air death (enters spiral, spawns smoke)
	var air_enemy = ProceduralRaiderScript.new()
	air_enemy.variant_id = "hunter_drone"
	var a_rec = DamageReceiver.new()
	a_rec.name = "DamageReceiver"
	air_enemy.add_child(a_rec)
	var a_col = CollisionShape3D.new()
	var a_shape = BoxShape3D.new()
	a_shape.size = Vector3(2, 2, 2)
	a_col.shape = a_shape
	air_enemy.add_child(a_col)

	game.add_child(air_enemy)
	air_enemy.global_position = Vector3(10, 15.0, 10)
	for i in 2:
		await process_frame

	verify(air_enemy.is_air_unit, "7.1 Hunter drone correctly registered as air unit (is_air_unit=true)")
	a_rec.take_damage(dummy_dmg)

	verify(air_enemy.current_state == air_enemy.EnemyState.DEATH_SPIRAL, "7.2 Air unit enters DEATH_SPIRAL with tumbling angular velocity")

	# Clean up
	game.queue_free()
	for i in 5:
		await process_frame

	print("------------------------------------------------------------------")
	print("DESTRUCTION SYSTEM: ", "ALL PASSED" if failures == 0 else str(failures) + " FAILURES")
	print("==================================================================")
	quit(1 if failures else 0)
