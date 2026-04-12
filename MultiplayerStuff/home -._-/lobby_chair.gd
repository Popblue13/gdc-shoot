extends HomeBodyInteract

var enabled = false
var homebody : HomeBody = null
@onready var headset: Node3D = $headset
var org_trans : Transform3D
@onready var seat: Marker3D = $seat
@onready var hm_home: HM = $".."

func _ready() -> void:
	org_trans = headset.global_transform

func interact(body: HomeBody):
	if enabled == true: return
	enabled = true
	body.dead = true
	body.sitting_in_chair = true
	homebody = body
	body.current_chair = self 
	
	# We NO LONGER swap authority! The client keeps control of their body.
	# We just tell the server "Hey, I sat down, mark this chair as taken."
	if !multiplayer.is_server():
		update_server_with_chair.rpc_id(1, body.name.to_int())
	else:
		update_server_with_chair(body.name.to_int()) 
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(body, "global_position", seat.global_position, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(body, "global_rotation", seat.global_rotation, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	
	if body.camera:
		tween.tween_property(body.camera, "rotation", Vector3.ZERO, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

	await tween.finished
	await homebody.play_headset_anim()
	
	var tween2 = create_tween()
	tween2.tween_property(headset, "global_position", body.camera.global_position + (body.camera.basis.x * .2) , .1)
	
	var lobby_container = get_tree().get_first_node_in_group("LobbyContainer")
	if lobby_container: 
		lobby_container.get_node('LobbyViewer').open()

@rpc("any_peer","call_remote",'reliable')
func update_server_with_chair(peer_id: int = 0):
	if !multiplayer.is_server(): return
	
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = peer_id 
	
	var body = hm_home.get_node_or_null(str(sender_id))
	if body:
		# The Server just records that they are sitting so it knows the state.
		# It DOES NOT take authority. The client will handle sending the position!
		body.current_chair = self
		body.sitting_in_chair = true


# --- The client asks the server to leave the chair ---
@rpc("any_peer", "call_remote", "reliable")
func request_leave_chair():
	if not multiplayer.is_server(): return
	# Tell all clients (including the server) to play the exit animations
	leave_chair.rpc_id(multiplayer.get_remote_sender_id())

# --- The visual animation that runs on everyone's screen ---
@rpc("authority", "call_local", "reliable")
func leave_chair():
	enabled = false
	var was_my_chair = false
	
	if homebody:
		homebody.sitting_in_chair = false
		homebody.current_chair = null
		if homebody.has_method("play_headset_anim_reverse"):
			homebody.play_headset_anim_reverse()
			
		var local_id = multiplayer.get_unique_id()
		was_my_chair = (homebody.name == str(local_id))
		
		# We no longer need to restore authority here, just fix the camera
		if was_my_chair:
			homebody.camera.make_current()
			homebody.dead = false
		homebody = null
	
	var tween2 = create_tween()
	tween2.tween_property(headset, "global_transform", org_trans, .5)
	
	if was_my_chair:
		var lobby_container = get_tree().get_first_node_in_group("LobbyContainer")
		if lobby_container: 
			lobby_container.get_node('LobbyViewer').close()
