extends SprintAbility

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
signal equipped(this: Ability)

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
	get: return abh.reward_per_kill
	set(c): 
		abh.reward_per_kill = c
		reward_per_kill = abh.reward_per_kill

var can_kill: bool = false:
	get: return false
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
	abh.equipped			.connect(func(ab: Ability) -> void: self.equipped.emit(ab))
	
	cost_per_activation = 0.25
	self.can_kill = false
	
var tmpact: float = 0.0
func _physics_process(delta: float) -> void:
	if cash_storage - (net_activation_cost * delta) < 0: 
		if _is_sprinting: _stop_sprint()
		_is_sprinting = false
	
	if _is_sprinting:
		tmpact += delta
		if tmpact >= 1:
			activations += 3
			tmpact = 0
		fired.emit(net_activation_cost * delta)
	
	super(delta)
