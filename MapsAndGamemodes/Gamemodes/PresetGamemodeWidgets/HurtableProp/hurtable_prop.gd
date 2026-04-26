extends Merc 
class_name DestructibleProp

@export var invulnerable:bool = true

# 1. STRIP THE PHYSICS & PLAYER LOGIC
func _ready():
	health = 100.0
	# Do NOT call super() or custom_ready() so it doesn't spawn UI/Cameras

func _physics_process(delta):
	pass # Disables movement and gravity processing

func _process(delta):
	pass 

func _input(Inpu):
	pass

#override these functions to get your desired results in an unintrusive way.
func hit_effect(damage):
	pass
func destroy_effect():
	pass

# 2. OVERRIDE DAMAGE TO PREVENT LEADERBOARD KILLS
@rpc("any_peer", "call_local", "reliable")
func take_damage(damage: float):
	# We still accept the RPC call from the raycast, but we completely ignore 
	# the attacker_id because this is just a prop.
	
	hit_effect(damage)
	
	health -= damage
	print('hurt')
	if health <= 0 and not dead:
		dead = true
		destroy_prop()
		# We do NOT call die.rpc_id(1, attacker_id) here!
		# This protects the DM.gd leaderboard from registering a kill.


@rpc("any_peer", "call_local", "reliable")
func destroy_prop():
	# Spawn debris, play a sound, then remove
	destroy_effect()
	if !invulnerable:
		queue_free()
