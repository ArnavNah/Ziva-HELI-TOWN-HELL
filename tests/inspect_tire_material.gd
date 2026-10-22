@tool
extends SceneTree

func _init() -> void:
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	gltf.append_from_file("res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Tire.glb", state)
	var root = gltf.generate_scene(state)
	var mi: MeshInstance3D = null
	for c in root.get_children():
		if c is MeshInstance3D:
			mi = c
			break
	var mat = mi.mesh.surface_get_material(0) as StandardMaterial3D
	if mat:
		print("Tire Material Name:", mat.resource_name)
		print("Albedo Color:", mat.albedo_color)
		print("Albedo Texture:", mat.albedo_texture)
		if mat.albedo_texture:
			print("Albedo Tex Size:", mat.albedo_texture.get_width(), "x", mat.albedo_texture.get_height())
		print("Roughness Texture:", mat.roughness_texture)
		print("Normal Texture:", mat.normal_texture)
	quit()
