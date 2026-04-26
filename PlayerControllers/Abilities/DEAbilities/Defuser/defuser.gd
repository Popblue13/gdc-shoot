extends Ability

@onready var ray_cast_3d: RayCast3D = $RayCast3D

const defuse_time : float = 10.0
var cur_defuse_level : float = 10.0

var is_defusing : bool = false

# FIX 1: Use physics process so it perfectly matches the Merc's check_abilities rate
func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority(): return
	
	if merc and merc.camera:
		ray_cast_3d.global_transform = merc.camera.global_transform
	
	if not is_defusing:
		cur_defuse_level = defuse_time
		
	# Reset the flag so we can check it again next frame
	is_defusing = false
	
func activate():
	if !is_multiplayer_authority(): return
	if not ray_cast_3d.is_colliding(): return
	
	var hit_object = ray_cast_3d.get_collider()
	# If we hit the StaticBody3D child, grab its owner to access the DEBOMB script
	var bomb_target = hit_object if hit_object is PlantedBomb else hit_object.owner as PlantedBomb
	
	
	if bomb_target and bomb_target.planted:
		is_defusing = true
		# Use physics delta to ensure the math is accurate to the frame rate
		cur_defuse_level -= get_physics_process_delta_time()
		print(cur_defuse_level)
		if cur_defuse_level <= 0.0:
			# Defuse complete! Prevent spamming and tell the server.
			cur_defuse_level = defuse_time 
			_request_defuse.rpc_id(1, bomb_target.get_path())

@rpc("any_peer", "call_local", "reliable")
func _request_defuse(bomb_path: NodePath):
	if not multiplayer.is_server(): return
	
	# On a headless server, this will ALWAYS be the correct player ID
	var defuser_id = multiplayer.get_remote_sender_id() 
	
	var bomb_node = get_node_or_null(bomb_path)
	if bomb_node and bomb_node.defuse_gamemode:
		bomb_node.defuse_gamemode.on_bomb_defused()
