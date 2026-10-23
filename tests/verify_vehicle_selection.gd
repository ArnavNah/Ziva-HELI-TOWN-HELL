extends SceneTree

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)
	print("PASS: " if condition else "FAIL: ", description)

func capture(path: String) -> Image:
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	frame.save_png(path)
	return frame

func run() -> void:
	print("=== BEGIN VEHICLE SELECTION MENU & STAGE VERIFICATION ===")

	# 1. Test MainMenu without Flight Academy button
	var main_menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(main_menu)
	current_scene = main_menu

	var academy_btn = main_menu.get_node_or_null("VBoxContainer/AcademyBtn")
	check(academy_btn == null or not academy_btn.visible, "Flight Academy button removed/hidden from main menu")

	var veh_menu: VehicleSelectionMenu = main_menu.get_node_or_null("VehicleSelectionMenu")
	check(veh_menu != null, "VehicleSelectionMenu instance exists in MainMenu")

	# Test opening VehicleSelectionMenu from Start button
	main_menu._on_start_pressed()
	check(veh_menu.visible == true, "Selecting airframe opens dedicated VehicleSelectionMenu")

	# Check 3D showcase nodes
	var stage_vp = veh_menu.get_node_or_null("StageContainer/StageViewport")
	check(stage_vp != null, "3D Showcase SubViewport exists")
	var turntable = stage_vp.get_node_or_null("Turntable") if stage_vp else null
	check(turntable != null, "Turntable 3D rotating pedestal exists")
	var heli = turntable.get_node_or_null("ShowcaseHelicopter") if turntable else null
	check(heli != null, "Showcase helicopter 3D model exists on turntable")

	# Test 2: Select APACHE (Index 0)
	veh_menu.select_aircraft(0)
	check(veh_menu.aircraft_title.text == "AH-64 APACHE", "Apache designation loaded")
	check(veh_menu.speed_bar.value > 50.0, "Apache speed rating: truthful positive")
	check(veh_menu.hull_bar.value > 40.0, "Apache hull rating: truthful positive")

	# Test 3: Select NIGHTHAWK (Index 1)
	veh_menu.select_aircraft(1)
	check(veh_menu.aircraft_title.text == "RAH-66 NIGHTHAWK", "Nighthawk designation loaded")
	check(veh_menu.speed_bar.value > veh_menu.hull_bar.value, "Nighthawk speed exceeds hull rating")

	# Test 4: Select WARLOCK (Index 2)
	veh_menu.select_aircraft(2)
	check(veh_menu.aircraft_title.text == "MI-28 WARLOCK", "Warlock designation loaded")
	check(veh_menu.hull_bar.value > 50.0, "Warlock hull rating: fortified")
	check(veh_menu.firepower_bar.value >= 0.0, "Warlock firepower rating: valid")

	# Test 5: Back navigation restores MainMenu focus
	veh_menu._on_back_pressed()
	check(veh_menu.visible == false, "Back button returns to MainMenu")

	# Visual Captures
	if DisplayServer.get_name() != "headless":
		await create_timer(0.4).timeout
		await capture("res://artifacts/main_menu_new.png")

		# Capture Apache showcase stage
		veh_menu.visible = true
		veh_menu.select_aircraft(0)
		await create_timer(0.4).timeout
		await capture("res://artifacts/vehicle_select_apache.png")

		# Capture Nighthawk showcase stage
		veh_menu.select_aircraft(1)
		await create_timer(0.4).timeout
		await capture("res://artifacts/vehicle_select_nighthawk.png")

		# Capture Warlock showcase stage
		veh_menu.select_aircraft(2)
		await create_timer(0.4).timeout
		await capture("res://artifacts/vehicle_select_warlock.png")

	print("\nVEHICLE SELECTION VERIFICATION: %d/%d CHECKS PASSED." % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
