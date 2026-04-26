@abstract
extends Merc

const MoneyAbility := preload("res://PlayerControllers/Abilities/MoneyBased/base_money_ability.gd")

const GROUP_NAME = "CASH_USER"				## Group name. Access through `get_tree().get_nodes_in_group()` and similar group functions
@export var DEFAULT_CASH: float = 250.99	## Starting cash
@export var MIN_CASH: float = 0				## Minimum possible cash
@export var MAX_CASH: float = 10000.0		## Maximum possible cash

signal cash_updated(old: float, new: float)	## Emitted any time the player's cash changes

## Player's cash. Relayed to money-based abilities via `cash_updated` signal
var cash: float = DEFAULT_CASH:
	set(m):
		m = clampf(m, MIN_CASH, MAX_CASH)
		if m != cash:
			var old := cash
			cash = m
			cash_updated.emit(old, cash)

## Last used money ability. Used for returning money on kill. A bit ad-hoc because the kill_confirmed signal
## doesn't return the ability being used to kill, but it should be fine in most cases
@onready var last_used_ability: Ability = null

## Overwritten from `Merc`, but still makes space for a custom ready via `money_custom_ready`
func custom_ready() -> void:
	add_to_group(GROUP_NAME)
	for ability in abilities:
		if !ability.is_in_group(MoneyAbility.GROUP_NAME): continue
		ability.connect_player_cash(self)
		ability.fired.connect(
			func(cost: float) -> void: 
				cash -= cost
				if ability.can_kill: 
					last_used_ability = ability
		)

	kill_confirmed.connect(
		func(_killed_id: int) -> void:
			if !last_used_ability or !last_used_ability.is_in_group(MoneyAbility.GROUP_NAME): return
			cash += last_used_ability.reward_per_kill
	)

	health_changed.connect(
		func(old: float, new: float) -> void: if new < old: cash += 10 * abs(old - new)
	)

	money_custom_ready()
	return

## Overwrite in an extending class to implement merc specific ready behavior
@abstract func money_custom_ready() -> void
