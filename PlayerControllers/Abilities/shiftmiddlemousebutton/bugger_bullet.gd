extends Area3D

var parent : Merc 
var speed :float = 2
var damage :float = 50

var freeze_bullet : bool = false
var freeze_time :float = 2.0

func _process(delta: float) -> void:
	global_position -= global_transform.basis.z * delta * speed

func _on_body_entered(body: Node3D) -> void:
	if !is_multiplayer_authority(): return
	
	if body != parent and body is Merc:
		if freeze_bullet:
			body.disable_movement.rpc_id(body.name, freeze_time)
		else:
			body.take_damage.rpc_id(body.name, damage)
