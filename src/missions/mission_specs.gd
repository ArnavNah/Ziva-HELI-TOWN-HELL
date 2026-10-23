class_name MissionSpecs
extends RefCounted

## MissionSpecs — Tactical operations, extraction contracts, rewards and eligibility.

const MISSIONS: Dictionary = {
	"rooftop_supply": {
		"title": "SKY CACHE / Rooftop Supply", "kind": "supply", "gate_wave": 2,
		"hold_time": 8.0, "time_limit": 100.0, "base_cr": 250, "base_xp": 25, "base_salvage": 3,
		"brief": "Clear hostiles within 30m and stabilize above the roof LZ. Cache guarantees shield and overdrive pickups."
	},
	"medevac": {
		"title": "MEDEVAC / Wounded Personnel", "kind": "extract", "visual": "medical",
		"passengers": 3, "hold_time": 4.0, "delivery_hold": 3.0, "time_limit": 150.0,
		"base_cr": 360, "base_xp": 20, "base_salvage": 3, "repair_reward": 12.0,
		"brief": "Recover the casualty team, then deliver them to the marked medical LZ."
	},
	"vip_extraction": {
		"title": "VIP / Priority Evacuation", "kind": "extract", "visual": "vip",
		"passengers": 1, "hold_time": 3.0, "delivery_hold": 4.0, "time_limit": 130.0,
		"base_cr": 420, "base_xp": 24, "base_salvage": 4, "gate_wave": 2,
		"brief": "Collect the marked officer and transfer them to the secure evacuation LZ."
	},
	"black_box_recovery": {
		"title": "BLACK BOX / Intelligence Recovery", "kind": "extract", "visual": "intel",
		"passengers": 0, "hold_time": 3.0, "delivery_hold": 3.0, "time_limit": 160.0,
		"base_cr": 330, "base_xp": 22, "base_salvage": 4,
		"brief": "Retrieve the flight recorder from the wreck and return it to the command LZ."
	},
	"sortie_extraction": {
		"title": "EXFIL / End Sortie", "kind": "sortie", "visual": "evac",
		"hold_time": 5.0, "base_cr": 0, "base_xp": 0, "base_salvage": 0,
		"gate_wave": 3, "manual_only": true,
		"brief": "Reach the marked LZ, stabilize your hover, then confirm extraction to bank the sortie."
	},
	"destroy_sam": {
		"time_limit": 45.0,
		"title": "Destroy SAM Battery",
		"base_cr": 300,
		"base_xp": 18,
		"base_salvage": 2,
		"bonus_desc": "Avoid SAM missile damage",
		"bonus_cr": 100,
		"bonus_salvage": 1
	},
	"destroy_radar": {
		"title": "Destroy Radar Installation",
		"base_cr": 350,
		"base_xp": 20,
		"base_salvage": 2,
		"bonus_desc": "Avoid SAM missile damage",
		"bonus_cr": 100,
		"bonus_salvage": 1
	},
	"cargo_run": {
		"title": "Tactical Cargo Run",
		"base_cr": 0, # Cargo delivery pays separately
		"base_xp": 12,
		"base_salvage": 2,
		"bonus_desc": "Score 10 kills while carrying cargo",
		"bonus_cr": 80,
		"bonus_salvage": 1
	},
	"high_value_target": {
		"title": "Eliminate High Value Target",
		"base_cr": 360,
		"base_xp": 24,
		"base_salvage": 3,
		"flare_reward": 1,
		"bonus_desc": "Neutralize target within 65s",
		"bonus_cr": 120,
		"bonus_salvage": 1
	},
	"clear_airspace": {
		"title": "Clear Airspace Corridor",
		"base_cr": 240,
		"base_xp": 20,
		"base_salvage": 2,
		"target_kills": 10,
		"radius": 140.0,
		"bonus_desc": "Finish operation above 50% hull",
		"bonus_cr": 75,
		"bonus_salvage": 1
	},
	"defend_beacon": {
		"title": "Defend Tactical Beacon",
		"base_cr": 320,
		"base_xp": 22,
		"base_salvage": 3,
		"repair_reward": 12.0,
		"hold_time": 25.0,
		"radius": 34.0,
		"bonus_desc": "Finish operation above 50% hull",
		"bonus_cr": 90,
		"bonus_salvage": 1
	},
	"escort_convoy": {
		"title": "Escort Supply Convoy",
		"base_cr": 340,
		"base_xp": 24,
		"base_salvage": 3,
		"repair_reward": 10.0,
		"hold_time": 26.0,
		"route_time": 42.0,
		"radius": 42.0,
		"bonus_desc": "Finish operation above 50% hull",
		"bonus_cr": 95,
		"bonus_salvage": 1
	},
	"rescue_crew": {
		"title": "Rescue Downed Crew",
		"kind": "extract", "visual": "crew", "passengers": 2,
		"delivery_hold": 3.0, "time_limit": 180.0,
		"base_cr": 300,
		"base_xp": 20,
		"base_salvage": 2,
		"repair_reward": 15.0,
		"hold_time": 4.0,
		"radius": 34.0,
		"bonus_desc": "Finish operation above 50% hull",
		"bonus_cr": 85,
		"bonus_salvage": 1
	},
	"bounty_leader": {
		"title": "Hunt Bounty Squadron Leader",
		"base_cr": 420,
		"base_xp": 28,
		"base_salvage": 5,
		"flare_reward": 1,
		"bonus_desc": "Neutralize leader within 75s",
		"bonus_cr": 150,
		"bonus_salvage": 2
	}
}
