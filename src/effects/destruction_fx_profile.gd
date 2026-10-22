class_name DestructionFXProfile
extends RefCounted

## DestructionFXProfile — Authoritative specifications for vehicle & airframe destruction.
## Covers visual size, flash duration, fireball expansion, burning fragment count/speed,
## segmented smoke trail density, surface contact dust, wreckage, audio, and light budgets.

const PROFILES: Dictionary = {
	"light_ground": {
		"id": "light_ground",
		"fireball_size": 1.4,
		"flash_core_color": Color(1.0, 0.90, 0.64), # #FFE6A3
		"flash_edge_color": Color(1.0, 0.61, 0.25), # #FF9B3F
		"flash_duration": 0.06,
		"fragment_count": 4,
		"fragment_speed_min": 13.0,
		"fragment_speed_max": 20.0,
		"fragment_gravity": 18.0,
		"fragment_lifetime": 0.55,
		"smoke_puff_spacing": 0.28,
		"smoke_puff_size": 0.45,
		"smoke_puff_lifetime": 0.95,
		"contact_dust_enabled": true,
		"has_wreck": false,
		"wreck_lifetime": 0.0,
		"sound_name": "explosion",
		"camera_trauma": 0.25,
		"real_light_energy": 2.8,
		"real_light_radius": 8.0,
		"real_light_duration": 0.10,
		"real_light_priority": 1
	},
	"heavy_ground": {
		"id": "heavy_ground",
		"fireball_size": 2.2,
		"flash_core_color": Color(1.0, 0.92, 0.68),
		"flash_edge_color": Color(1.0, 0.55, 0.18),
		"flash_duration": 0.08,
		"fragment_count": 6,
		"fragment_speed_min": 15.0,
		"fragment_speed_max": 24.0,
		"fragment_gravity": 19.0,
		"fragment_lifetime": 0.70,
		"smoke_puff_spacing": 0.32,
		"smoke_puff_size": 0.65,
		"smoke_puff_lifetime": 1.25,
		"contact_dust_enabled": true,
		"has_wreck": true,
		"wreck_lifetime": 2.5,
		"sound_name": "explosion",
		"camera_trauma": 0.45,
		"real_light_energy": 3.6,
		"real_light_radius": 11.0,
		"real_light_duration": 0.14,
		"real_light_priority": 2
	},
	"drone": {
		"id": "drone",
		"fireball_size": 1.1,
		"flash_core_color": Color(1.0, 0.90, 0.64),
		"flash_edge_color": Color(1.0, 0.61, 0.25),
		"flash_duration": 0.05,
		"fragment_count": 3,
		"fragment_speed_min": 11.0,
		"fragment_speed_max": 17.0,
		"fragment_gravity": 16.0,
		"fragment_lifetime": 0.45,
		"smoke_puff_spacing": 0.25,
		"smoke_puff_size": 0.35,
		"smoke_puff_lifetime": 0.80,
		"contact_dust_enabled": false,
		"has_wreck": false,
		"wreck_lifetime": 0.0,
		"sound_name": "explosion",
		"camera_trauma": 0.20,
		"real_light_energy": 2.2,
		"real_light_radius": 6.0,
		"real_light_duration": 0.08,
		"real_light_priority": 1
	},
	"aircraft": {
		"id": "aircraft",
		"fireball_size": 1.8,
		"flash_core_color": Color(1.0, 0.92, 0.68),
		"flash_edge_color": Color(1.0, 0.58, 0.22),
		"flash_duration": 0.07,
		"fragment_count": 5,
		"fragment_speed_min": 14.0,
		"fragment_speed_max": 22.0,
		"fragment_gravity": 18.0,
		"fragment_lifetime": 0.65,
		"smoke_puff_spacing": 0.30,
		"smoke_puff_size": 0.55,
		"smoke_puff_lifetime": 1.10,
		"contact_dust_enabled": true,
		"has_wreck": true,
		"wreck_lifetime": 2.0,
		"sound_name": "explosion",
		"camera_trauma": 0.35,
		"real_light_energy": 3.2,
		"real_light_radius": 9.5,
		"real_light_duration": 0.12,
		"real_light_priority": 2
	},
	"boss": {
		"id": "boss",
		"fireball_size": 3.2,
		"flash_core_color": Color(1.0, 0.95, 0.75),
		"flash_edge_color": Color(1.0, 0.50, 0.15),
		"flash_duration": 0.10,
		"fragment_count": 8,
		"fragment_speed_min": 18.0,
		"fragment_speed_max": 30.0,
		"fragment_gravity": 20.0,
		"fragment_lifetime": 0.95,
		"smoke_puff_spacing": 0.35,
		"smoke_puff_size": 0.85,
		"smoke_puff_lifetime": 1.50,
		"contact_dust_enabled": true,
		"has_wreck": true,
		"wreck_lifetime": 3.5,
		"sound_name": "explosion_heavy",
		"camera_trauma": 0.70,
		"real_light_energy": 4.5,
		"real_light_radius": 14.0,
		"real_light_duration": 0.20,
		"real_light_priority": 3
	},
	"player": {
		"id": "player",
		"fireball_size": 2.6,
		"flash_core_color": Color(1.0, 0.94, 0.72),
		"flash_edge_color": Color(1.0, 0.52, 0.16),
		"flash_duration": 0.09,
		"fragment_count": 7,
		"fragment_speed_min": 16.0,
		"fragment_speed_max": 27.0,
		"fragment_gravity": 19.0,
		"fragment_lifetime": 0.85,
		"smoke_puff_spacing": 0.30,
		"smoke_puff_size": 0.70,
		"smoke_puff_lifetime": 1.35,
		"contact_dust_enabled": true,
		"has_wreck": true,
		"wreck_lifetime": 3.0,
		"sound_name": "explosion_heavy",
		"camera_trauma": 1.0,
		"real_light_energy": 4.2,
		"real_light_radius": 13.0,
		"real_light_duration": 0.18,
		"real_light_priority": 3 # Reserved hero slot
	},
	"building": {
		"id": "building",
		"fireball_size": 2.4,
		"flash_core_color": Color(1.0, 0.88, 0.60),
		"flash_edge_color": Color(0.9, 0.50, 0.20),
		"flash_duration": 0.07,
		"fragment_count": 5,
		"fragment_speed_min": 12.0,
		"fragment_speed_max": 20.0,
		"fragment_gravity": 22.0,
		"fragment_lifetime": 0.60,
		"smoke_puff_spacing": 0.35,
		"smoke_puff_size": 0.75,
		"smoke_puff_lifetime": 1.40,
		"contact_dust_enabled": true,
		"has_wreck": false,
		"wreck_lifetime": 0.0,
		"sound_name": "explosion",
		"camera_trauma": 0.35,
		"real_light_energy": 3.0,
		"real_light_radius": 10.0,
		"real_light_duration": 0.12,
		"real_light_priority": 1
	}
}

static func get_profile(profile_id: String) -> Dictionary:
	if PROFILES.has(profile_id):
		return PROFILES[profile_id]
	return PROFILES["light_ground"]

static func get_profile_for_entity(entity: Node) -> Dictionary:
	if not is_instance_valid(entity):
		return PROFILES["light_ground"]

	if entity.is_in_group("player"):
		return PROFILES["player"]

	if entity.is_in_group("bosses"):
		return PROFILES["boss"]

	if entity.is_in_group("buildings"):
		return PROFILES["building"]

	# Resolve from explicit enemy data
	var var_id: String = ""
	if "variant_id" in entity and not str(entity.variant_id).is_empty():
		var_id = str(entity.variant_id)
	elif entity.has_meta("variant_id"):
		var_id = str(entity.get_meta("variant_id"))

	if not var_id.is_empty():
		var v_data: Dictionary = EnemyData.VARIANTS.get(var_id, {})
		var family: String = v_data.get("family", "")
		var is_heavy: bool = v_data.get("is_heavy", false)

		if family == "air":
			return PROFILES["aircraft"] if is_heavy else PROFILES["drone"]
		elif family == "ground":
			return PROFILES["heavy_ground"] if is_heavy else PROFILES["light_ground"]

	# Fallback checks
	if entity.is_in_group("enemies"):
		if "is_air_target" in entity and entity.is_air_target:
			return PROFILES["aircraft"]
		return PROFILES["light_ground"]

	return PROFILES["light_ground"]
