@warning_ignore("unused_signal")
extends Node

## Global EventBus for Heli-Town Hell
## Decouples combat, mission, delivery, score, and state notifications.

# Combat & Damage Signals
signal damage_dealt(target: Node, amount: float, source_weapon: String, is_lethal: bool)
signal entity_destroyed(entity: Node, killer_weapon: String, score_val: int, xp_val: int)
signal enemy_destroyed(enemy_node: Node, score_val: int)
signal player_damaged(current_hull: float, max_hull: float, damage_amount: float)
signal player_hit(damage_amount: float, source_position: Vector3, has_direction: bool, source_label: String)
signal player_healed(current_hull: float, max_hull: float)
signal player_fuel_changed(current_fuel: float, max_fuel: float)
signal player_died(cause: String)

# Weapon & Ammo Signals
signal weapon_fired(weapon_id: int, ammo_remaining: int)
signal weapon_reloaded(weapon_id: int)
signal weapon_switched(weapon_id: int)
signal salvo_lock_added(target: Node, lock_count: int)
signal salvo_launched(missile_count: int)
signal flares_deployed(charges_left: int)
signal super_activated()
signal super_charge_changed(current_charge: float, max_charge: float)

# Mission & Cargo Signals
signal tactical_mission_started(mission_data: Dictionary)
signal tactical_mission_updated(progress: float, target_goal: float)
signal tactical_mission_completed(mission_data: Dictionary, bonus_achieved: bool)
signal tactical_mission_failed(mission_data: Dictionary)

signal cargo_contract_offered(cargo_data: Dictionary)
signal cargo_loaded(cargo_data: Dictionary)
signal cargo_delivered(cargo_data: Dictionary, speed_bonus: bool, sam_bonus: bool)
signal cargo_failed(cargo_data: Dictionary)

# Waves & Director Signals
signal wave_started(wave_number: int, theme: String, duration: float)
signal wave_cleared(wave_number: int)
signal boss_spawned(boss_node: Node)
signal boss_stage_changed(stage: int)
signal boss_defeated()

# Economy & Pickups
signal pickup_collected(pickup_type: String, value: float)
signal combo_updated(combo_count: int, multiplier: float)
signal credits_banked(amount: int)
signal at_risk_credits_changed(amount: int)
signal salvage_collected(amount: int)

# Score & High Score
signal score_updated(current_score: int, points_added: int)
signal high_score_beaten(new_high_score: int, previous_high_score: int)

# Run State
signal run_state_changed(new_state: int, old_state: int)
signal run_completed(success: bool, stats: Dictionary)

# Boundary Signals
signal border_warning_changed(is_warning: bool, return_dir: Vector3, distance_to_edge: float)

# Threat & Telegraph Warnings (Section 7)
signal threat_warning(source_position: Vector3, threat_type: String, duration: float)

