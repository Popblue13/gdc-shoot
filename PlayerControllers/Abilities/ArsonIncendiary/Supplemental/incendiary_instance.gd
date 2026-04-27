extends Node3D

const FIRE_AREA = preload("res://PlayerControllers/Abilities/ArsonIncendiary/Supplemental/FireArea.tscn")
const FIRE_POINT = preload("res://PlayerControllers/Abilities/ArsonIncendiary/Supplemental/FirePoint.tscn")
const MASTER_FIRE = preload("res://PlayerControllers/Abilities/ArsonIncendiary/Supplemental/MasterFire.tscn")

var exploding = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node) -> void:
	if !exploding:
		var parent = get_parent()
		var impact_pos = self.global_position
		var multiplayer_auth = self.get_multiplayer_authority()
		exploding = true
		if is_multiplayer_authority():
			if body and body.has_method("take_damage"):
				body.take_damage.rpc_id(body.get_multiplayer_authority(), 5.0) #Do 5 damage on direct impact
		#print("collided with " + str(body.name) + str(body.get_path()))
		#var fire = MASTER_FIRE.instantiate()
		#fire.set_multiplayer_authority(multiplayer_auth)
		#parent.add_child(fire)
		#fire.global_position = impact_pos
		#fire.set_multiplayer_authority(multiplayer_auth)
		var parentpath = parent.get_path()
		#spawnMasterFire.rpc(impact_pos, multiplayer_auth)#, parentpath)
		spawnMasterFire(impact_pos, multiplayer_auth)
		
		#await get_tree().create_timer(0.05).timeout
		despawnMyself()
		#despawnMyself.rpc()

#@rpc("any_peer", "call_local", "reliable")
func spawnMasterFire(start_pos, ownerID):#, parentpath):
	#print("Spawning master fire!")
	var fire = MASTER_FIRE.instantiate()
	fire.set_multiplayer_authority(ownerID)
	#var parent = get_node_or_null(parentpath)
	var parent = get_tree().root
	parent.add_child(fire)
	fire.global_position = start_pos

#@rpc("any_peer", "call_local", "reliable")
func despawnMyself():
	hide()
	#await get_tree().create_timer(20).timeout
	#queue_free()
