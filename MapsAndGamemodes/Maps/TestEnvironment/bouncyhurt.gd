extends DestructibleProp
@onready var label_3d: Label3D = $Label3D

var time_to_reset = .5
@rpc("any_peer", "call_local", "reliable")
func take_damage(damage: float):
	# We still accept the RPC call from the raycast, but we completely ignore 
	# the attacker_id because this is just a prop.
	rotation.x += .2
	time_to_reset = 1
	health -= damage
	label_3d.text = str(health)

func _process(delta):
	time_to_reset -= delta
	if time_to_reset <= 0:
		health = 100
		label_3d.text = str(health)
	rotation = rotation.normalized()
	rotation = rotation.lerp(Vector3.ZERO, delta * 15)
