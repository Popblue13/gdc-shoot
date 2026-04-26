extends "res://PlayerControllers/Abilities/Grenade/grenade_ability.gd"

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
	get: return ceilf(100.0/damage) * cost_per_activation * 3
	set(_c): return

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

var m: Merc = abh.m:
	get: return abh.m
	set(mer):
		abh.m = mer
		m = abh.m

func connect_player_cash(player: Merc) -> void:
	abh.connect_player_cash(player)

func _ready() -> void:
	add_to_group(abh.GROUP_NAME)
	abh.cost_updated		.connect(func(old: float, new: float) -> void: self.cost_updated		.emit(old, new))
	abh.reward_updated		.connect(func(old: float, new: float) -> void: self.reward_updated		.emit(old, new))
	abh.mult_updated		.connect(func(old: float, new: float) -> void: self.mult_updated		.emit(old, new))
	abh.activations_updated	.connect(func(old: float, new: float) -> void: self.activations_updated	.emit(old, new))
	abh.equipped			.connect(func(ab: Ability) -> void: self.equipped.emit(ab))

	cost_per_activation = 35
	damage = 100
	can_kill = true

func shoot():
	if cash_storage - net_activation_cost < 0: return
	
	super()
	cash_storage -= net_activation_cost
	fired.emit(net_activation_cost)
	activations += 1

func equip():
	super()
	equipped.emit(self)

@rpc("any_peer", "call_local", "reliable")
func explode():
	# Only the authority should calculate and send damage
	if is_multiplayer_authority():
		for i in explosion_radius.get_overlapping_bodies():
			if i != null and i != m and i is Merc:
				i.take_damage.rpc_id(i.name.to_int(), damage) 
	
	# Everything below this runs locally for all clients (Visuals/Cleanup)
	if cpu_particles_3d: cpu_particles_3d.emitting = true
	grenade.set_deferred("freeze", true)
	
	await cpu_particles_3d.finished
	reset_grenade()

func reset_grenade():
	#Kill leftover momentum so it doesn't fly off when un-frozen later
	grenade.linear_velocity = Vector3.ZERO
	grenade.angular_velocity = Vector3.ZERO
	
	grenade.global_transform = hand.global_transform
	
	#Re-link the RemoteTransform3D so the grenade follows the hand again
	hand.set_deferred("remote_path", hand.get_path_to(grenade))
	
	grenade.visible = true
	thrown = false
