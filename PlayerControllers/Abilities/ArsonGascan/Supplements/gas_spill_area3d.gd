extends Area3D

@onready var gas_spill: Node3D = $".."

func ignite():
	#print("Ignited!!!")
	gas_spill.ignite.rpc()
