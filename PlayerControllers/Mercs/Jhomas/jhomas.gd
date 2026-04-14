extends Merc

@export_group("Jhomas Things")
@export var health_per_sec = 5.0

@onready var heal_delay: Timer = $HealDelay

func custom_process(_delta : float):
	if health >= 250.0:
		health = 250.0
	else:
		if heal_delay.is_stopped():
			take_damage(health_per_sec*-1)
			heal_delay.start()
