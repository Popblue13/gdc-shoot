extends Map
class_name HM
@onready var trans_out_path: CameraFollowPath = $TransOutPath
@onready var trans_middle: CameraFollowPath = $TransMiddle

func start_gamemode():
	pass

func end_gamemode():
	pass #not gonna happen -._-

func player_died(merc : Merc, killer_id : int = 0):
	pass

func _on_player_joined(peer_id: int):
	if !multiplayer.is_server(): return
	
	# 1. Search for an existing body for this player.
	# Note: Adjust the path here if your player_spawner puts nodes somewhere else!
	# Assuming the spawned nodes are named as the peer_id (e.g., "1", "12345")
	var existing_body = get_node_or_null(str(peer_id))
	
	if existing_body:
		# --- PLAYER IS RETURNING ---
		print("Player ", peer_id, " returned home. Waking up existing body.")
		print(existing_body.current_chair)
		# If they were sitting in a chair, trigger the exit sequence
		if existing_body.current_chair:
			# This calls the @rpc("authority", "call_local") function we fixed earlier!
			# It will play the animations for everyone and the client will locally take back authority.
			existing_body.current_chair.request_leave_chair()
			
	else:
		# --- PLAYER IS JOINING FOR THE FIRST TIME ---
		print("Player ", peer_id, " joined home for the first time. Spawning body.")
		player_spawner.spawn({'merc_type' = 'homebody', "peer_id" = peer_id, "position" = Vector3.ZERO})
		
func custom_ready():
	pass

func _on_player_left(player_id: int):
	pass

func custom_process(delta : float):
	pass
