class_name SpawnCard
extends Resource

## SpawnCard — Typed Godot Resource defining encounter spawning units,
## military category, credit cost, selection weight, stream eligibility,
## wave gates, variant caps, and group size.

@export var card_id: String = ""
@export var variant_id: String = ""
@export var category: String = "light_mobile" # light_mobile, heavy_armor, attack_aircraft, support, area_denial
@export var cost: int = 10
@export var weight: float = 1.0
@export var gate_wave: int = 1
@export var max_cap: int = 4
@export var allowed_streams: Array[String] = ["fast", "slow"]
@export var allowed_themes: Array[String] = [] # Empty means eligible across all themes
@export var group_size: int = 1
@export var is_heavy: bool = false
@export var is_air: bool = false
@export var requires_heavy_slot: bool = false
@export var requires_air_slot: bool = false
@export var modifier_type: int = 0 # Matches EnemyData.ModifierType.NONE

const VALID_CATEGORIES: Array[String] = [
	"light_mobile",
	"heavy_armor",
	"attack_aircraft",
	"support",
	"area_denial"
]

const EnemyDataClass = preload("res://src/enemies/enemy_data.gd")

func validate() -> bool:
	if card_id.is_empty():
		push_warning("SpawnCard: Empty card_id")
		return false
	if variant_id.is_empty():
		push_warning("SpawnCard [%s]: Empty variant_id" % card_id)
		return false
	if not EnemyDataClass.is_variant_enabled(variant_id):
		push_warning("SpawnCard [%s]: Variant '%s' is not enabled in active roster" % [card_id, variant_id])
		return false
	if cost <= 0:
		push_warning("SpawnCard [%s]: Cost must be positive (got %d)" % [card_id, cost])
		return false
	if weight <= 0.0:
		push_warning("SpawnCard [%s]: Weight must be positive (got %f)" % [card_id, weight])
		return false
	if group_size < 1 or group_size > 6:
		push_warning("SpawnCard [%s]: Group size must be between 1 and 6 (got %d)" % [card_id, group_size])
		return false
	if not category in VALID_CATEGORIES:
		push_warning("SpawnCard [%s]: Invalid category '%s'" % [card_id, category])
		return false
	var spec: Dictionary = EnemyDataClass.get_spec(variant_id)
	if gate_wave < int(spec.get("gate_wave", 1)) or max_cap < 1 or max_cap > int(spec.get("max_cap", 4)) or group_size > max_cap:
		return false
	if modifier_type not in [EnemyDataClass.ModifierType.NONE, EnemyDataClass.ModifierType.ELITE, EnemyDataClass.ModifierType.SHIELDED]:
		return false
	if allowed_streams.is_empty() or not is_finite(weight):
		return false
	for stream in allowed_streams:
		if stream not in ["fast", "slow"]:
			return false
	if is_air != (spec.get("family", "air") != "ground"):
		return false
	return true

func is_eligible(wave: int, theme: String, stream: String) -> bool:
	if wave < gate_wave:
		return false
	if not allowed_streams.is_empty() and not (stream in allowed_streams):
		return false
	if not allowed_themes.is_empty() and not (theme in allowed_themes):
		return false
	return true
