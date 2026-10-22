class_name RetroMaterialLibrary
extends RefCounted

## RetroMaterialLibrary — Centralized material provider for the modern-retro 64px/m style.
## All materials are calibrated with:
## - Nearest filtering with mipmaps (TEXTURE_FILTER_NEAREST_WITH_MIPMAPS = 2)
## - Matte surfaces (roughness ~0.95, metallic 0.0, minimal specular)
## - Deliberately painted pixel clusters in 3-5 broad value groups
## - 64 texture pixels per metre (128x128 = 2m x 2m, 256x256 = 4m x 4m)

const MAT_DIR := "res://resources/materials/modern_retro/"

static var _cache: Dictionary = {}

static func get_material(mat_name: String) -> StandardMaterial3D:
	if _cache.has(mat_name):
		return _cache[mat_name]
	
	var path := MAT_DIR + mat_name + ".tres"
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is StandardMaterial3D:
			_cache[mat_name] = res
			return res
	
	# Fallback: create runtime material if file missing
	var fallback := StandardMaterial3D.new()
	fallback.resource_name = mat_name + "_fallback"
	fallback.roughness = 0.95
	fallback.metallic = 0.0
	fallback.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_cache[mat_name] = fallback
	return fallback

static func brick() -> StandardMaterial3D:
	return get_material("mat_brick_warm")

static func plaster() -> StandardMaterial3D:
	return get_material("mat_plaster_pale")

static func road() -> StandardMaterial3D:
	return get_material("mat_asphalt_road")

static func pavement() -> StandardMaterial3D:
	return get_material("mat_pavement_sidewalk")

static func grass() -> StandardMaterial3D:
	return get_material("mat_grass_olive")

static func soil() -> StandardMaterial3D:
	return get_material("mat_soil_rich")

static func grass_soil_blend() -> StandardMaterial3D:
	return get_material("mat_grass_soil_blend")

static func crate() -> StandardMaterial3D:
	return get_material("mat_crate_wood")

static func barrel() -> StandardMaterial3D:
	return get_material("mat_barrel_metal")

static func debris_fracture() -> StandardMaterial3D:
	return get_material("mat_debris_fracture")

static func tree_bark() -> StandardMaterial3D:
	return get_material("mat_tree_bark")

static func tree_foliage() -> StandardMaterial3D:
	return get_material("mat_tree_foliage")

static func building_window() -> StandardMaterial3D:
	return get_material("mat_building_window")

## Helper to calculate standard UV scale for a mesh with world dimensions [width, height] in meters
## base_tile_meters: 2.0 for 128x128 textures, 4.0 for 256x256 textures
static func get_calibrated_uv_scale(width_m: float, height_m: float, base_tile_meters: float = 2.0) -> Vector2:
	return Vector2(width_m / base_tile_meters, height_m / base_tile_meters)
