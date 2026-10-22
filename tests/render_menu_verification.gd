extends SceneTree

## Menu system comprehensive integration and verification test suite.

var frame: int = 0
var main_menu: MainMenu
var main_game: Node3D
var artifacts_dir: String = "res://artifacts/menu-repair-tests"

func _init() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		push_error("Use tools/run_menu_checks.py with an isolated profile.")
		quit(1)
		return
	print(">>> STARTING MENU SYSTEM VERIFICATION SUITE <<<")
	main_menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(main_menu)
	current_scene = main_menu

	var runner = MenuTestRunner.new()
	runner.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(runner)

class MenuTestRunner extends Node:
	var frame: int = 0
	var artifacts_dir: String = "res://artifacts/menu-repair-tests"

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		frame += 1

		# Frame 10: Open Hangar Menu on Armory Mods tab and take screenshot
		if frame == 10:
			var menu = get_tree().current_scene as MainMenu
			if menu:
				print("[Step 1] Opening Hangar Menu...")
				menu._on_hangar_pressed()
				var hangar = menu.get_node_or_null("HangarMenu") as HangarMenu
				if hangar:
					# Switch to WEAPON MODS tab
					hangar._switch_tab(HangarMenu.TabIndex.MODS)
					print("[Step 1] Switched to Armory Weapon Mods tab.")

		if frame == 25:
			_capture("hangar_armory_verification.png")
			# Now switch to Systems tab and buy an upgrade to test economic persistence
			var menu = get_tree().current_scene as MainMenu
			if menu:
				var hangar = menu.get_node_or_null("HangarMenu") as HangarMenu
				if hangar:
					hangar._switch_tab(HangarMenu.TabIndex.SYSTEMS)
					var pm = get_tree().root.get_node_or_null("ProfileManager")
					if pm:
						pm.wallet_credits = 2500 # Grant test credits
						hangar.refresh_ui()
						print("[Step 2] Switched to Systems tab. Wallet: ", pm.wallet_credits)

		if frame == 40:
			_capture("hangar_systems_verification.png")
			# Close hangar, open Settings
			var menu = get_tree().current_scene as MainMenu
			if menu:
				var hangar = menu.get_node_or_null("HangarMenu") as HangarMenu
				if hangar:
					hangar.visible = false
					menu._sync_overlay_focus()
				print("[Step 3] Opening Settings Menu...")
				menu._on_settings_pressed()
				var settings = menu.get_node_or_null("SettingsMenu") as SettingsMenu
				if settings:
					# Switch to Controls view
					settings._switch_sub_view(false)
					print("[Step 3] Switched Settings to Controls view.")

		if frame == 55:
			_capture("settings_controls_verification.png")
			# Switch Settings to Preferences view
			var menu = get_tree().current_scene as MainMenu
			if menu:
				var settings = menu.get_node_or_null("SettingsMenu") as SettingsMenu
				if settings:
					settings._switch_sub_view(true)

		if frame == 70:
			_capture("settings_preferences_verification.png")
			# Now transition to MainGame to test In-Game Pause and In-Game Settings!
			print("[Step 4] Launching Main Game to test In-Game Pause and Settings...")
			var menu = get_tree().current_scene
			if menu:
				menu.queue_free()
			var game = load("res://scenes/main_game.tscn").instantiate()
			get_tree().root.add_child(game)
			get_tree().current_scene = game

		# In-Game tests
		if frame == 85:
			var game = get_tree().current_scene
			if game and game.name == "MainGame":
				print("[Step 5] Triggering Pause Menu in Main Game...")
				var pause = game.get_node_or_null("UI/PauseMenu") as PauseMenu
				if pause:
					pause.toggle_pause()
					print("[Step 5] Pause Menu opened, telemetry active.")

		if frame == 100:
			_capture("in_game_pause_verification.png")
			# Test opening Settings from inside In-Game Pause!
			var game = get_tree().current_scene
			if game:
				var pause = game.get_node_or_null("UI/PauseMenu") as PauseMenu
				if pause:
					print("[Step 6] Opening Settings from Pause Menu...")
					pause._on_settings_pressed()

		if frame == 115:
			_capture("in_game_settings_verification.png")
			# Close settings and test Debrief Screen
			var game = get_tree().current_scene
			if game:
				var settings = game.get_node_or_null("UI/SettingsMenu")
				if settings:
					settings.visible = false
				var pause = game.get_node_or_null("UI/PauseMenu")
				if pause:
					pause.visible = false
				get_tree().paused = false
				
				print("[Step 7] Testing Operational Debrief Screen...")
				var debrief = game.get_node_or_null("UI/DebriefScreen") as DebriefScreen
				if debrief:
					var test_summary = {
						"successful": true,
						"cause_of_death": "Extracted Safely",
						"survival_time": 245.0,
						"distance_flown_m": 4200.0,
						"wave_reached": 6,
						"kills": 38,
						"ground_kills": 24,
						"air_kills": 14,
						"score": 15800,
						"combat_pay": 180,
						"banked_credits": 650,
						"salvage_credits": 120,
						"at_risk_recovered": 300,
						"at_risk_lost": 0,
						"salvage_lost": 0,
						"total_payout": 1250
					}
					debrief.show_debrief(test_summary)

		if frame == 130:
			_capture("debrief_victory_verification.png")
			print(">>> ALL MENU VERIFICATION CAPTURES COMPLETE! <<<")
			get_tree().quit(0)

	func _capture(file_name: String) -> void:
		var img = get_viewport().get_texture().get_image()
		if img and not img.is_empty():
			var p = artifacts_dir + "/" + file_name
			img.save_png(p)
			print("Saved verification screenshot: ", p)
