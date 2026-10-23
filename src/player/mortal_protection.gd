extends RefCounted
## Combat-time burst snapshot. Environmental crashes/fuel damage opt out at the caller.
const BURST_WINDOW := 0.20
const GRACE := 0.50
const REARM_DELAY := 15.0
var clock := 0.0
var grace_left := 0.0
var cooldown := 0.0
var armed := true
var burst_started := -100.0
var burst_eligible := false

func advance(delta: float, hull: float, maximum: float) -> void:
	clock += maxf(delta, 0.0)
	grace_left = maxf(0.0, grace_left - delta)
	cooldown = maxf(0.0, cooldown - delta)
	if not armed and cooldown <= 0.0 and hull >= maximum * 0.60:
		armed = true

func limit_damage(damage: float, hull: float, maximum: float) -> float:
	if grace_left > 0.0:
		return 0.0
	if clock - burst_started > BURST_WINDOW:
		burst_started = clock
		burst_eligible = hull > maximum * 0.30
	if armed and burst_eligible and damage >= hull:
		armed = false
		burst_eligible = false
		cooldown = REARM_DELAY
		grace_left = GRACE
		return maxf(0.0, hull - 1.0)
	return damage
