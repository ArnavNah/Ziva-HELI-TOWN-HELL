extends SceneTree
var failures: Array[String] = []
var checks := 0
const ROLES := ["rocket_buggy", "flame_tank", "rail_crawler", "hunter_drone", "torpedo_vtol", "escort_fighter"]

func _init() -> void:
    call_deferred("run")

func check(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        failures.append(description)
        push_error(description)

func clear_units() -> void:
    for unit in get_nodes_in_group("enemies"):
        unit.queue_free()
    for shot in get_nodes_in_group("enemy_projectiles"):
        shot.queue_free()
    await physics_frame
    await physics_frame

func run() -> void:
    seed(6729)
    var game = load("res://scenes/main_game.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    var director := root.get_node("CombatDirector")
    director.is_wave_active = false
    var player = game.get_node("PlayerHelicopter")
    player.is_invulnerable = true
    player.set_physics_process(false)
    player.position = Vector3(0, 14, 0)
    var spawner = game.get_node("EnemySpawner")
    spawner.encounter_rng.seed = 881
    await physics_frame
    var city = game.get_node("CityGenerator")
    var dressing = city.get_node("FieldDressing")
    var knoll_count := 0
    var pond_count := 0
    for child in dressing.get_children():
        if child is StaticBody3D:
            knoll_count += 1
            check(city.terrain_lots.has(child.position), "Raised terrain stays inside natural park lots")
            var ray := PhysicsRayQueryParameters3D.create(child.global_position + Vector3.UP * 15, child.global_position, 2)
            var hit = child.get_world_3d().direct_space_state.intersect_ray(ray)
            check(not hit.is_empty() and hit.position.y > 2.0, "Knoll collision matches raised landscape")
            if not hit.is_empty():
                var offset_ray := PhysicsRayQueryParameters3D.create(child.global_position + Vector3(1, 15, 0), child.global_position + Vector3.RIGHT, 2)
                var offset_hit = child.get_world_3d().direct_space_state.intersect_ray(offset_ray)
                check(not offset_hit.is_empty() and absf(offset_hit.position.y - hit.position.y) < 0.05, "Plateau top has level collision across its center")
        if child.name.begins_with("MeadowPond"):
            pond_count += 1
            check(city.terrain_lots.has(child.position - Vector3.UP * 0.18), "Ponds stay off sports courts and fountain plazas")
    check(knoll_count > 10 and pond_count > 0, "World contains raised knolls and animated ponds")
    check(dressing.get_node("BroadleafCrowns").get_child_count() > 1, "Broadleaf trees are batched across cullable sectors")
    check(dressing.get_node("GrassTufts").get_child_count() > 1, "Grass is batched across cullable sectors")
    var camera = player.get_node("PlayerCamera")
    camera.init_camera(player)
    camera.update_camera(0.016)
    var view_angle := rad_to_deg(atan2(camera.global_position.y - camera.current_look_target.y, Vector2(camera.global_position.x - camera.current_look_target.x, camera.global_position.z - camera.current_look_target.z).length()))
    check(camera.base_distance <= 38 and camera.base_height <= 36 and view_angle > 32 and view_angle < 48, "Camera provides close oblique helicopter framing")
    check(not camera.is_position_behind(player.global_position) and not camera.is_position_behind(Vector3(0, 0, -45)), "Aircraft and forward ground targets remain in front of camera")
    for role in ROLES:
        var altitude := 0.1 if EnemyData.VARIANTS[role].family == "ground" else 24.0
        var unit = spawner.spawn_enemy_type(role, Vector3(0, altitude, -32))
        check(unit != null and unit.variant_id == role, "New role instantiates: " + role)
        check(unit.get_node("Visuals").get_child_count() >= 3 and unit.has_node("Turret"), "Role has recognizable procedural geometry: " + role)
        unit.fire_timer = 0.0
        var start: Vector3 = unit.global_position
        await physics_frame
        await physics_frame
        if role == "rail_crawler":
            check(unit.charge_timer > 0 and is_instance_valid(unit.charge_line), "Rail crawler warns before firing")
            check(director.current_heavy_attackers.has(unit), "Rail telegraph holds a heavy attack slot")
            var lock: Vector3 = unit.charge_target
            player.position.x = 8.0
            await create_timer(0.25).timeout
            check(unit.charge_target == lock, "Rail warning retains a dodgeable locked aim point")
            player.position.x = 0.0
            await create_timer(0.85).timeout
            check(unit.charge_timer <= 0 and not director.current_heavy_attackers.has(unit), "Rail fires and releases its slot after warning")
        else:
            check(get_nodes_in_group("enemy_projectiles").size() > 0, "Role fires its weapon: " + role)
            if role == "torpedo_vtol":
                var homing := false
                for shot in get_nodes_in_group("enemy_projectiles"):
                    homing = homing or shot.is_homing
                check(homing, "Torpedo VTOL fires guided missiles")
            if role == "flame_tank":
                var incendiary := false
                for shot in get_nodes_in_group("enemy_projectiles"):
                    incendiary = incendiary or shot.damage_data.burn_chance > 0
                check(incendiary, "Incendiary rounds carry burn data")
        await create_timer(0.1).timeout
        check(unit.global_position.distance_to(start) > 0.1, "Role moves under actual physics: " + role)
        await clear_units()
    # Normal wave selection must retain gates and caps despite the larger roster.
    director.current_wave = 2
    var counts := {}
    for i in range(50):
        var unit = spawner.spawn_wave_enemy(2)
        if unit:
            unit.set_physics_process(false)
            counts[unit.variant_id] = int(counts.get(unit.variant_id, 0)) + 1
            check(EnemyData.VARIANTS[unit.variant_id].gate_wave <= 2, "Wave gates protect early encounters")
    for key in counts:
        check(counts[key] <= EnemyData.VARIANTS[key].max_cap, "Procedural deployment respects variant cap: " + key)
    check(counts.has("hunter_drone") and counts.has("rocket_buggy"), "New air and ground roles appear through real wave selection")
    await clear_units()
    print("STRIKE MEADOW CHECKS: ", checks - failures.size(), "/", checks)
    quit(0 if failures.is_empty() else 1)
