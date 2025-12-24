extends Node

const SERVER_PORT = 8080
const SERVER_IP = "127.0.0.1"

var player = preload("res://Player Conrollers/Default/FirstPersonController.tscn")
var level = preload("res://Maps/Default.tscn")

var _players_spawn_node
var host_mode_enabled = false
var multiplayer_mode_enabled = false
var respawn_point = Vector2(30, 20)

func _ready():
	if OS.has_feature("dedicated_server"):
		print("Starting dedicated server...")
		become_host()

func become_host():
	print("Starting host!")
	
	multiplayer_mode_enabled = true
	host_mode_enabled = true
	
	var server_peer = ENetMultiplayerPeer.new()
	server_peer.create_server(SERVER_PORT)
	
	multiplayer.multiplayer_peer = server_peer
	
	
	multiplayer.peer_disconnected.connect(_del_player)
	
	load_level()
	
	
	if not OS.has_feature("dedicated_server"):
		_add_player_to_game(1)

func load_level():
	var scene : Level = level.instantiate()
	get_tree().get_current_scene().add_child(scene)
	_players_spawn_node = scene.player_spawn
	
	if !multiplayer.is_server():
		rpc_id(1, "i_am_ready_to_play")
	
func join_as_player():
	print("Player 2 joining")
	
	multiplayer_mode_enabled = true
	
	var client_peer = ENetMultiplayerPeer.new()
	client_peer.create_client(SERVER_IP, SERVER_PORT)
	multiplayer.multiplayer_peer = client_peer
	
	while client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		await get_tree().process_frame
	
	load_level()

@rpc("any_peer", "call_remote")
func i_am_ready_to_play():
	var id = multiplayer.get_remote_sender_id()
	print("Client %s is ready. Spawning them now." % id + "sent from server ;)")
	_add_player_to_game(id)
	
func _add_player_to_game(id: int):
	# CRITICAL: Only the server is allowed to create nodes.
	# The MultiplayerSpawner will automatically copy them to the clients.
	if not multiplayer.is_server():
		return
	
	print("Player %s joined the game!" % id)
	
	var player_to_add = player.instantiate()
	player_to_add.name = str(id)
	
	_players_spawn_node.add_child(player_to_add, true)	
	
func _del_player(id: int):
	print("Player %s left the game!" % id)
	if not _players_spawn_node.has_node(str(id)):
		return
	_players_spawn_node.get_node(str(id)).queue_free()
