extends "res://PlayerControllers/Abilities/EvilGun/evil_gun_ability.gd"

# Sorry in advance, this is going to get weird thanks to Godot's lack of 
# multi-inheritence / interface implementation

const MoneyAbility := preload("res://PlayerControllers/Abilities/MoneyBased/base_money_ability.gd")

## Composition hack. Godot hasn't implemented interfaces or multi-inheritence so I've got to do this terribleness to mock it
## AbilityHolder is essentially an unmodified MoneyAbility which I'm then connecting the signals and properties to so that
## the overall class mimics the functionality of a MoneyAbility despite not technically being one
class AbilityHolder extends MoneyAbility:
	func activate() -> void:
		return
	
	pass

var abh := AbilityHolder.new()

signal cost_updated(old: float, new: float)
signal reward_updated(old: float, new: float)
signal mult_updated(old: float, new: float)
signal activations_updated(old: int, new: int)

signal fired(cost: float)

var activations: int = abh.activations:
	get: return abh.activations
	set(a): 
		abh.activations = a
		activations = abh.activations

var cost_per_activation: float = abh.cost_per_activation:
	get: return abh.cost_per_activation
	set(c): 
		abh.cost_per_activation = c
		cost_per_activation = abh.cost_per_activation

var reward_per_kill: float = abh.reward_per_kill:
	get: 
		var storage := abh.reward_per_kill
		if storage < 0: return abs(storage)
		else: return ceilf(100.0/damage) * cost_per_activation * 3
	
	set(c): 
		abh.reward_per_kill = c
		reward_per_kill = abh.reward_per_kill


var can_kill: bool = true:
	get: return true
	set(_v): return
	
var cost_multiplier: float = abh.cost_multiplier:
	get: return abh.cost_multiplier
	set(m): 
		abh.cost_multiplier = m
		cost_multiplier = abh.cost_multiplier

var cash_storage: float = abh.cash_storage:
	get: return abh.cash_storage
	set(m): 
		abh.cash_storage = m
		cash_storage = abh.cash_storage
		update_label()

var net_activation_cost: float = abh.net_activation_cost:
	get: return abh.net_activation_cost
	set(n): 
		abh.net_activation_cost = n
		net_activation_cost = abh.net_activation_cost

var connected: bool = abh.connected:
	get: return abh.connected
	set(v): 
		abh.connected = v
		connected = abh.connected

func connect_player_cash(player: Merc) -> void:
	abh.connect_player_cash(player)

func _ready() -> void:
	add_to_group(abh.GROUP_NAME)
	abh.cost_updated		.connect(func(old: float, new: float) -> void: self.cost_updated		.emit(old, new))
	abh.reward_updated		.connect(func(old: float, new: float) -> void: self.reward_updated		.emit(old, new))
	abh.mult_updated		.connect(func(old: float, new: float) -> void: self.mult_updated		.emit(old, new))
	abh.activations_updated	.connect(func(old: float, new: float) -> void: self.activations_updated	.emit(old, new))
	
	## Gun Settings
	ammo = 99
	max_ammo = 99
	super()
	
	update_label()
	cost_per_activation = 0
	reward_per_kill = -500
	can_kill = true

func _process(delta: float) -> void:
	super(delta)
	
	# TODO: This is a bit hacky, and I don't love it, but it works for now. Figure out why it's not updating
	# correctly and remove this so that it only updates on actual cash update
	update_label()

### Gun Stuff ###

func update_label() -> void:
	label.text = "%0.2f/%0.2f: %0.f" % [cash_storage, net_activation_cost, floor(cash_storage / net_activation_cost)]

func equip() -> void:
	super()
	update_label()

func reload() -> void: return

func shoot():
	if cash_storage - cost_per_activation < 0:
		# Optional: Play a "click" sound here for empty ammo
		failure.emit()
		activated.emit(false)
		return
	
	cash_storage -= net_activation_cost
	
	# Restart animation and start the cooldown timer
	animation_player.stop() 
	animation_player.play("fire")
	fire_attack_speed.start()
	
	# 4. Fire every raycast in the array (1 for Pistol, Many for Shotgun)
	#_do_raycasts()
	
	fired.emit(net_activation_cost)
	activations += 1
	
	success.emit()
	activated.emit(true)
