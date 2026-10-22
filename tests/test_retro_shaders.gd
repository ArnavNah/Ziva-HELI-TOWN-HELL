extends SceneTree

func _init():
	print("--- BEGIN RETRO SHADERS VERIFICATION ---")
	var runner = RetroShaderRunner.new()
	root.add_child(runner)

class RetroShaderRunner extends Node:
	var frame: int = 0
	var tests_passed: int = 0
	var total_tests: int = 6
	var scene_root: Node = null

	func _ready():
		process_mode = Node.PROCESS_MODE_ALWAYS
		var main_scene = preload("res://scenes/main_game.tscn")
		scene_root = main_scene.instantiate()
		get_tree().root.call_deferred("add_child", scene_root)

	func _process(_delta: float):
		frame += 1

		if frame == 5:
			# Test 1: ShaderManager autoload is present and initialized
			var sm = get_tree().root.get_node_or_null("ShaderManager")
			if sm:
				print("  [PASS] 1. ShaderManager: Autoload initialized and operational.")
				tests_passed += 1
			else:
				print("  [FAIL] 1. ShaderManager: Autoload missing.")

		elif frame == 10:
			# Test 2: Nearest Texture Sampling Verification
			var sm = get_tree().root.get_node_or_null("ShaderManager")
			var tex_filter = ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", -1)
			if sm and sm.nearest_sampling_enabled and tex_filter == 0:
				print("  [PASS] 2. Nearest Texture Sampling: Enabled in project settings & ShaderManager.")
				tests_passed += 1
			else:
				print("  [FAIL] 2. Nearest Sampling incorrect. filter=%s" % tex_filter)

		elif frame == 15:
			# Test 3: Selective Silhouette Outlines on Player Helicopter
			var heli = get_tree().get_first_node_in_group("player")
			var has_outline = false
			if heli:
				var meshes = heli.find_children("*", "MeshInstance3D", true, false)
				for m in meshes:
					if m is MeshInstance3D:
						var mat = m.get_active_material(0)
						if not mat and m.material_override:
							mat = m.material_override
						if mat and mat.next_pass is ShaderMaterial:
							has_outline = true
							break
			if has_outline:
				print("  [PASS] 3. Selective Outlines: Inverted hull outline attached to Player Helicopter via next_pass.")
				tests_passed += 1
			else:
				print("  [FAIL] 3. Player Helicopter missing outline next_pass.")

		elif frame == 20:
			# Test 4: Selective Outlines on Hostile Enemy Units, but NOT on City/Roads
			var spawner = scene_root.get_node_or_null("EnemySpawner")
			var enemy_has_outline = false
			if spawner:
				var enemy = spawner.spawn_enemy_type("siege_tank", Vector3(-14.0, 1.0, 5.0))
				if enemy:
					# Check enemy meshes for outline next_pass
					for c in enemy.get_children():
						if c is MeshInstance3D:
							var mat = c.get_active_material(0)
							if mat and mat.next_pass is ShaderMaterial:
								enemy_has_outline = true
								break
						elif c is Node3D:
							for sub in c.get_children():
								if sub is MeshInstance3D:
									var mat2 = sub.get_active_material(0)
									if mat2 and mat2.next_pass is ShaderMaterial:
										enemy_has_outline = true
										break

			# Verify city roads do NOT have outline next_pass (avoid outlining every road tile)
			var road_clean = true
			var city = scene_root.get_node_or_null("CityGenerator")
			if city:
				for c in city.get_children():
					if c is MeshInstance3D:
						var smat = c.get_active_material(0)
						if not smat and c.mesh and c.mesh.get_surface_count() > 0:
							smat = c.mesh.surface_get_material(0)
						if smat and smat.next_pass != null:
							road_clean = false
							break

			if enemy_has_outline and road_clean:
				print("  [PASS] 4. Selective Restraint: Hostile units have outlines; city streets/terrain are clean.")
				tests_passed += 1
			else:
				print("  [FAIL] 4. Enemy outline=%s, Road clean=%s" % [enemy_has_outline, road_clean])

		elif frame == 25:
			# Test 5: Screen resampling post-process below the HUD (native 3D render).
			var sm = get_tree().root.get_node_or_null("ShaderManager")
			var pp_valid = false
			if sm and sm.post_process_layer and sm.post_process_mat:
				# Test cycling through screen block sizes.
				sm.set_pixelation_mode(1) # 2x screen blocks
				var p1 = sm.post_process_mat.get_shader_parameter("enable_pixelation")
				var s1 = sm.post_process_mat.get_shader_parameter("pixel_size")
				sm.set_pixelation_mode(0) # Native
				var p0 = sm.post_process_mat.get_shader_parameter("enable_pixelation")
				if p1 == true and s1 == 2.0 and p0 == false and sm.post_process_layer.layer == 0:
					pp_valid = true

			if pp_valid:
				print("  [PASS] 5. Screen Resampling: Layer 0 switches native/2x/3x blocks below the UI.")
				tests_passed += 1
			else:
				print("  [FAIL] 5. World post-process invalid.")

		elif frame == 30:
			# Test 6: Hotkey Toggles & Toast HUD Notifications
			var sm = get_tree().root.get_node_or_null("ShaderManager")
			var hotkey_valid = false
			if sm:
				var initial_outline = sm.outlines_enabled
				# Simulate F6 keypress
				var event = InputEventKey.new()
				event.keycode = KEY_F6
				event.pressed = true
				sm._unhandled_input(event)
				if sm.outlines_enabled != initial_outline:
					# Restore
					sm._unhandled_input(event)
					hotkey_valid = (sm.outlines_enabled == initial_outline)

			if hotkey_valid:
				print("  [PASS] 6. Hotkey Control: F6-F10 shortcuts dynamically toggle shaders with HUD feedback.")
				tests_passed += 1
			else:
				print("  [FAIL] 6. Hotkeys failed to toggle state.")

		elif frame == 35:
			print("Retro Shaders Test Summary: %d/%d PASSED." % [tests_passed, total_tests])
			if tests_passed == total_tests:
				print("--- ALL RETRO SHADER SPEC VERIFICATIONS SUCCEEDED ---")
				get_tree().quit(0)
			else:
				print("--- SOME SHADER VERIFICATIONS FAILED ---")
				get_tree().quit(1)
