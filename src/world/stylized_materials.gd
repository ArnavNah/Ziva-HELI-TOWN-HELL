class_name StylizedMaterials
extends RefCounted

## StylizedMaterials — Centralized material factory for Megabonk chunky pixel environment.
## High roughness (0.95), metallic 0.0, filter_nearest_mipmap, restrained banded lighting.

const SURFACE = preload("res://src/shaders/field_surface.gdshader")
const TERRAIN = preload("res://src/shaders/meadow.gdshader")
const ATLAS_SHADER = preload("res://src/shaders/town_atlas.gdshader")
static var town_texture: Texture2D = null
const TILE_METERS := 8.0
static var atlas_cache: Dictionary = {}

static func town_atlas(damaged: bool = false, tile: int = -1, world_mapping: bool = false, wind: float = 0.0) -> ShaderMaterial:
	var key := str(damaged) + ":" + str(tile) + ":" + str(world_mapping) + ":" + str(wind)
	if atlas_cache.has(key):
		return atlas_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = ATLAS_SHADER
	mat.resource_name = "TownPaint_" + key
	if not town_texture and ResourceLoader.exists("res://assets/environment/painted/town_atlas.png"):
		town_texture = load("res://assets/environment/painted/town_atlas.png")
	mat.set_shader_parameter("albedo_texture", town_texture)
	mat.set_shader_parameter("damage_amount", 1.0 if damaged else 0.0)
	mat.set_shader_parameter("fixed_tile", tile)
	mat.set_shader_parameter("world_mapping", world_mapping)
	mat.set_shader_parameter("tile_meters", TILE_METERS)
	mat.set_shader_parameter("wind_strength", wind)
	atlas_cache[key] = mat
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("ShaderManager"):
		tree.root.get_node("ShaderManager").register_world_material(mat)
	return mat

static func _get_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	return null

static var tex_grass: Texture2D = _get_tex("res://assets/environment/textures/tile_grass_olive.png")
static var tex_road: Texture2D = _get_tex("res://assets/environment/textures/tile_road_asphalt.png")
static var tex_sidewalk: Texture2D = _get_tex("res://assets/environment/textures/tile_sidewalk_paving.png")
static var tex_brick: Texture2D = _get_tex("res://assets/environment/textures/tile_wall_brick.png")
static var tex_concrete: Texture2D = _get_tex("res://assets/environment/textures/tile_wall_concrete.png")
static var tex_industrial: Texture2D = _get_tex("res://assets/environment/textures/tile_wall_industrial.png")
static var tex_roof: Texture2D = _get_tex("res://assets/environment/textures/tile_roof_slate.png")
static var tex_helipad: Texture2D = _get_tex("res://assets/environment/textures/tile_helipad.png")
static var tex_windows: Texture2D = _get_tex("res://assets/environment/textures/tile_window_grid.png")

static var surface_cache: Dictionary = {}
static var textured_cache: Dictionary = {}
static var terrain_material: ShaderMaterial
static var road_material: ShaderMaterial
static var sidewalk_material: ShaderMaterial
static var helipad_material: ShaderMaterial
static var roof_material: ShaderMaterial

static func surface(color: Color, variation: float = 0.035, wind: float = 0.0) -> ShaderMaterial:
	var key := str(color) + ":" + str(variation) + ":" + str(wind)
	if surface_cache.has(key):
		return surface_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = SURFACE
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("variation", variation)
	mat.set_shader_parameter("wind_strength", wind)
	mat.set_shader_parameter("use_texture", false)
	surface_cache[key] = mat
	return mat

static func textured(texture: Texture2D, tint: Color = Color.WHITE, uv_scale: Vector2 = Vector2.ONE, use_vertex_tint: bool = true) -> ShaderMaterial:
	if not texture:
		return surface(tint)
	var key := str(texture.get_instance_id()) + ":" + str(tint) + ":" + str(uv_scale) + ":" + str(use_vertex_tint)
	if textured_cache.has(key):
		return textured_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = SURFACE
	mat.set_shader_parameter("albedo_texture", texture)
	mat.set_shader_parameter("base_color", tint)
	mat.set_shader_parameter("uv_scale", uv_scale)
	mat.set_shader_parameter("use_texture", true)
	mat.set_shader_parameter("use_vertex_tint", use_vertex_tint)
	textured_cache[key] = mat
	return mat

static func road() -> ShaderMaterial:
	if road_material:
		return road_material
	road_material = town_atlas(false, 11, true)
	return road_material

static func sidewalk() -> ShaderMaterial:
	if sidewalk_material:
		return sidewalk_material
	sidewalk_material = town_atlas(false, 13, true)
	return sidewalk_material

static func helipad() -> ShaderMaterial:
	if helipad_material:
		return helipad_material
	helipad_material = textured(tex_helipad, Color.WHITE, Vector2(1.0, 1.0), false)
	return helipad_material

static func roof() -> ShaderMaterial:
	if roof_material:
		return roof_material
	roof_material = town_atlas(false, 2, true)
	return roof_material

static func facade(tex_type: String = "concrete", tint: Color = Color.WHITE) -> ShaderMaterial:
	var tex := tex_concrete
	match tex_type:
		"brick": tex = tex_brick
		"concrete": tex = tex_concrete
		"industrial": tex = tex_industrial
		"roof": tex = tex_roof
		"windows": tex = tex_windows
	return textured(tex, tint, Vector2.ONE, true)

static func terrain() -> ShaderMaterial:
	if terrain_material:
		return terrain_material
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN
	mat.set_shader_parameter("grass_texture", load("res://assets/environment/painted/grass.png"))
	mat.set_shader_parameter("uv_scale", 1.0 / TILE_METERS)
	mat.set_shader_parameter("grass_deep", Color(0.22, 0.31, 0.14, 1.0))
	mat.set_shader_parameter("grass_mid", Color(0.31, 0.41, 0.20, 1.0))
	mat.set_shader_parameter("grass_bright", Color(0.40, 0.49, 0.25, 1.0))
	mat.set_shader_parameter("grass_warm", Color(0.47, 0.52, 0.29, 1.0))
	terrain_material = mat
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("ShaderManager"):
		tree.root.get_node("ShaderManager").register_world_material(mat)
	return mat
