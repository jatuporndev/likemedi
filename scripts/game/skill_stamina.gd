extends RefCounted

const MAX_STAMINA := 6
const RECHARGE_SECONDS := 4.0

var current := MAX_STAMINA
var _recharge_progress := 0.0


func can_spend(amount: int) -> bool:
	return amount <= current


func spend(amount: int) -> bool:
	if not can_spend(amount):
		return false

	current -= amount
	return true


func recharge(delta: float) -> bool:
	if current >= MAX_STAMINA:
		_recharge_progress = 0.0
		return false

	_recharge_progress += delta
	if _recharge_progress < RECHARGE_SECONDS:
		return false

	var gained := int(_recharge_progress / RECHARGE_SECONDS)
	_recharge_progress = fmod(_recharge_progress, RECHARGE_SECONDS)
	current = mini(current + gained, MAX_STAMINA)
	if current >= MAX_STAMINA:
		_recharge_progress = 0.0
	return true


func recharge_progress_seconds() -> float:
	return _recharge_progress
