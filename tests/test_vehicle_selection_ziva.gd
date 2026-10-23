extends Node

func test_aircraft_specs_truth() -> void:
	var specs_script = load("res://data/aircraft_specs.gd")
	assert(specs_script != null, "aircraft_specs.gd must exist")
	
	var apache = specs_script.get_specs("apache")
	assert(apache.speed == 36.0, "Apache baseline speed must be 36.0")
	assert(apache.hull == 100.0, "Apache baseline hull must be 100")
	assert(apache.fuel == 100.0, "Apache baseline fuel must be 100")
	assert(apache.get("yaw_mult", 1.0) == 1.0, "Apache baseline yaw_mult must be 1.0")
	
	var nighthawk = specs_script.get_specs("nighthawk")
	assert(nighthawk.speed == 41.4, "Nighthawk baseline speed must be 41.4")
	assert(nighthawk.hull == 85.0, "Nighthawk baseline hull must be 85")
	assert(nighthawk.fuel == 90.0, "Nighthawk baseline fuel must be 90")
	assert(nighthawk.yaw_mult == 1.20, "Nighthawk baseline yaw_mult must be 1.20")
	
	var warlock = specs_script.get_specs("warlock")
	assert(warlock.speed == 31.7, "Warlock baseline speed must be 31.7")
	assert(warlock.hull == 130.0, "Warlock baseline hull must be 130")
	assert(warlock.fuel == 120.0, "Warlock baseline fuel must be 120")
	assert(warlock.yaw_mult == 0.85, "Warlock baseline yaw_mult must be 0.85")

func test_vehicle_selection_menu_structure() -> void:
	var menu_scene = load("res://scenes/ui/vehicle_selection_menu.tscn")
	assert(menu_scene != null, "VehicleSelectionMenu scene must exist")
	var menu = menu_scene.instantiate()
	assert(menu != null, "VehicleSelectionMenu must instantiate")
	
	add_child(menu)
	menu.visible = true
	
	# Verify essential nodes
	var stage_container = menu.find_child("StageContainer", true, false)
	assert(stage_container != null, "StageContainer must exist for 3D hangar showroom")
	
	var turntable = menu.find_child("Turntable", true, false)
	assert(turntable != null, "Turntable root must exist in 3D showroom")
	
	var heli = menu.find_child("ShowcaseHelicopter", true, false)
	assert(heli != null, "Showcase helicopter model instance must exist")
	
	var deploy_btn = menu.find_child("DeployBtn", true, false)
	assert(deploy_btn != null, "Deploy button must exist")
	
	var back_btn = menu.find_child("BackBtn", true, false)
	assert(back_btn != null, "Back button must exist")
	
	var armory_btn = menu.find_child("ArmoryBtn", true, false)
	assert(armory_btn != null, "Upgrade hangar button must exist")
	
	menu.queue_free()
