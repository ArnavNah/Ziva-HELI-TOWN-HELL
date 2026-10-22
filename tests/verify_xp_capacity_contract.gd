extends SceneTree

## Verification only: exercise an actual catalog card against production weapons.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	var player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	root.get_node("XpManager").reset_run()
	root.get_node("XpManager").add_xp(25) # This rare card unlocks at level two.
	var weapons = player.get_node("Weapons")
	var before: int = weapons.get_max_ammo(GameConstants.WeaponType.MACHINE_GUN)
	for card in load("res://src/resources/upgrade_card_database.gd").get_master_deck():
		if card.card_id == "cannon_rotary_overdrive":
			print("Applying real ROTARY OVERDRIVE card: ", card.stat_changes)
			player.get_node("SubsystemManager").apply_upgrade(card)
	var after: int = weapons.get_max_ammo(GameConstants.WeaponType.MACHINE_GUN)
	print("CAPACITY_CONTRACT before=", before, " after=", after, " expected=", roundi(before * 1.30))
	quit(0 if after == roundi(before * 1.30) else 1)
