extends SceneTree

func _initialize() -> void:
	var p = load("res://assets/player/player.glb").instantiate()
	var body: MeshInstance3D = p.find_child("Helicopter_Body", true, false)
	var rotor: MeshInstance3D = p.find_child("Main_Rotor", true, false)
	if body:
		print("Body pos: ", body.position, " AABB: ", body.get_aabb())
	if rotor:
		print("Rotor pos: ", rotor.position, " AABB: ", rotor.get_aabb())
	quit(0)
