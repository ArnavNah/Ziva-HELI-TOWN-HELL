extends RefCounted
## Six silhouettes assembled from shared low-poly primitives; a local seed varies liveries.
const Parts = preload("res://src/enemies/raider_visuals.gd")
const Materials = preload("res://src/world/stylized_materials.gd")
const AzureSiegeTankScene: PackedScene = preload("res://scenes/enemies/azure_siege_tank_visuals.tscn")

static func build(enemy: Node3D, role: String, visual_seed: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = visual_seed
    var visual := Node3D.new()
    visual.name = "Visuals"
    enemy.add_child(visual)
    var palettes := [Color("82794e"), Color("536f61"), Color("b49b65"), Color("72728b")]
    var armor := Materials.surface(palettes[rng.randi_range(0, palettes.size() - 1)])
    var dark := Materials.surface(Color("25333d"))
    var stripe := Materials.surface(Color("e2ad43"))
    var red := Materials.surface(Color("b94c36"))
    var cyan := Materials.surface(Color("78c7cc"))
    var turret := Node3D.new()
    turret.name = "Turret"
    enemy.add_child(turret)
    match role:
        "rocket_buggy":
            Parts.box(visual, Vector3(2.4, 0.7, 4.2), Vector3(0, 0.8, 0), armor)
            Parts.box(visual, Vector3(1.8, 0.8, 1.3), Vector3(0, 1.5, -0.6), dark)
            for side in [-1.0, 1.0]:
                for axle in [-1.3, 1.3]:
                    Parts.wheel_mesh(visual, 0.6, 0.4, Vector3(side * 1.3, 0.6, axle), dark)
            turret.position = Vector3(0, 1.8, 0.9)
            for side in [-0.5, 0.5]:
                Parts.box(turret, Vector3(0.65, 0.55, 1.8), Vector3(side, 0, -0.3), red)
                Parts.box(turret, Vector3(0.45, 0.35, 0.1), Vector3(side, 0, -1.25), stripe)
        "rail_crawler":
            enemy.remove_child(visual)
            enemy.remove_child(turret)
            visual.queue_free()
            turret.queue_free()
            var rig = AzureSiegeTankScene.instantiate()
            var new_visuals = rig.get_node_or_null("Visuals")
            var new_turret = rig.get_node_or_null("Turret")
            if new_visuals and new_turret:
                rig.remove_child(new_visuals)
                rig.remove_child(new_turret)
                new_visuals.owner = null
                new_turret.owner = null
                enemy.add_child(new_visuals)
                enemy.add_child(new_turret)
                rig.queue_free()
        "flame_tank":
            Parts.box(visual, Vector3(3.2, 1.1, 5.8), Vector3(0, 0.95, 0), armor)
            for side in [-1.0, 1.0]:
                Parts.box(visual, Vector3(0.65, 0.9, 5.6), Vector3(side * 1.65, 0.6, 0), dark)
                Parts.box(visual, Vector3(0.7, 0.16, 5.4), Vector3(side * 1.65, 1.12, 0), stripe)
            turret.position = Vector3(0, 1.9, -0.4)
            Parts.box(turret, Vector3(1.9, 0.6, 1.9), Vector3.ZERO, armor)
            for side in [-0.65, 0.65]:
                Parts.cylinder(visual, 0.55, 1.7, Vector3(side, 1.9, 1.6), red)
            Parts.box(turret, Vector3(0.5, 0.4, 2.4), Vector3(0, 0.1, -1.4), red)
        "hunter_drone":
            Parts.box(visual, Vector3(1.6, 0.7, 2.0), Vector3(0, 0.7, 0), red)
            Parts.box(visual, Vector3(3.4, 0.15, 0.5), Vector3(0, 0.9, 0), dark)
            var rotor := Node3D.new()
            rotor.name = "AnimatedRotor"
            rotor.position.y = 1.1
            visual.add_child(rotor)
            Parts.box(rotor, Vector3(3.6, 0.07, 0.2), Vector3.ZERO, dark)
            Parts.box(rotor, Vector3(0.2, 0.07, 3.6), Vector3.ZERO, dark)
            turret.position = Vector3(0, 0.4, -0.8)
            Parts.box(turret, Vector3(0.3, 0.3, 0.9), Vector3(0, 0, -0.4), stripe)
        "torpedo_vtol":
            Parts.box(visual, Vector3(2.0, 1.3, 5.5), Vector3(0, 0.9, 0), armor)
            Parts.box(visual, Vector3(6.8, 0.2, 1.5), Vector3(0, 1.0, 0), dark)
            Parts.box(visual, Vector3(1.4, 0.5, 1.4), Vector3(0, 1.45, -1.5), cyan)
            for side in [-1.0, 1.0]:
                Parts.cylinder(visual, 1.15, 0.12, Vector3(side * 3.0, 1.25, 0), stripe)
                Parts.box(visual, Vector3(0.6, 0.6, 2.5), Vector3(side * 1.5, 0.45, 0), red)
            turret.position = Vector3(0, 0.4, -2.0)
            Parts.box(turret, Vector3(0.7, 0.5, 0.6), Vector3.ZERO, dark)
        "escort_fighter":
            Parts.box(visual, Vector3(1.1, 0.8, 5.0), Vector3(0, 0.6, 0), dark)
            Parts.box(visual, Vector3(7.0, 0.18, 1.3), Vector3(0, 0.7, 0.6), armor)
            Parts.box(visual, Vector3(2.8, 0.15, 0.8), Vector3(0, 0.85, 2.0), stripe)
            Parts.box(visual, Vector3(0.2, 1.1, 1.0), Vector3(0, 1.1, 1.9), stripe)
            turret.position = Vector3(0, 0.6, -1.6)
            for side in [-0.75, 0.75]:
                Parts.box(turret, Vector3(0.16, 0.16, 1.6), Vector3(side, 0, -0.5), red)
    # A top recognition stripe stays visible at tactical camera distance.
    Parts.box(visual, Vector3(0.25, 0.1, 1.2), Vector3(0.4, 1.7, 0), stripe)
