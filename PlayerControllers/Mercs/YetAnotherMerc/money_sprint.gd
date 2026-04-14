extends SprintAbility

var cash: float = 100
var cost_per_second: float = 2

signal fired(cost_per_bullet: float)
func _connect_cash(player: Merc) -> void:
	if player.has_signal("cash_updated"):
		player.cash_updated.connect(func(new: float) -> void: cash = new)

func _physics_process(delta: float) -> void:
	if cash - cost_per_second < 0: _is_sprinting = false
	super(delta)
	if _is_sprinting:
		fired.emit(cost_per_second * delta)
