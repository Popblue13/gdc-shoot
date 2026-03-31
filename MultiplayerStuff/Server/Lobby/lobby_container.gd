extends Node
class_name LobbyContainer

const LOBBY = preload("res://MultiplayerStuff/Server/Lobby/Lobby.tscn")

#RUNS ONLY ON SERVER
var lobbies : Dictionary[String, Array] = {} #lobbyid = [player_id, ...]

#might have to have a bool, if match started then always spawn the map if not there, this is so people late to joining gets synced up
#@rpc('any_peer', "call_local")
#func create_new_lobby(lobby_id: String):
	#if !multiplayer.is_server():
		#create_new_lobby.rpc_id(1, lobby_id)
		#return
	#
	#print('something is making a lobby')
	#
	#var lobby_scene : Lobby = LOBBY.instantiate()
	#lobby_scene.name = str(lobby_id)
	#add_child(lobby_scene, true)

func _ready():
	$MultiplayerSpawner.spawn_function = _custom_lobby_spawn

# The server calls this to build the lobby package
@rpc("any_peer", "call_remote", "reliable")
func create_new_lobby(lobby_id: String, players_in_lobby: Array[int]):
	if multiplayer.is_server():
		var data = { "id": lobby_id, "players": players_in_lobby }
		$MultiplayerSpawner.spawn(data)
		lobbies[lobby_id] = players_in_lobby
		ServerDatabase.update_lobbies(lobbies)

# This runs on EVERY machine when the lobby spawns
func _custom_lobby_spawn(data: Dictionary) -> Node:
	var lobby_scene: Lobby = LOBBY.instantiate()
	lobby_scene.name = str(data["id"]).validate_node_name()
	lobby_scene.players_ids = data["players"]
	
	# THE HACK: If I am a client, and I am not in this lobby's player list...
	if not multiplayer.is_server() and multiplayer.get_unique_id() not in data["players"]:
		# Turn off rendering
		#lobby_scene.visible = false #TODO
		# Completely disable physics, _process, and interactions
		lobby_scene.process_mode = Node.PROCESS_MODE_DISABLED     
	return lobby_scene

@rpc("any_peer","call_remote",'reliable')
func add_player_to_lobby(lobby_id : String, player_id : int):
	print('button')
	if !multiplayer.is_server():
		print('playerp ressed')
		add_player_to_lobby.rpc_id(1, lobby_id, player_id)
		return
	print('server  ressed')
	if lobbies.has(lobby_id):
		lobbies[lobby_id].append(player_id)
		ServerDatabase.update_lobbies(lobbies)
		print('joined lobby ', lobby_id)
	else:
		print("lobby does not exist :(")


func _on_create_lobby_button_pressed() -> void:
	if !multiplayer.is_server():
		var array_of_player :Array[int] = []
		create_new_lobby.rpc_id(1, "server_lobby_" + str(randi_range(1,9999)), array_of_player)
		return
	
