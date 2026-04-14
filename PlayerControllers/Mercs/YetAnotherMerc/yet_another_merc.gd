extends Merc

signal cash_updated(new_cash: float)
@export var cash: float = 1000.0:
	set(m):
		var tmp: float = max(0, min(m, 9999))
		if tmp != cash:
			cash = tmp
			cash_updated.emit(cash)

@onready var cash_using_abilities: Array = [
		$MoneyGun,
		$MoneyShotgun,
		$MoneyMachineGun,
		$MoneyGrenade,
		$JumpAbility,
		$SprintAbility
	]:
	get: return cash_using_abilities.duplicate()
	set(_n): return

func custom_ready() -> void:
	for ability in cash_using_abilities:
		if ability.has_method("_connect_cash"): ability._connect_cash(self)
		if ability.has_signal("fired"): ability.fired.connect(func(cost: float) -> void: cash -= cost)
	
	return

func custom_process(_delta: float) -> void:
	return
