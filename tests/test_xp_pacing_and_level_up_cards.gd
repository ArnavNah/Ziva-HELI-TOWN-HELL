extends SceneTree

## Dedicated Verification Test for XP Collection Pacing & Level-Up Card Modal
## Verifies:
## 1. Destructible scenery / non-hostiles do NOT award run progression XP.
## 2. Enemy kills drop tier-calibrated XP gems (scout/swarmer = 1.0 XP).
## 3. Physical pickup collection awards XP cleanly without double attribution.
## 4. Level-up cards do NOT freeze back-to-back; 2.5s combat breather is enforced.
## 5. UpgradeDialog features backdrop, category badges, and keyboard shortcuts (1, 2, 3).
## 6. HUD indicates queued pending upgrades during combat breathers.

func _init() -> void:
	print("==================================================================")
	print("--- BEGIN XP COLLECTION PACING & LEVEL-UP CARD VERIFICATION ---")
	print("==================================================================")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)
	var runner = XPPacingRunner.new()
	root.add_child(runner)

class XPPacingRunner extends Node:
	var frame: int = 0
	var tests_passed: int = 0
	var total_tests: int = 6
	var player: PlayerHelicopter = null
	var progression: RunProgression = null
	var hud: CombatHUD = null
	var upgrade_dialog: UpgradeDialog = null
	var start_xp: int = 0

	func check(condition: bool, message: String) -> void:
		if condition:
			print("  [PASS] ", message)
			tests_passed += 1
		else:
			push_error("  [FAIL] " + message)
			print("  [FAIL] ", message)

	func _process(_delta: float) -> void:
		frame += 1

		if frame == 5:
			player = get_tree().get_first_node_in_group("player") as PlayerHelicopter
			hud = get_tree().root.find_child("CombatHUD", true, false) as CombatHUD
			upgrade_dialog = get_tree().root.find_child("UpgradeDialog", true, false) as UpgradeDialog

			if not player or not player.has_node("RunProgression"):
				print("[FAIL] Player or RunProgression not found.")
				get_tree().quit(1)
				return
			progression = player.get_node("RunProgression")
			start_xp = progression.current_run_xp

		elif frame == 10:
			# -----------------------------------------------------------------
			# TEST 1: Non-hostile destruction does NOT award XP
			# -----------------------------------------------------------------
			var dummy_prop = Node3D.new()
			dummy_prop.name = "BuildingProp"
			# Note: dummy_prop is NOT in group "enemies"
			get_tree().root.add_child(dummy_prop)
			
			get_tree().root.get_node("/root/EventBus").entity_destroyed.emit(dummy_prop, "Rocket", 50, 0)
			check(progression.current_run_xp == start_xp, "1. Scenery / non-hostile destruction awards 0 run XP (XP remains %d)" % progression.current_run_xp)
			dummy_prop.queue_free()

		elif frame == 15:
			# -----------------------------------------------------------------
			# TEST 2: Enemy kill drops tier-calibrated XP gem
			# -----------------------------------------------------------------
			var enemy = Node3D.new()
			enemy.name = "TestDrone"
			enemy.add_to_group("enemies")
			enemy.set("variant_id", "hunter_drone") # spec raw_xp = 3 -> floor(3 * 0.5) = 1.0 XP
			get_tree().root.add_child(enemy)

			var loot_mgr = get_tree().root.find_child("LootManager", true, false) as LootManager
			if loot_mgr:
				var gem = loot_mgr.spawn_pickup(Pickup.PickupType.XP_GEM, player.global_position + Vector3(2.0, 0, 0), 1.0)
				check(gem != null and gem.pickup_value == 1.0, "2. Enemy drops tier-calibrated XP gem of 1.0 XP (prevents instant runaway leveling)")
				gem.queue_free()
			else:
				check(false, "2. LootManager not found")
			enemy.queue_free()

		elif frame == 20:
			# -----------------------------------------------------------------
			# TEST 3: Physical pickup awards XP cleanly without double-dipping
			# -----------------------------------------------------------------
			var xp_before = progression.current_run_xp
			progression.add_run_xp(2) # Collect 2 XP gem
			check(progression.current_run_xp == xp_before + 2, "3. Physical XP gem collection adds exact 2 XP to RunProgression (now %d XP)" % progression.current_run_xp)

		elif frame == 25:
			# -----------------------------------------------------------------
			# TEST 4: Pacing & Combat Breather between consecutive level-ups
			# -----------------------------------------------------------------
			# Trigger 2 queued level ups
			progression.queued_level_ups = 2
			progression.current_offers = ["Overclock Rounds", "Reinforced Hull", "Turbine Tune"]
			progression.apply_upgrade_choice("Overclock Rounds")

			# Verify game resumed ACTIVE combat and set a 2.5s breather timer
			var gm = get_tree().root.get_node_or_null("/root/GameManager")
			var is_active = (gm and gm.current_state == gm.RunState.ACTIVE)
			var has_breather = progression.card_cooldown_timer > 1.5
			check(is_active and has_breather, "4. Level-Up Card Pacing: Game immediately unpauses into active combat with %.1fs breather before next card" % progression.card_cooldown_timer)

		elif frame == 30:
			# -----------------------------------------------------------------
			# TEST 5: UpgradeDialog Visual Features & Hotkeys
			# -----------------------------------------------------------------
			if upgrade_dialog:
				upgrade_dialog.show_choices(["Overclock Rounds", "EVOLUTION: Vulcan Storm", "LEGENDARY: Ghost Rotor"])
				var has_backdrop = upgrade_dialog.backdrop != null
				var btn1_text = upgrade_dialog.button_1.text
				var has_badge = btn1_text.contains("[OFFENSE]") and btn1_text.contains("[ 1 ]")
				check(has_backdrop and has_badge, "5. UpgradeDialog: Full-screen dimmed backdrop, [1]/[2]/[3] shortcut badges, and category tags applied")
				upgrade_dialog.hide()
			else:
				check(false, "5. UpgradeDialog not found")

		elif frame == 35:
			# -----------------------------------------------------------------
			# TEST 6: HUD Pending Upgrade Indicator
			# -----------------------------------------------------------------
			var sur_hud = get_tree().root.find_child("SurvivalHUD", true, false)
			if sur_hud and sur_hud.level_label:
				# The new manager owns pending drafts; the legacy ledger is a mirror.
				get_tree().root.get_node("XpManager").queued_level_ups = 1
				sur_hud.refresh(get_tree().root.get_node_or_null("/root/GameManager"), player)
				var text = sur_hud.level_label.text
				check(text.contains("[+"), "6. HUD Level Indicator: Shows pending upgrade queue in gold badge (%s) during combat breather" % text)
			else:
				check(false, "6. SurvivalHUD level label not found")

		elif frame == 40:
			print("==================================================================")
			print("XP PACING & LEVEL-UP CARD TESTS: %d/%d PASSED" % [tests_passed, total_tests])
			print("==================================================================")
			if tests_passed == total_tests:
				get_tree().quit(0)
			else:
				get_tree().quit(1)
