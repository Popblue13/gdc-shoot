extends Merc

@onready var UI = $TrackerUI
@export var turrets = 0 : set = set_turrets
var bandages = 1

func set_turrets(value):
	turrets = value
	match turrets:
		0:
			$MeshInstance3D/backrig/turret1.visible = false
			$MeshInstance3D/backrig/turret1.visible = false
		1:
			$MeshInstance3D/backrig/turret1.visible = false
			$MeshInstance3D/backrig/turret1.visible = true
		2:
			$MeshInstance3D/backrig/turret1.visible = true
			$MeshInstance3D/backrig/turret1.visible = true
	var diff = abs(turrets - value)
	if turrets > value:
		UI.remove_bolts(diff)
	else:
		UI.add_bolts(diff)

@rpc("any_peer", "call_remote", "reliable")
func turret_take_damage(name, damage):
	for child in get_children():
		if child.name == name:
			child.take_real_damage(damage)

#nothing here! other than some basic ui and text stuff!
func custom_process(delta : float): 
	return

func custom_ready():
	turrets = 2
