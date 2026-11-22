class_name SludgeMeter
extends RefCounted
## Team health: the station's sludge level, 0..100 %.
## Rises from open leaks, unfinished clogs and hazards; falls when work
## orders complete. At 100 % the station floods (unless flooding is disabled,
## e.g. solo play, which can never hard-fail).

var value: float = 0.0
var can_flood: bool = true
var peak: float = 0.0


## open_leaks/open_clogs: counts of active, unfixed sources. mult: difficulty.
func tick(dt: float, open_leaks: int, open_clogs: int, mult: float, leak_rate: float, clog_rate: float) -> void:
	var rate: float = (float(open_leaks) * leak_rate + float(open_clogs) * clog_rate) * mult
	add(rate * dt)


func add(amount: float) -> void:
	value = clampf(value + amount, 0.0, 100.0)
	if not can_flood:
		value = minf(value, 95.0)
	peak = maxf(peak, value)


func reward(amount: float) -> void:
	value = maxf(0.0, value - amount)


func is_flooded() -> bool:
	return can_flood and value >= 100.0


## Stars: 3 = fast and clean, 1 = you made it.
static func stars_for(time_s: float, par_s: float, sludge: float) -> int:
	if time_s <= par_s and sludge < 50.0:
		return 3
	if time_s <= par_s * 1.5 and sludge < 80.0:
		return 2
	return 1
