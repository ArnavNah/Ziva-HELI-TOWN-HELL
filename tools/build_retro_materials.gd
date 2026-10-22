extends SceneTree

func _init() -> void:
	print("--- Building Modern-Retro StandardMaterial3D Resources ---")
	var out_dir := "res://resources/materials/modern_retro"
	DirAccess.make_dir_recursive_absolute("res://resources/materials/modern_retro")
	
	var mat_defs := [
		{
			"name": "mat_brick_warm",
			"tex": "res://assets/environment/retro_textures/brick_warm_128.png",
			"roughness": 0.95,
			"metallic": 0.0,
			"specular": 0.15,
			"repeat": true,
			"transparency": BaseMaterial3D.TRANSPARENCY_DISABLED,
			"cull": BaseMaterial3D.CULL_BACK
		},
		{
			"name": "mat_plaster_pale",
			"tex": "res://assets/environment/retro_textures/plaster_pale_128.png",
			"roughness": 0.95,
			"metallic": 0.0,
			"specular": 0.15,
			"repeat": true,
			"transparency": BaseMaterial3D.TRANSPARENCY_DISABLED,
			"cull": BaseMaterial3D.CULL_BACK
		},
		{
			"name": "mat_asphalt_road",
			"tex": "res://assets/environment/retro_textures/asphalt_road_256.png",
			"roughness": 0.96,
			"metallic": 0.0,
			"specular": 0.12,
			"repeat": true,
			"transparency": BaseMaterial3D.TRANSPARENCY_DISABLED,
			"cull": BaseMaterial3D.CULL_BACK
		},
		{
			"name": "mat_pavement_sidewalk",
			"tex": "res://assets/environment/retro_textures/pavement_sidewalk_128.png",
			"roughness": 0.95,
			"metallic": 0.0,
			"specular": 0.15,
			"repeat": true,
			"transparency": BaseMaterial3D.TRANSPARENCY_DISABLED,
			"cull": BaseMaterial3D.CULL_BACK
		},
		{
			"name": "mat_grass_olive",
			"tex": "res://assets/environment/retro_textures/grass_olive_128.png",
			"roughness": 0.98,
			"metallic": 0.0,
			"specular": 0.08,
			"repeat": true,
			"transparency": BaseMaterial3D.TRANSPARENCY_DISABLED,
			"cull": BaseMaterial3D.CULL_BACK
		},
		{
			"name": "mat_soil_rich",
			"tex": "res://assets/environment/retro_textures/soil_rich_128.png",
			"roughness": 0.98,
			"metallic": 0.0,
			"specular": 0.08,
			"repeat": true,
			"transparency": BaseMaterial3D.TRANSPARENCY_DISABLED,
			"cull": BaseMaterial3D.CULL_BACK
		},
		{
			"name": "mat_grass_soil_blend",
			"tex": "res://assets/environment/retro_textures/grass_soil_blend_256.png",
			"roughness": 0.98,
			"metallic": 0.0,
			"specular": 0.08,
			"repeat": true,
			"transparency": BaseMaterial3D.TRANSPARENCY_DISABLED,
			"cull": BaseMaterial3D.CULL_BACK
		},
		{
			"name": "mat_crate_wood",
			"tex": "res://assets/environment/retro_textures/crate_wood_128.png",
			"roughness": 0.92,
			"metallic": 0.0,
			"specular": 0.15,
			"repeat": false,
			"transparency": BaseMaterial3D.TRANSPARENCY_DISABLED,
			"cull": BaseMaterial3D.CULL_BACK
		},
		{
			"name": "mat_barrel_metal",
			"tex": "res://assets/environment/retro_textures/barrel_metal_128.png",
			"roughness": 0.88,
			"metallic": 0.0,
			"specular": 0.20,
			"repeat": false,
			"transparency": BaseMaterial3D.TRANSPARENCY_DISABLED,
			"cull": BaseMaterial3D.CULL_BACK
		},
		{
			"name": "mat_debris_fracture",
			"tex": "res://assets/environment/retro_textures/debris_fracture_128.png",
			"roughness": 0.98,
			"metallic": 0.0,
			"specular": 0.08,
			"repeat": true,
			"transparency": BaseMaterial3D.TRANSPARENCY_DISABLED,
			"cull": BaseMaterial3D.CULL_BACK
		},
		{
			"name": "mat_tree_bark",
			"tex": "res://assets/environment/retro_textures/tree_bark_128.png",
			"roughness": 0.96,
			"metallic": 0.0,
			"specular": 0.10,
			"repeat": true,
			"transparency": BaseMaterial3D.TRANSPARENCY_DISABLED,
			"cull": BaseMaterial3D.CULL_BACK
		},
		{
			"name": "mat_tree_foliage",
			"tex": "res://assets/environment/retro_textures/tree_foliage_128.png",
			"roughness": 0.95,
			"metallic": 0.0,
			"specular": 0.08,
			"repeat": false,
			"transparency": BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,
			"alpha_scissor_threshold": 0.5,
			"cull": BaseMaterial3D.CULL_DISABLED
		},
		{
			"name": "mat_building_window",
			"tex": "res://assets/environment/retro_textures/building_window_128.png",
			"roughness": 0.85,
			"metallic": 0.0,
			"specular": 0.25,
			"repeat": true,
			"transparency": BaseMaterial3D.TRANSPARENCY_DISABLED,
			"cull": BaseMaterial3D.CULL_BACK
		}
	]
	
	for d in mat_defs:
		var mat := StandardMaterial3D.new()
		mat.resource_name = d["name"]
		
		if ResourceLoader.exists(d["tex"]):
			mat.albedo_texture = load(d["tex"])
		else:
			push_error("Missing texture: " + d["tex"])
			
		mat.roughness = d["roughness"]
		mat.metallic = d["metallic"]
		mat.metallic_specular = d["specular"]
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		mat.texture_repeat = d["repeat"]
		mat.transparency = d["transparency"]
		if d.has("alpha_scissor_threshold"):
			mat.alpha_scissor_threshold = d["alpha_scissor_threshold"]
		mat.cull_mode = d["cull"]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		
		var path: String = out_dir + "/" + str(d["name"]) + ".tres"
		var err := ResourceSaver.save(mat, path)
		if err == OK:
			print("Created material: ", path)
		else:
			print("Error creating material ", path, ": ", err)
			
	print("--- All 13 Modern-Retro Materials Built Successfully ---")
	quit(0)
