extends DestructibleProp

@export var damage = 10

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var dada : Merc
var targets := []

func hit_effect(damage):
	print("ouchies")

@rpc("any_peer", "call_local", "reliable")
func take_damage(damage: float):
	dada.turret_take_damage(name, damage)

@rpc("any_peer", "call_local", "reliable")
func take_real_damage(damage):
	print(multiplayer.get_unique_id())
	health -= damage
	if health <= 0 and not dead:
		dead = true
		destroy_prop.rpc()


func _physics_process(delta):
	pass
