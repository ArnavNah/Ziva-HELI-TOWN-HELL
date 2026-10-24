class_name DamageData
extends RefCounted

## DamageData — Carries all contextual info for a hit event, ensuring accurate
## weapon XP attribution, affinity scaling, and status procs.

var raw_damage: float = 0.0
var weapon_type: int = GameConstants.WeaponType.MACHINE_GUN
var attacker: Node = null
# Preserve a bearing even when the firing enemy dies before its projectile lands.
var source_position: Vector3 = Vector3.ZERO
var has_source_position: bool = false
var is_salvo: bool = false
var is_crit: bool = false
var blast_radius: float = 0.0
var impact_fx_handled: bool = false

# Status effect chances/overrides
var burn_chance: float = 0.0
var emp_chance: float = 0.0
var emp_duration: float = GameConstants.STATUS_EMP_DURATION
var shock_chance: float = 0.0
var armored_bonus: float = 0.0
var structure_bonus: float = 0.0
var cluster_count: int = 0
var is_already_scaled: bool = false
var lingering_fire: bool = false

func _init(
	p_raw_damage: float = 10.0,
	p_weapon_type: int = GameConstants.WeaponType.MACHINE_GUN,
	p_attacker: Node = null,
	p_is_salvo: bool = false,
	p_blast_radius: float = 0.0,
	p_apply_multiplier: bool = true
) -> void:
	raw_damage = p_raw_damage
	# Snapshot enemy strength once; blast targets and status ticks reuse this hit data.
	if p_apply_multiplier and is_instance_valid(p_attacker) and "combat_damage_multiplier" in p_attacker:
		raw_damage *= p_attacker.combat_damage_multiplier
		is_already_scaled = true
	elif not p_apply_multiplier:
		is_already_scaled = true
	weapon_type = p_weapon_type
	attacker = p_attacker
	if is_instance_valid(p_attacker) and p_attacker is Node3D and p_attacker.is_inside_tree():
		source_position = p_attacker.global_position
		has_source_position = true
	is_salvo = p_is_salvo
	blast_radius = p_blast_radius

func clone_scaled(scale_factor: float = 1.0) -> DamageData:
	var valid_attacker: Node = attacker if is_instance_valid(attacker) else null
	var copy = DamageData.new(
		raw_damage * scale_factor,
		weapon_type,
		valid_attacker,
		is_salvo,
		blast_radius,
		false # Do not reapply attacker multiplier!
	)
	copy.source_position = source_position
	copy.has_source_position = has_source_position
	copy.is_crit = is_crit
	copy.burn_chance = burn_chance
	copy.emp_chance = emp_chance
	copy.emp_duration = emp_duration
	copy.shock_chance = shock_chance
	copy.armored_bonus = armored_bonus
	copy.structure_bonus = structure_bonus
	copy.cluster_count = cluster_count
	copy.lingering_fire = lingering_fire
	copy.impact_fx_handled = impact_fx_handled
	return copy
