extends Ability
class_name passive_heal

@export var health_per_second: float = 5.0

var max_health: float

# frames until next heal
var time_to_heal: float = 0
var heal_progress: float = 0


func activate() -> void:
	if heal_progress >= time_to_heal:
		heal_progress = 0
		if merc.health < max_health:
			merc.take_damage(-1)

func _process(delta: float) -> void:
	if !time_to_heal:
		if merc != null:
			if merc.health != 0:
				# initilization step
				time_to_heal = 1.0 / health_per_second
				max_health = merc.health
	else:
		# framely function
		heal_progress += delta
		activate()
