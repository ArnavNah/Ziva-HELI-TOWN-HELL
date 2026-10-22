class_name RunProgression
extends Node

## RunProgression — In-run XP leveling (1-15), 3-choice upgrade cards, and card application (Page 18).
## Authoritative XP progression ledger and transactional upgrade choice authority.

const UpgradeCatalog = preload("res://src/player/upgrade_catalog.gd")

signal run_leveled_up(new_level: int)
signal upgrade_choices_offered(choices: Array[String])
signal upgrade_applied(upgrade_name: String)

var current_run_xp: int = 0
var current_run_level: int = 1
var queued_level_ups: int = 0
var current_offers: Array[String] = []

# Upgrade Stacks
var upgrade_stacks: Dictionary = {
	"overclock_rounds": 0,
	"hair_trigger": 0,
	"extended_mag": 0,
	"speed_loader": 0,
	"salvo_overclock": 0,
	"reinforced_hull": 0,
	"reactive_armor": 0,
	"turbine_tune": 0,
	"vector_jets": 0,
	"airstrike": 0,
	"field_repair": 0,
	"aegis_field": 0
}

var evolved_weapons: Array[String] = []
var has_legendary: bool = false
var card_cooldown_timer: float = 0.0
const CONSECUTIVE_CARD_COOLDOWN: float = 2.5 # 2.5s live combat breather between consecutive upgrade cards
var presentation_delay_timer: float = 0.0

@export var player_helicopter: CharacterBody3D

func _get_player_helicopter() -> CharacterBody3D:
	if player_helicopter and is_instance_valid(player_helicopter):
		return player_helicopter
	if get_parent() is CharacterBody3D:
		player_helicopter = get_parent()
		return player_helicopter
	if is_inside_tree():
		var p = get_tree().get_first_node_in_group("player")
		if p is CharacterBody3D:
			player_helicopter = p
			return player_helicopter
	return null

func _ready() -> void:
	if not player_helicopter and get_parent() is CharacterBody3D:
		player_helicopter = get_parent()
	if is_inside_tree() and has_node("/root/GameManager"):
		get_node("/root/GameManager").active_run_progression = self
	elif is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").entity_destroyed.connect(_on_entity_destroyed_standalone)
	var xp_manager = get_node_or_null("/root/XpManager")
	if xp_manager:
		xp_manager.xp_changed.connect(_sync_xp_manager)
		_sync_xp_manager(0, 0)

func _sync_xp_manager(_current_xp: int, _target_xp: int) -> void:
	var xp_manager = get_node_or_null("/root/XpManager")
	if xp_manager:
		current_run_xp = xp_manager.total_xp_collected
		current_run_level = xp_manager.current_level
		queued_level_ups = xp_manager.queued_level_ups

func _exit_tree() -> void:
	if is_inside_tree() and has_node("/root/GameManager"):
		if get_node("/root/GameManager").active_run_progression == self:
			get_node("/root/GameManager").active_run_progression = null

func _on_entity_destroyed_standalone(_entity: Node, _weapon: String, _score: int, xp_val: int) -> void:
	if not has_node("/root/GameManager"):
		add_run_xp(xp_val)

func _process(delta: float) -> void:
	if has_node("/root/XpManager"):
		return # Compatibility ledger; LevelUpUi owns the authoritative draft.
	if card_cooldown_timer > 0.0:
		card_cooldown_timer = maxf(0.0, card_cooldown_timer - delta)

	if presentation_delay_timer > 0.0:
		presentation_delay_timer = maxf(0.0, presentation_delay_timer - delta)
		if presentation_delay_timer <= 0.0:
			_try_offer_upgrade()
	elif queued_level_ups > 0 and current_offers.is_empty() and card_cooldown_timer <= 0.0:
		_try_offer_upgrade()

func _try_offer_upgrade() -> void:
	if queued_level_ups <= 0 or not current_offers.is_empty():
		return
	var p = _get_player_helicopter()
	if p and "is_dashing" in p and p.is_dashing:
		return # Don't interrupt active evasive dash
	if p and "is_dying" in p and p.is_dying:
		return
	_offer_next_upgrade_choice()

func add_run_xp(amount: int) -> void:
	if amount <= 0:
		return
	var xp_manager = get_node_or_null("/root/XpManager")
	if xp_manager:
		xp_manager.add_xp(amount)
		return
	if current_run_level >= GameConstants.MAX_RUN_LEVEL:
		return

	current_run_xp += amount
	if is_inside_tree() and has_node("/root/GameManager"):
		get_node("/root/GameManager").run_xp = current_run_xp
	_check_for_level_ups()

func _check_for_level_ups() -> void:
	while current_run_level < GameConstants.MAX_RUN_LEVEL:
		var next_thresh = GameConstants.RUN_XP_THRESHOLDS[current_run_level - 1]
		if current_run_xp >= next_thresh:
			current_run_level += 1
			queued_level_ups += 1
			run_leveled_up.emit(current_run_level)
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("level_up", 1.0, 3.0)
		else:
			break

	if queued_level_ups > 0 and current_offers.is_empty():
		if card_cooldown_timer <= 0.0 and presentation_delay_timer <= 0.0:
			presentation_delay_timer = 0.35 # Brief combat breather before pausing

func _offer_next_upgrade_choice() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.current_state in [gm.RunState.BOSS_DECISION, gm.RunState.RESULTS, gm.RunState.LOADING, gm.RunState.PAUSED]:
			return
	if queued_level_ups <= 0 or not current_offers.is_empty():
		return

	# Collect candidate pool from UpgradeCatalog
	var p = _get_player_helicopter()
	var candidates: Array[String] = []
	for item_id in UpgradeCatalog.CATALOG:
		var entry: Dictionary = UpgradeCatalog.CATALOG[item_id]
		if UpgradeCatalog.is_eligible(entry, p, self):
			candidates.append(entry.get("title", item_id))

	if candidates.is_empty():
		# Empty pool fallback: Field repair is always safe
		candidates.append("Field Repair")

	candidates.shuffle()
	var pick_count = mini(3, candidates.size())
	var three_choices: Array[String] = []
	for i in range(pick_count):
		three_choices.append(candidates[i])

	# Pause game and emit choices
	if is_inside_tree() and has_node("/root/GameManager"):
		get_node("/root/GameManager").change_state(get_node("/root/GameManager").RunState.UPGRADE_CHOICE)

	current_offers = three_choices.duplicate()
	upgrade_choices_offered.emit(three_choices)

func apply_upgrade_choice(chosen_name_or_id: String) -> bool:
	if queued_level_ups <= 0:
		push_warning("RunProgression: No queued level up choices available.")
		return false

	# Match against current offers (by title or ID)
	var matched_offer_idx := -1
	var resolved_entry: Dictionary = {}

	for i in range(current_offers.size()):
		var off = current_offers[i]
		if off == chosen_name_or_id:
			matched_offer_idx = i
			resolved_entry = UpgradeCatalog.get_entry(off)
			break
		var off_entry = UpgradeCatalog.get_entry(off)
		if off_entry.get("id", "") == chosen_name_or_id or off_entry.get("title", "") == chosen_name_or_id:
			matched_offer_idx = i
			resolved_entry = off_entry
			break

	if matched_offer_idx == -1 or resolved_entry.is_empty():
		push_warning("RunProgression: Rejected invalid upgrade choice: %s" % chosen_name_or_id)
		return false

	var item_id = resolved_entry.get("id", "")
	var p = _get_player_helicopter()

	# Apply effect authoritatively
	var applied_ok = UpgradeCatalog.apply_effect(item_id, p, self)
	if not applied_ok:
		push_warning("RunProgression: Failed applying effect for upgrade: %s" % item_id)
		return false

	# Update stack counts
	upgrade_stacks[item_id] = upgrade_stacks.get(item_id, 0) + 1

	# Successfully committed transaction: Consume choice and clear offers
	queued_level_ups = maxi(0, queued_level_ups - 1)
	current_offers.clear()

	upgrade_applied.emit(resolved_entry.get("title", chosen_name_or_id))

	if queued_level_ups > 0:
		card_cooldown_timer = CONSECUTIVE_CARD_COOLDOWN

	# Reconcile GameManager state ONLY if we are currently in UPGRADE_CHOICE
	if is_inside_tree() and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.current_state == gm.RunState.UPGRADE_CHOICE:
			gm.change_state(gm.RunState.ACTIVE)

	return true
