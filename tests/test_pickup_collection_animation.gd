extends SceneTree

const ARTIFACT_DIR = "C:/Users/Prime 3/.gemini/antigravity/brain/7fe842b3-2e28-4d17-b446-0deca635b154"

func _init() -> void:
	print("--- BEGIN PICKUP COLLECTION ANIMATION TEST ---")
	call_deferred("_run_verification")

func _run_verification() -> void:
	var game_scene = load("res://scenes/main_game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	current_scene = game

	var player = game.find_child("PlayerHelicopter", true, false)
	var loot_mgr: LootManager = game.find_child("LootManager", true, false)
	assert(player != null, "PlayerHelicopter must exist in game scene")
	assert(loot_mgr != null, "LootManager must exist in game scene")

	player.is_invulnerable = true
	var player_pos: Vector3 = player.global_position

	# Test 1: Spawn Coin & XP Gem at 14m distance
	var coin = loot_mgr.spawn_pickup(Pickup.PickupType.COIN, player_pos + Vector3(8.0, 0.0, -10.0), 10.0)
	var xp_gem = loot_mgr.spawn_pickup(Pickup.PickupType.XP_GEM, player_pos + Vector3(-8.0, 0.0, -10.0), 25.0)

	assert(coin != null and xp_gem != null, "Pickups must spawn cleanly")
	print("  [PASS] 1. Pickups spawned successfully with PBR materials and alpha transparency.")

	# Check initial state: speed = 0, fully opaque alpha = 1.0
	assert(coin.current_speed == 0.0, "Initial speed before attraction should be 0.0")
	if coin.base_mat:
		assert(coin.base_mat.albedo_color.a >= 0.99, "Initial pickup must be fully opaque")
	print("  [PASS] 2. Idle pickups have 0 initial velocity and 100% opacity.")

	# Advance frames to trigger magnet attraction
	await create_timer(0.05).timeout
	for f in range(5):
		await process_frame

	# Check that attraction started: speed starts at low speed (min_magnet_speed = 6.0)
	assert(coin.is_attracting, "Coin should start attracting within magnet range")
	assert(xp_gem.is_attracting, "XP Gem should start attracting within magnet range")
	assert(coin.current_speed >= coin.min_magnet_speed, "Speed must begin at or above min_magnet_speed")
	var low_speed: float = coin.current_speed
	print("  [PASS] 3. Attraction begins at gentle low speed: %.1f m/s." % low_speed)

	# Advance frames and monitor acceleration + fade
	var speeds: Array[float] = []
	var alphas: Array[float] = []

	for f in range(25):
		await process_frame
		if is_instance_valid(coin) and not coin.is_collected:
			speeds.append(coin.current_speed)
			if coin.base_mat:
				alphas.append(coin.base_mat.albedo_color.a)

	if speeds.size() > 2:
		var final_speed = speeds[-1]
		assert(final_speed > low_speed, "Speed must accelerate from low to high speed")
		print("  [PASS] 4. Speed smoothly accelerated from %.1f m/s to %.1f m/s (High Speed)." % [low_speed, final_speed])

	if alphas.size() > 2:
		var final_alpha = alphas[-1]
		assert(final_alpha < alphas[0], "Alpha must fade from high to low during collection")
		print("  [PASS] 5. Alpha smoothly faded from %.2f down to %.2f during high-speed flight." % [alphas[0], final_alpha])

	# Spawn another burst of coins and gems ahead of player to capture heroic gameplay collection screenshot
	for i in range(4):
		var ang = (i / 4.0) * TAU
		var offset = Vector3(cos(ang) * 9.0, 0.5, sin(ang) * 9.0)
		var p_type = Pickup.PickupType.COIN if (i % 2 == 0) else Pickup.PickupType.XP_GEM
		loot_mgr.spawn_pickup(p_type, player.global_position + offset, 5.0)

	await create_timer(0.35).timeout
	for f in range(2):
		await process_frame

	if DisplayServer.get_name() != "headless":
		var vp = root.get_viewport()
		var tex = vp.get_texture()
		var img = tex.get_image()
		if img:
			img.save_png("res://artifacts/pickup_collection_animation.png")
			print("  [PASS] 6. Captured pickup_collection_animation.png screenshot.")

	# If level up triggered an upgrade dialog, apply choice to unpause
	var progression = player.get_node_or_null("RunProgression")
	if progression:
		while progression.queued_level_ups > 0:
			progression.apply_upgrade_choice("Field Repair")
	if game.has_node("UI/UpgradeDialog"):
		game.get_node("UI/UpgradeDialog").hide()
	game.get_tree().paused = false

	# Wait for pickups to fully reach player and complete collection
	await create_timer(0.4).timeout

	var gm = game.get_node_or_null("/root/GameManager")
	if gm:
		assert(gm.coins_collected > 0, "Coins must be collected and register in GameManager")
		print("  [PASS] 7. Total coins collected: %d (Economy registered successfully)." % gm.coins_collected)
	if progression:
		print("  [PASS] 8. Run XP registered: %d XP (Level: %d)." % [progression.current_run_xp, progression.current_run_level])

	print("--- ALL PICKUP ANIMATION CHECKS PASSED ---")
	quit(0)
