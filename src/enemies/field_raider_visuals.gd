extends RefCounted
## Air raider silhouettes assembled from shared low-poly primitives; a local seed varies liveries.
const Parts = preload("res://src/enemies/raider_visuals.gd")
const Materials = preload("res://src/world/stylized_materials.gd")

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
        "torpedo_vtol", "escort_fighter":
            Parts.build(enemy, role)
            return
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
