extends "res://PlayerControllers/Abilities/Grenade/grenade_ability.gd"

signal fired(cost_per_bullet: float)

var cash: float = 100.0:
	set(c): 
		cash = max(0, min(c, 9999))
		available_ammo = cash

var cost_per_bullet: float = 20.0

var available_ammo: float = cash / cost_per_bullet:
	set(total_cash):
		available_ammo = floor(max(0, min(total_cash / cost_per_bullet, cash)))

var cost_mult: float = 1.0
func update_cost_mult(mult: float) -> void: cost_mult = mult

signal uses_updated(uses: int, prior: int)
var activations: int = 0:
	set(n):
		if n != activations:
			var old := activations
			activations = max(0, n)
			uses_updated.emit(activations, old)
func get_activations() -> int: return activations

func _connect_cash(player: Merc) -> void:
	if player.has_signal("cash_updated"):
		player.cash_updated.connect(func(new: float) -> void: cash = new)

func _ready() -> void:
	cash = 100
	damage = 100

func shoot():
	super()
	cash -= (cost_per_bullet * cost_mult)
	fired.emit(cost_per_bullet * cost_mult)
	activations += 1
