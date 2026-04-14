extends "res://PlayerControllers/Abilities/Jump/jump_ability.gd"

var cash: float = 100
var cost_per_jump: float = 10

signal fired(cost_per_bullet: float)
func _connect_cash(player: Merc) -> void:
	if player.has_signal("cash_updated"):
		player.cash_updated.connect(func(new: float) -> void: cash = new)

func _ready() -> void:
	jump_strength *= 2
	success.connect(func() -> void: fired.emit(cost_per_jump))
	return

func _physics_process(delta: float) -> void:
	if cash - cost_per_jump < 0: return
	super(delta)
