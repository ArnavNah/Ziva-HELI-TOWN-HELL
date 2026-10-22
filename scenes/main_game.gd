extends Node3D

signal scene_prepared
var is_prepared: bool = false
var session_started: bool = false

## MainGame — Master orchestrator scene linking flight, combat, waves, world, and UI.

@onready var player: CharacterBody3D = $PlayerHelicopter
@onready var hud: CanvasLayer = $UI/CombatHUD
@onready var upgrade_dialog: Control = $UI/UpgradeDialog
@onready var debrief_screen: Control = $UI/DebriefScreen
@onready var mission_mgr: Node = $MissionManager
@onready var cargo_mgr: Node = $CargoManager
@onready var enemy_spawner: Node = $EnemySpawner

func _ready() -> void:
	$Ground/MeshInstance3D.material_override = preload("res://src/world/stylized_materials.gd").terrain()
	_connect_events()
	_prepare_session.call_deferred()

func _connect_events() -> void:
	if has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		bus.run_completed.connect(_on_run_completed)
		bus.entity_destroyed.connect(_on_entity_destroyed)

	if player and player.has_node("RunProgression"):
		var rp = player.get_node("RunProgression")
		rp.upgrade_choices_offered.connect(_on_upgrade_choices_offered)

func _start_game_session() -> void:
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.start_new_run(gm.selected_aircraft if gm.selected_aircraft != "" else "apache")
	if has_node("/root/CombatDirector"):
		get_node("/root/CombatDirector").start_wave_director()

func _on_upgrade_choices_offered(choices: Array[String]) -> void:
	if upgrade_dialog and upgrade_dialog.has_method("show_choices"):
		upgrade_dialog.show_choices(choices)

func _on_run_completed(_success: bool, summary: Dictionary) -> void:
	upgrade_dialog.hide()
	$UI/BossDecisionDialog.hide()
	$UI/PauseMenu.hide()
	$UI/SettingsMenu.hide()
	if debrief_screen and debrief_screen.has_method("show_debrief"):
		debrief_screen.show_debrief(summary)

func _on_entity_destroyed(_entity: Node, _killer: String, _score: int, _xp: int) -> void:
	if mission_mgr and mission_mgr.has_method("register_kill_for_mission"):
		mission_mgr.register_kill_for_mission()

func _prepare_session() -> void:
	var city = get_node_or_null("CityGenerator")
	if city and "is_generating" in city and city.is_generating:
		await city.generation_complete
	var pm = get_node_or_null("/root/ProfileManager")
	if pm and player:
		pm.apply_loadout(player)
	await get_tree().process_frame
	is_prepared = is_instance_valid(player) and is_instance_valid(hud) and player.get_node_or_null("PlayerCamera") != null
	if not is_prepared:
		return
	scene_prepared.emit()
	if not get_node("/root/UIFlow").busy:
		activate_session()

func activate_session() -> void:
	if session_started or not is_prepared:
		return
	session_started = true
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		if player and player.has_method("activate_spawn_grace"):
			player.activate_spawn_grace(2.0)
	_start_game_session()
