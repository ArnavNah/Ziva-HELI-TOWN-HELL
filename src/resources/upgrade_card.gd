@tool
class_name UpgradeCard
extends Resource

## UpgradeCard — Data-driven custom Resource defining upgrade metadata, rarity tiers,
## target subsystems (Primary Cannon, Rocket Pods, Guided Missiles, Global Tome),
## and stat modification payloads for the roguelite level-up card draft system.

enum RarityTier {
	COMMON = 0,
	UNCOMMON = 1,
	RARE = 2,
	EPIC = 3,
	LEGENDARY = 4
}

enum SubsystemType {
	PRIMARY_CANNON = 0,
	ROCKET_PODS = 1,
	GUIDED_MISSILES = 2,
	GLOBAL_TOME = 3
}

const RARITY_COLORS: Dictionary = {
	RarityTier.COMMON: Color(0.70, 0.73, 0.78, 1.0),      # Tactical Steel Silver
	RarityTier.UNCOMMON: Color(0.25, 0.85, 0.45, 1.0),    # Emerald Operative Green
	RarityTier.RARE: Color(0.20, 0.65, 1.0, 1.0),         # High-Tech Avionics Cyan/Blue
	RarityTier.EPIC: Color(0.72, 0.35, 0.95, 1.0),        # Experimental Plasma Purple
	RarityTier.LEGENDARY: Color(1.0, 0.84, 0.0, 1.0)      # Prototype Gold / Amber
}

const RARITY_NAMES: Dictionary = {
	RarityTier.COMMON: "COMMON",
	RarityTier.UNCOMMON: "UNCOMMON",
	RarityTier.RARE: "RARE",
	RarityTier.EPIC: "EPIC",
	RarityTier.LEGENDARY: "LEGENDARY"
}

const SUBSYSTEM_NAMES: Dictionary = {
	SubsystemType.PRIMARY_CANNON: "PRIMARY CANNON",
	SubsystemType.ROCKET_PODS: "ROCKET PODS",
	SubsystemType.GUIDED_MISSILES: "GUIDED MISSILES",
	SubsystemType.GLOBAL_TOME: "GLOBAL TOME"
}

@export var card_id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var rarity: RarityTier = RarityTier.COMMON
@export var target_subsystem: SubsystemType = SubsystemType.PRIMARY_CANNON
@export var stat_changes: Dictionary = {}
@export var min_level: int = 1
@export var max_stacks: int = 0 # Zero means unlimited.
@export var required_cards: PackedStringArray = []

static func create(
	p_id: String,
	p_title: String,
	p_desc: String,
	p_rarity: RarityTier,
	p_subsystem: SubsystemType,
	p_stats: Dictionary,
	p_icon: Texture2D = null
) -> UpgradeCard:
	var card = UpgradeCard.new()
	card.card_id = p_id
	card.title = p_title
	card.description = p_desc
	card.rarity = p_rarity
	card.target_subsystem = p_subsystem
	card.stat_changes = p_stats.duplicate(true)
	card.icon = p_icon
	return card

func get_rarity_name() -> String:
	return RARITY_NAMES.get(rarity, "COMMON")

func get_rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)

func get_subsystem_name() -> String:
	return SUBSYSTEM_NAMES.get(target_subsystem, "GLOBAL")

func get_formatted_stats() -> String:
	if stat_changes.is_empty():
		return description
	
	var lines: Array[String] = []
	for key in stat_changes.keys():
		var val = stat_changes[key]
		var label = _format_stat_key(str(key))
		if typeof(val) == TYPE_FLOAT:
			if "mult" in str(key) or "reduction" in str(key) or "chance" in str(key) or str(key) in ["armor_pierce", "armor_mitigation_add", "evasion"]:
				var pct = int(round(val * 100.0))
				if "reduction" in str(key):
					pct = -pct
				var sign_str = "+" if pct > 0 else ""
				lines.append("%s: %s%d%%" % [label, sign_str, pct])
			else:
				var sign_str = "+" if val > 0 else ""
				lines.append("%s: %s%.1f" % [label, sign_str, val])
		elif typeof(val) == TYPE_INT:
			var sign_str = "+" if val > 0 else ""
			lines.append("%s: %s%d" % [label, sign_str, val])
		elif typeof(val) == TYPE_BOOL:
			lines.append("%s: %s" % [label, "ENABLED" if val else "DISABLED"])
		else:
			lines.append("%s: %s" % [label, str(val)])
	return "\n".join(lines)

func _format_stat_key(key: String) -> String:
	var clean = key.replace("_mult", "").replace("_reduction", "").replace("_add", "").replace("_", " ").capitalize()
	return clean
