class_name SwordMotion
extends RefCounted
## Animation, hit window, grounded step and cancel timing share the same clock.
const SWINGS := [
	{"duration":0.34,"active":Vector2(0.31,0.56),"frames":[0.14,0.30,0.39,0.58,0.78,1.01],"step":0.20,"cancel":0.67},
	{"duration":0.37,"active":Vector2(0.32,0.57),"frames":[0.13,0.31,0.40,0.58,0.78,1.01],"step":0.24,"cancel":0.68},
	{"duration":0.52,"active":Vector2(0.43,0.63),"frames":[0.15,0.40,0.49,0.66,0.83,1.01],"step":0.30,"cancel":0.80}]
const FIRE_SWINGS := [
	{"duration":0.50,"active":Vector2(0.38,0.56),"frames":[0.08,0.30,0.38,0.58,0.80,1.01],"step":0.16,"cancel":0.76,"reach":2.15,"cone":0.18,"bonus":0,"pause":0.045,"shake":0.035},
	{"duration":0.54,"active":Vector2(0.35,0.55),"frames":[0.06,0.27,0.35,0.57,0.79,1.01],"step":0.20,"cancel":0.76,"reach":2.30,"cone":0.05,"bonus":4,"pause":0.050,"shake":0.045},
	{"duration":0.70,"active":Vector2(0.46,0.63),"frames":[0.06,0.38,0.46,0.65,0.85,1.01],"step":0.26,"cancel":0.83,"reach":2.50,"cone":0.78,"bonus":12,"pause":0.075,"shake":0.075}]
const THUNDER_SWINGS := [
	{"duration":0.24,"active":Vector2(0.28,0.49),"frames":[0.06,0.17,0.28,0.51,0.73,1.01],"step":0.10,"cancel":0.64,"reach":2.80,"width":0.36,"bonus":0,"pause":0.012,"shake":0.012},
	{"duration":0.22,"active":Vector2(0.25,0.48),"frames":[0.04,0.14,0.25,0.50,0.72,1.01],"step":0.10,"cancel":0.62,"reach":2.95,"width":0.36,"bonus":0,"pause":0.012,"shake":0.012},
	{"duration":0.32,"active":Vector2(0.33,0.55),"frames":[0.05,0.22,0.33,0.57,0.78,1.01],"step":0.24,"cancel":0.72,"reach":3.15,"width":0.42,"bonus":3,"pause":0.022,"shake":0.025}]
static func profile(combo: int, weapon: String = "wind") -> Dictionary:
	var index := clampi(combo-1,0,2)
	if weapon=="fire":
		return FIRE_SWINGS[index]
	if weapon=="thunder":
		return THUNDER_SWINGS[index]
	var result: Dictionary = SWINGS[index].duplicate(true)
	result.merge({"reach":2.25 if combo==3 else 2.05,"cone":0.12 if combo==3 else -0.05,"bonus":[0,1,4][index],"pause":0.055 if combo==3 else 0.035,"shake":0.065 if combo==3 else 0.025})
	return result
static func in_range(combo: int, weapon: String, offset: Vector3, facing: Vector3) -> bool:
	var data := profile(combo,weapon)
	var forward := offset.dot(facing)
	if weapon=="thunder":
		# A narrow lane, not a cone that gets very wide at the tip. Never hit behind.
		return forward>=0.0 and forward<float(data.reach) and (offset-facing*forward).length()<float(data.width)
	var length := offset.length()
	if weapon=="fire":
		return length<float(data.reach) and forward>=0.0 and (length<0.25 or facing.dot(offset.normalized())>float(data.cone))
	return length<float(data.reach) and (length<0.35 or facing.dot(offset.normalized())>float(data.cone))
static func frame(combo: int, progress: float, weapon: String = "wind") -> int:
	var ends: Array = profile(combo,weapon).frames
	for i in range(6):
		if progress<float(ends[i]):
			return i
	return 5
static func active(combo: int, progress: float, weapon: String = "wind") -> bool:
	var window: Vector2 = profile(combo,weapon).active
	return progress>=window.x and progress<=window.y
static func step_speed(combo: int, progress: float, weapon: String = "wind") -> float:
	var data := profile(combo,weapon)
	var window: Vector2 = data.active
	if progress<window.x or progress>window.y:
		return 0
	# Sine pulse integrates to the chosen step length: no constant skating in recovery.
	return float(data.step)*PI/(2.0*float(data.duration)*(window.y-window.x))*sin(PI*(progress-window.x)/(window.y-window.x))
