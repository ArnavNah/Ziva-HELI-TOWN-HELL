class_name CargoSpecs
extends RefCounted

## CargoSpecs — Authoritative cargo types, risk factors, and contract pricing formula (Page 16).

const COMMODITIES: Dictionary = {
	"medical": {
		"name": "Medical Supplies",
		"base_value": 150,
		"risk_factor": 1.05
	},
	"ammunition": {
		"name": "Ammunition",
		"base_value": 170,
		"risk_factor": 1.12,
		"replenish_flare": true
	},
	"fuel": {
		"name": "Aviation Fuel",
		"base_value": 160,
		"risk_factor": 1.16
	},
	"electronics": {
		"name": "Electronics",
		"base_value": 215,
		"risk_factor": 1.08
	},
	"parts": {
		"name": "Machine Parts",
		"base_value": 185,
		"risk_factor": 1.04
	},
	"military": {
		"name": "Military Supplies",
		"base_value": 245,
		"risk_factor": 1.20
	}
}

static func calculate_contract_price(commodity_key: String, distance: float, difficulty_mult: float = 1.0) -> Dictionary:
	if not COMMODITIES.has(commodity_key):
		commodity_key = "medical"
	var c = COMMODITIES[commodity_key]
	var base_val: float = float(c["base_value"])
	var risk: float = float(c["risk_factor"])

	# Formula: base * risk * (1 + min(1.15, distance / 900)) * difficulty_mult
	var distance_factor = 1.0 + minf(1.15, distance / 900.0)
	var raw_price = base_val * risk * distance_factor * difficulty_mult
	
	# Round to nearest 10 credits (Page 16)
	var secured_base = int(round(raw_price / 10.0) * 10.0)

	# Speed bonus: ~25% rounded to nearest 5
	var speed_bonus = int(round((float(secured_base) * 0.25) / 5.0) * 5.0)

	# Time limit: greater of 42s or round(distance / 42 + 24)
	var time_limit = maxf(42.0, round(distance / 42.0 + 24.0))

	return {
		"commodity": c["name"],
		"base_price": secured_base,
		"speed_bonus": speed_bonus,
		"time_limit": time_limit,
		"sam_risk_bonus": 80
	}
