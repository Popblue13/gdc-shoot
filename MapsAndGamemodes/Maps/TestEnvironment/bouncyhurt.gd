extends DestructibleProp
@onready var label_3d: Label3D = $Label3D

var time_to_reset = .5
@rpc("any_peer", "call_local", "reliable")

func _ready():
	team = "red"

func take_damage(damage: float):
	# We still accept the RPC call from the raycast, but we completely ignore 
	# the attacker_id because this is just a prop.
	rotation.x += (.2*(damage/100))
	time_to_reset = 1
	health -= damage
	label_3d.text = str(health)
	var attacker_id = multiplayer.get_remote_sender_id()
	notify_kill_confirmed(attacker_id)

func _process(delta):
	time_to_reset -= delta
	if time_to_reset <= 0:
		health = 100
		rotation.x = 0
		label_3d.text = str(health)
	rotation = rotation.normalized()
	rotation = rotation.lerp(Vector3.ZERO, delta * 15)
