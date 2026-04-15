extends Node
class_name LobbyContainer

const LOBBY = preload("res://MultiplayerStuff/Server/Lobby/Lobby.tscn")
const LOBBY_TIMEOUT_SECONDS = 300.0 # 5 Minutes

#RUNS ONLY ON SERVER
var lobbies : Dictionary[String, Array] = {} #lobbyid = [player_id, ...]
var empty_lobby_timers: Dictionary[String, Timer] = {} # NEW: Tracks deletion timers

@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var lobby_changer_camera: LobbyChangerCamera = $LobbyChangerCamera
@onready var map_dropdown: OptionButton = $LobbyViewer/Panel/OptionButton
@onready var lobby_name_input: LineEdit = $LobbyViewer/Panel/LobbyName

#might have to have a bool, if match started then always spawn the map if not there, this is so people late to joining gets synced up

func _ready():
	multiplayer_spawner.spawn_function = _custom_lobby_spawn
	_setup_map_dropdown() # Add this line!
	if !multiplayer.is_server(): return
	multiplayer.peer_disconnected.connect(_on_player_disconnected)

func _setup_map_dropdown() -> void:
	if map_dropdown == null: return 
	
	map_dropdown.clear() # Clear any default items in the inspector
	
	# Loop through all the keys in your global database
	for map_key in ServerDatabase.Maps.keys():
		if map_key == "hm_home":
			continue # Skip the home map
			
		# Add the map name to the list
		map_dropdown.add_item(map_key)

@rpc("any_peer", "call_remote", "reliable")
func create_new_lobby(desired_lobby_id: String, players_in_lobby: Array[int], selected_map : String):
	if multiplayer.is_server():
		# Grab the index on the server BEFORE adding the new lobby to the dictionary
		var final_lobby_id = desired_lobby_id.validate_node_name()
		var base_name = final_lobby_id
		var name_suffix = 2
		
		# 2. If the name already exists, keep adding numbers until it's unique!
		while lobbies.has(final_lobby_id):
			final_lobby_id = base_name + "_" + str(name_suffix)
			name_suffix += 1
		
		var current_index = lobbies.size() 
		
		# Pack the index into the data package!
		var data = { 
			"id": final_lobby_id, 
			"players": players_in_lobby,
			"grid_index": current_index, # <--- ADD THIS
		}
		
		lobbies[final_lobby_id] = players_in_lobby
		ServerDatabase.update_lobbies(lobbies)
		var lob : Lobby = multiplayer_spawner.spawn(data)
		
		if lobbies.size() == 1:
			lob.call_deferred("change_map", "hm_home")
		else:
			lob.call_deferred("change_map", selected_map)
			
		# NEW: If lobby is created empty, immediately start the deletion timer
		if players_in_lobby.is_empty():
			_start_lobby_deletion_timer(final_lobby_id)

# This runs on EVERY machine when the lobby spawns
func _custom_lobby_spawn(data: Dictionary) -> Node:
	var lobby_scene: Lobby = LOBBY.instantiate()
	lobby_scene.name = str(data["id"]).validate_node_name()
	
	# --- GRID SPAWN LOGIC ---
	# Read the exact index the server assigned to this specific lobby!
	var index = data["grid_index"] 
	
	var columns = 8 
	var spacing = 1500.0 
	
	var grid_x = index % columns
	var grid_z = floor(index / columns)
	
	lobby_scene.position = Vector3(grid_x * spacing, 0, grid_z * spacing)
	# ------------------------
	
	if not multiplayer.is_server() and multiplayer.get_unique_id() not in data["players"]:
		lobby_scene.hide() 
		lobby_scene.process_mode = Node.PROCESS_MODE_DISABLED
		
	return lobby_scene

@rpc("any_peer","call_remote",'reliable')
func add_player_to_lobby(lobby_id : String, player_id : int):
	if !multiplayer.is_server():
		add_player_to_lobby.rpc_id(1, lobby_id, player_id)
		return
	
	if lobbies.has(lobby_id):
		if player_id not in lobbies[lobby_id]:
			# NEW: Stop the deletion countdown because someone joined!
			_cancel_lobby_deletion_timer(lobby_id)
			
			lobbies[lobby_id].append(player_id)
			ServerDatabase.update_lobbies(lobbies)
			wake_up_lobby.rpc_id(player_id, lobby_id)
			
			var active_lobby : Lobby = get_node_or_null(lobby_id.validate_node_name())
			if active_lobby:
				active_lobby.on_player_joined(player_id)
			
		else: print(str(player_id) + ' already joined')
	else:
		print("lobby does not exist :(")

@rpc("any_peer", "call_remote", "reliable")
func remove_player_from_lobby(lobby_id: String, player_id: int):
	# 1. If a client calls this, route it to the server
	if !multiplayer.is_server():
		remove_player_from_lobby.rpc_id(1, lobby_id, player_id)
		return
	# 2. Server handles the actual removal
	if lobbies.has(lobby_id):
		if player_id in lobbies[lobby_id]:
			lobbies[lobby_id].erase(player_id)
			
			# Update the dumb ServerDatabase single-source-of-truth
			ServerDatabase.update_lobbies(lobbies)
			
			# Tell the Map that they left so it can delete their character/stats!
			var active_lobby : Lobby = get_node_or_null(lobby_id.validate_node_name())
			if active_lobby:
				active_lobby.on_player_left(player_id)
				
			print("Player ", player_id, " removed from ", lobby_id)
			
			# NEW: Check if the lobby is now completely empty
			if lobbies[lobby_id].is_empty() and lobby_id != "home":
				_start_lobby_deletion_timer(lobby_id)

@rpc("any_peer", "call_remote", "reliable")
func change_lobby(new_lobby_id: String, player_id: int) -> void:
	# 1. Route client requests to the server
	if !multiplayer.is_server():
		change_lobby.rpc_id(1, new_lobby_id, player_id)
		return
		
	# 2. Make sure the destination actually exists
	if not lobbies.has(new_lobby_id):
		print("Cannot change lobby: Destination lobby does not exist.")
		return

	# 3. Find the player's current lobby
	var old_lobby_id: String = ""
	for l_id in lobbies.keys():
		if player_id in lobbies[l_id]:
			old_lobby_id = l_id
			break

	# 4. Prevent redundant work if they are already there
	if old_lobby_id == new_lobby_id:
		print("Player " + str(player_id) + " is already in lobby: " + new_lobby_id)
		return
	
	# 4.5 Trigger the client-side camera transition
	if old_lobby_id == 'home':
		start_client_camera_transition.rpc_id(player_id, old_lobby_id, new_lobby_id)
	else:
		finalize_lobby_change_on_server(old_lobby_id, new_lobby_id)

@rpc("authority", "call_remote", "reliable")
func start_client_camera_transition(old_lobby_id: String, new_lobby_id: String):
	wake_up_lobby(new_lobby_id)
	
	var old_lobby : Lobby = get_node_or_null(old_lobby_id.validate_node_name())
	var new_lobby : Lobby = get_node_or_null(new_lobby_id.validate_node_name())
	var old_path : CameraFollowPath = old_lobby.camera_follow_path
	var new_path : CameraFollowPath = new_lobby.camera_follow_path
	
	if old_lobby_id == "home":
		var middle_path = old_lobby.get_node('home').trans_middle #maps have same name as lobby
		middle_path.set_dolly_points(old_path, new_path)
		old_path = old_lobby.get_node('home').trans_out_path
		
		lobby_changer_camera.set_dolley_sequence([old_path,middle_path, new_path])
		await lobby_changer_camera.finished_with_all_camera_transitions
	elif old_path and new_path:
		lobby_changer_camera.set_dolley_sequence([old_path, new_path])
		await lobby_changer_camera.finished_with_all_camera_transitions
	
	# Once the animation finishes, tell the server to complete the data swap
	finalize_lobby_change_on_server.rpc_id(1, old_lobby_id, new_lobby_id)


@rpc("any_peer", "call_remote", "reliable")
func finalize_lobby_change_on_server(old_lobby_id: String, new_lobby_id: String):
	if !multiplayer.is_server(): return
	
	# Get the ID of the client who just finished their animation
	var player_id = multiplayer.get_remote_sender_id()
	
	# 5. Execute the swap
	if old_lobby_id != "":
		remove_player_from_lobby(old_lobby_id, player_id)
		put_lobby_to_sleep.rpc_id(player_id, old_lobby_id)

	# 6. Add them to the new lobby
	add_player_to_lobby(new_lobby_id, player_id)

@rpc("authority", "call_remote", "reliable")
func put_lobby_to_sleep(lobby_id: String): 
	var inactive_lobby: Lobby = get_node_or_null(lobby_id.validate_node_name())
	if inactive_lobby:
		inactive_lobby.hide()
		inactive_lobby.process_mode = Node.PROCESS_MODE_DISABLED

@rpc("authority", "call_remote", "reliable")
func wake_up_lobby(lobby_id: String): 
	var active_lobby :Lobby = get_node_or_null(lobby_id.validate_node_name())
	if active_lobby:
		active_lobby.show()
		active_lobby.process_mode = Node.PROCESS_MODE_INHERIT

func _on_create_lobby_button_pressed() -> void:
	if !multiplayer.is_server():
		var array_of_player :Array[int] = []
		
		var selected_map = map_dropdown.get_item_text(map_dropdown.selected)
		var desired_name = lobby_name_input.text.strip_edges()
		
		if desired_name == "":
			desired_name = "Server_Lobby_" + str(randi_range(1000, 9999))
			
		create_new_lobby.rpc_id(1, desired_name, array_of_player, selected_map)
		
func _on_player_disconnected(peer_id: int):
	# Search our local lobbies dictionary to find where they were
	for lobby_id in lobbies.keys():
		if peer_id in lobbies[lobby_id]:
			remove_player_from_lobby(lobby_id, peer_id)
			return

#region LOBBY SAFTEY TIMER DELETION
#LOBBY TIMEOUT SAFETY LOGIC
# ==========================================

func _start_lobby_deletion_timer(lobby_id: String) -> void:
	if empty_lobby_timers.has(lobby_id) or lobby_id == 'home':
		return # Timer is already running
		
	var timer = Timer.new()
	timer.wait_time = LOBBY_TIMEOUT_SECONDS
	timer.one_shot = true
	# Use a lambda to pass the lobby_id parameter into the timeout function
	timer.timeout.connect(func(): _on_empty_lobby_timeout(lobby_id))
	add_child(timer)
	timer.start()
	
	empty_lobby_timers[lobby_id] = timer
	print("Lobby '", lobby_id, "' is empty. Safely closing in 5 minutes.")

func _cancel_lobby_deletion_timer(lobby_id: String) -> void:
	if empty_lobby_timers.has(lobby_id):
		var timer = empty_lobby_timers[lobby_id]
		if is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
		empty_lobby_timers.erase(lobby_id)
		print("Player joined Lobby '", lobby_id, "'. Deletion cancelled.")

func _on_empty_lobby_timeout(lobby_id: String) -> void:
	if !multiplayer.is_server(): return
	
	# Double check that the lobby is still empty and actually exists
	if lobbies.has(lobby_id) and lobbies[lobby_id].is_empty():
		print("Lobby '", lobby_id, "' was empty for 5 minutes. Deleting...")
		
		# 1. Clean up databases
		lobbies.erase(lobby_id)
		ServerDatabase.update_lobbies(lobbies)
		
		# 2. Delete the actual node from the world
		var active_lobby: Lobby = get_node_or_null(lobby_id.validate_node_name())
		if active_lobby:
			active_lobby.queue_free()
			
	# 3. Clean up the timer reference
	if empty_lobby_timers.has(lobby_id):
		var timer = empty_lobby_timers[lobby_id]
		if is_instance_valid(timer):
			timer.queue_free()
		empty_lobby_timers.erase(lobby_id)
#endregion
