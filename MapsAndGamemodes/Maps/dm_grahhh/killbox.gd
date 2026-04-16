extends Area3D

@onready var scream = $AudioStreamPlayer3D

@export var damage = 10000

func _on_body_entered(body: Node3D) -> void:
	print("body in moat")
	if not is_multiplayer_authority(): return
	body.take_damage.rpc_id(body.name.to_int(), damage) 
	scream.play()
