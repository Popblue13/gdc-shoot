extends Merc

@onready var UI = $UI
@onready var boltgun = $BoltGun

var bolts = 0 : set = set_bolt

func set_bolt(value):
	var diff = abs(bolts - value)
	if bolts > value:
		UI.remove_bolts(diff)
	else:
		UI.add_bolts(diff)
	print(value, diff, bolts)
	bolts = value

#nothing here! other than some basic ui and text stuff!
func custom_process(delta : float): 
	pass

func custom_ready():
	bolts = 1

func _on_kill_confirmed(person_killed_id: int) -> void:
	bolts += 1
