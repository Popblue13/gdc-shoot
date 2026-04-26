@abstract
extends Ability
## Abstract definition of a money-based ability
##
## This class outlines some things required for a money-based ability to function. Namely, a few variables, signals attached to those variables, and an `add_to_group` call.
## Any money-based ability should extend from this class for the entire market behavior to function

const CashUser := preload("res://PlayerControllers/Abilities/MoneyBased/base_money_user.gd")

const GROUP_NAME: String = "MONEY_ABILITY"	## Group name. Access through `get_tree().get_nodes_in_group()` and similar group functions
const DEFAULT_CASH: float = 1000.0			## Starting money
const MIN_ACTIVATIONS: int = 0				## Minimum number of activations the ability may have
const MIN_COST_PER_ACT: int = 0				## Minimum cost an activation will charge per activation
const MIN_COST_MULT: float = 0.001			## Minimum cost multiplier that will be applied to an activation

signal cost_updated(old: float, new: float)		## Emitted when the gross cost of ability activation changes
signal reward_updated(old: float, new: float)	## Emitted when the cost per kill changes
signal mult_updated(old: float, new: float)		## Emitted when the cost multiplier of ability activation changes
signal activations_updated(old: int, new: int)	## Emitted when the total number of activations changes

@warning_ignore_start("unused_signal")
signal fired(cost: float) ## Emitted by extending ability when a behavior is successful. Should emit the amount of money to subtract from the player
signal equipped(this: Ability)
@warning_ignore_restore("unused_signal")

## Number of times this ability has been activated. Used to determine cost multiplier
var activations: int = 0:
	set(a):
		a = max(MIN_ACTIVATIONS, a)
		if a != activations:
			var old := activations
			activations = a
			activations_updated.emit(old, activations)

## Gross cost to activate ability. Multiplied with `cost_multiplier` to get net cost per activation
@export var cost_per_activation: float = 0.0:
	set(c):
		c = max(MIN_COST_PER_ACT, c)
		if c != cost_per_activation:
			var old := cost_per_activation
			cost_per_activation = c
			cost_updated.emit(old, cost_per_activation)

## Amount of money awarded to the player on kill with this ability
@export var reward_per_kill: float = 100.0:
	set(c):
		if c != reward_per_kill:
			var old := reward_per_kill
			reward_per_kill = c
			reward_updated.emit(old, reward_per_kill)

## Whether the given ability can kill. Intended use is to not spuriously switch between last used abilities when moving / using movement abilities
@export var can_kill: bool = false

## Multiplier applied to `cost_per_activation` to get net cost
var cost_multiplier: float = 1.0:
	set(m):
		m = max(MIN_COST_MULT, m)
		if m != cost_multiplier:
			var old := cost_multiplier
			cost_multiplier = m
			mult_updated.emit(old, cost_multiplier)

var cash_storage: float = DEFAULT_CASH	## Used to store the player's cash without directly holding a reference to them
var net_activation_cost: float:
	get: return cost_per_activation * cost_multiplier
	set(n): assert(false, "<BaseMoneyAbility::set(net_activation_cost, %f)> Error: This is a virtual property, it can not be set" % n)

var connected: bool = false	## Whether the ability has been connected to a player or not. 
var m: Merc = null

## Connects the ability's `cash_storage` to a player's actual `cash_updated` signal
func connect_player_cash(player: Merc) -> void:
	if connected or !player or !player.is_in_group(CashUser.GROUP_NAME): return
	
	player.cash_updated.connect(func(_old: float, new: float) -> void: cash_storage = new)
	cash_storage = player.cash
	connected = true
	m = player
	
	return

## Adds any instantiated nodes to the money ability group. Call super() in your extending classes if you want them to be properly included
func _ready() -> void:
	add_to_group(GROUP_NAME)

func equip_ability(ab: Array[Ability]) -> void:
	super(ab)
	equipped.emit(self)
	
