extends "res://PlayerControllers/Abilities/EvilGun/evil_gun_ability.gd"

signal fired(cost_per_bullet: float)

var cash: float = 100.0:
	set(c): 
		cash = max(0, min(c, 9999))
		available_ammo = cash

var cost_per_bullet: float = 0.0

var available_ammo: float = cash / (cost_per_bullet * cost_mult):
	set(total_cash):
		available_ammo = floor(max(0, min(total_cash / cost_per_bullet * cost_mult, cash)))
		@warning_ignore("narrowing_conversion")
		ammo = available_ammo
		label.text = "%0.2f/%0.2f: %0.0f" % [cash, cost_per_bullet * cost_mult, available_ammo]

var cost_mult: float = 1.0
func update_cost_mult(mult: float) -> void: 
	cost_mult = mult
	cash = cash

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
	ammo = 99
	max_ammo = 99
	super()
	label.text = ""

func reload() -> void: return

func shoot():
	if cash - cost_per_bullet < 0:
		# Optional: Play a "click" sound here for empty ammo
		return
	
	cash -= (cost_per_bullet * cost_mult)
	
	# Restart animation and start the cooldown timer
	animation_player.stop() 
	animation_player.play("fire")
	fire_attack_speed.start()
	label.text = "%0.2f/%0.2f: %0.0f" % [cash, (cost_per_bullet * cost_mult), available_ammo]
	
	# 4. Fire every raycast in the array (1 for Pistol, Many for Shotgun)
	_do_raycasts()
	
	fired.emit(cost_per_bullet * cost_mult)
	activations += 1
