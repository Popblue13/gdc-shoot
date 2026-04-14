extends "res://PlayerControllers/Abilities/Jump/jump_ability.gd"

var cash: float = 100
var cost_per_jump: float = 10
var cost_mult: float = 1.0
func update_cost_mult(mult: float) -> void: cost_mult = mult

signal fired(cost_per_bullet: float)
func _connect_cash(player: Merc) -> void:
	if player.has_signal("cash_updated"):
		player.cash_updated.connect(func(new: float) -> void: cash = new)

signal uses_updated(uses: int, prior: int)
var activations: int = 0:
	set(n):
		if n != activations:
			var old := activations
			activations = max(0, n)
			uses_updated.emit(activations, old)
func get_activations() -> int: return activations

func _ready() -> void:
	jump_strength *= 2
	success.connect(
		func() -> void: 
			fired.emit(cost_per_jump * cost_mult)
			activations += 1
	)
	return

func _physics_process(delta: float) -> void:
	if cash - (cost_per_jump * cost_mult) < 0: return
	super(delta)
