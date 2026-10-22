class_name CargoManager
extends Node

## CargoManager — Full cargo contract lifecycle, handling penalty, and depot service (Page 15 & 16).

const CargoSpecsClass = preload("res://src/missions/cargo_specs.gd")

enum CargoState {
	IDLE = 0,
	OFFERED = 1,
	ACCEPTED = 2,
	LOADING = 3,
	CARRYING = 4,
	UNLOADING = 5,
	COMPLETED = 6
}

var current_state: CargoState = CargoState.IDLE
var current_contract: Dictionary = {}
var pickup_pos: Vector3 = Vector3(50, 0, 50)
var dropoff_pos: Vector3 = Vector3(-120, 0, -100)

var load_hold_timer: float = 0.0
var unload_hold_timer: float = 0.0
var delivery_flight_timer: float = 0.0
var contract_cooldown: float = 14.0
var cooldown_timer: float = 4.0

# Depot service
var depot_service_cooldown: float = 0.0

func _process(delta: float) -> void:
	if depot_service_cooldown > 0.0:
		depot_service_cooldown -= delta

	if current_state == CargoState.IDLE:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			offer_contract("ammunition", 600.0)
		return

	var player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player:
		return

	# Handle depot repair / refill service if near either depot (within 18 units)
	_process_depot_service(player)

	var p_horiz = Vector2(player.global_position.x, player.global_position.z)

	match current_state:
		CargoState.OFFERED:
			var pick_horiz = Vector2(pickup_pos.x, pickup_pos.z)
			if p_horiz.distance_to(pick_horiz) <= 22.0:
				current_state = CargoState.LOADING
				load_hold_timer = 0.0

		CargoState.LOADING:
			var pick_horiz = Vector2(pickup_pos.x, pickup_pos.z)
			if p_horiz.distance_to(pick_horiz) <= 22.0:
				load_hold_timer += delta
				if load_hold_timer >= 1.0: # Hold for 1 second (Page 15)
					_attach_cargo_to_player(player)
					current_state = CargoState.CARRYING
					delivery_flight_timer = 0.0
			else:
				# Decays when drifting out
				load_hold_timer = maxf(0.0, load_hold_timer - delta * 2.0)

		CargoState.CARRYING:
			delivery_flight_timer += delta
			var drop_horiz = Vector2(dropoff_pos.x, dropoff_pos.z)
			if p_horiz.distance_to(drop_horiz) <= 20.0:
				current_state = CargoState.UNLOADING
				unload_hold_timer = 0.0

			# Max delivery carry limit: 240s
			if delivery_flight_timer >= 240.0:
				fail_delivery("Time expired")

		CargoState.UNLOADING:
			var drop_horiz = Vector2(dropoff_pos.x, dropoff_pos.z)
			if p_horiz.distance_to(drop_horiz) <= 20.0:
				unload_hold_timer += delta
				if unload_hold_timer >= 0.75: # Hold for 0.75 seconds (Page 15)
					_complete_delivery(player)
			else:
				current_state = CargoState.CARRYING

func offer_contract(commodity: String, dist: float) -> void:
	current_contract = CargoSpecsClass.calculate_contract_price(commodity, dist, 1.0)
	current_state = CargoState.OFFERED

func _attach_cargo_to_player(player: CharacterBody3D) -> void:
	# Base cargo handling multiplier is 0.91 (Page 15)
	player.cargo_mass_multiplier = 0.91

func _complete_delivery(player: CharacterBody3D) -> void:
	current_state = CargoState.COMPLETED
	player.cargo_mass_multiplier = 1.0

	var speed_won = (delivery_flight_timer <= current_contract["time_limit"])
	var base_cr = current_contract["base_price"]
	var speed_cr = current_contract["speed_bonus"] if speed_won else 0

	if is_inside_tree() and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.add_banked_credits(base_cr) # Immediately banked
		if speed_won:
			gm.add_at_risk_credits(speed_cr) # At risk until extraction
		gm.add_salvage(2)

	# Replenish 1 flare if ammunition cargo (Page 16)
	if current_contract.get("commodity") == "Ammunition" and player.has_node("Countermeasures"):
		player.get_node("Countermeasures").replenish_charges(1)

	# Reset after cooldown
	cooldown_timer = contract_cooldown
	current_state = CargoState.IDLE

func fail_delivery(_reason: String) -> void:
	var player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		player.cargo_mass_multiplier = 1.0
	current_state = CargoState.IDLE
	cooldown_timer = contract_cooldown

func _process_depot_service(player: CharacterBody3D) -> void:
	if depot_service_cooldown > 0.0:
		return
	var p_horiz = Vector2(player.global_position.x, player.global_position.z)
	var near_pick = p_horiz.distance_to(Vector2(pickup_pos.x, pickup_pos.z)) <= 18.0
	var near_drop = p_horiz.distance_to(Vector2(dropoff_pos.x, dropoff_pos.z)) <= 18.0

	if near_pick or near_drop:
		depot_service_cooldown = 16.0 # 16s cooldown (Page 15)
		# Restores 18% hull, 20% fuel, 25% ammo
		player.repair(player.max_hull * 0.18)
		player.refill_fuel(player.max_fuel * 0.20)
		if player.has_node("Weapons"):
			var wp = player.get_node("Weapons")
			var st = wp.weapon_states[wp.current_weapon_idx]
			var max_a = GameConstants.WEAPONS[wp.current_weapon_idx]["ammo_max"]
			st["ammo"] = mini(max_a, st["ammo"] + int(float(max_a) * 0.25))
