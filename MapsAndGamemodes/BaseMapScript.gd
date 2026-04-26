@abstract
class_name Map extends Node3D
#DO NOT EDIT THIS CODE
signal map_ready # The signal the Lobby is waiting for

var player_spawner : MultiplayerSpawner
var player_data_base : Dictionary[int, Dictionary]
var is_map_ready : bool = false # Lobby checks this for mid-game joiners
@export var map_name : String = 'default'
@export var environment : Environment
@export var characters_allowed : Array[String]
var orb_container: Node3D
var orb_spawner: MultiplayerSpawner

# You will need to put the path to your generic AbilityPickup.tscn here!
var pickup_orb_scene = preload("res://MapsAndGamemodes/Gamemodes/PresetGamemodeWidgets/AbilityPickup/ability_pickup.tscn") 

func _enter_tree() -> void:
	player_spawner = MultiplayerSpawner.new()
	player_spawner.name = "player_spawner"
	add_child(player_spawner)
	
	player_spawner.spawn_path = get_path()
	player_spawner.spawn_limit = 58
	
	player_spawner.spawn_function = _spawn_player
	register_players()
	
	orb_container = Node3D.new()
	orb_container.name = "DroppedOrbs"
	add_child(orb_container)
	
	orb_spawner = MultiplayerSpawner.new()
	orb_spawner.name = "OrbSpawner"
	add_child(orb_spawner)
	orb_spawner.spawn_path = ".."
	orb_spawner.spawn_function = _spawn_orb_network
	
	var parent_lobby = get_parent()
	if parent_lobby is Lobby:
		# Connect directly to your abstract functions now! No queue needed.
		
		parent_lobby.player_joined_lobby.connect(_on_player_joined)
		parent_lobby.player_left_lobby.connect(_on_player_left)
		multiplayer.peer_disconnected.connect(_disconnected_player)
	
	
	if !multiplayer.is_server(): return
	call_deferred("_finalize_setup")

func _finalize_setup() -> void:
	is_map_ready = true
	map_ready.emit() # Tell the Lobby: "Send me the players!"
	
	if multiplayer.is_server():
		start_gamemode()

func _game_ended(): #<1>
	if !multiplayer.is_server(): return
	var parent_lobby = get_parent()
	if parent_lobby is Lobby:
		parent_lobby.game_end()

func register_players(): #<ALL> registers MERCS
	player_spawner.clear_spawnable_scenes()
	
	for key in ServerDatabase.Mercs:
		var scene : PackedScene = ServerDatabase.Mercs[key]
		if scene and scene.resource_path != "":
			player_spawner.add_spawnable_scene(scene.resource_path)

func _spawn_player(spawn_data:Dictionary):
	#TODO throw error if dict does not match
	if !ServerDatabase.Mercs.keys().has(spawn_data["merc_type"]):
		spawn_data["merc_type"] = "default"
	
	var merc_spanwed : PackedScene = ServerDatabase.Mercs[spawn_data["merc_type"]]
	var merc_real : Merc = merc_spanwed.instantiate()
	
	
	merc_real.name = str(spawn_data["peer_id"])
	merc_real.debug_mode = false
	merc_real.set_multiplayer_authority(int(spawn_data["peer_id"]))
	merc_real.position = spawn_data["position"]
	
	merc_real.died.connect(player_died)
	merc_real.died.connect(kill_confirmed)
	return merc_real #DONT FOGET THIS BASTAD

func get_lobby_player_ids(): return int(name)

func _exit_tree() -> void:
	if multiplayer.is_server():
		_cleanup_network_nodes()

func _cleanup_network_nodes() -> void:
	for child in get_children():
		child.queue_free()

func _disconnected_player(peer_id : int):
	if !multiplayer.is_server(): return
	var player = get_node_or_null(str(peer_id))
	
	if player: 
		player.queue_free()
		print("Player ", peer_id, " removed successfully.")
	else:
		print("Could not find player to remove: ", peer_id)

func kill_confirmed(merc: Merc, killer_id: int = 0):
	if not multiplayer.is_server(): return
	
	var victim_id = merc.name.to_int()
	
	# If there was a killer, and it wasn't a suicide (like falling off the map)
	if killer_id != 0 and killer_id != victim_id:
		var killer_node = get_node_or_null(str(killer_id))
		
		# Ping the killer's specific client so they get immediate visual/audio feedback
		if killer_node and killer_node.has_method("notify_kill_confirmed"):
			killer_node.notify_kill_confirmed.rpc_id(killer_id, victim_id)


# Called by Merc.gd when dropping an item
func spawn_dropped_orb(ability_resource_path: String, drop_position: Vector3) -> void:
	if not multiplayer.is_server(): return
	
	# Package the data to send to the spawner
	var spawn_data = {
		"path": ability_resource_path,
		"pos": drop_position
	}
	orb_spawner.spawn(spawn_data)

# The network spawner function
func _spawn_orb_network(data: Variant) -> Node:
	var spawn_data = data as Dictionary
	var orb_instance = pickup_orb_scene.instantiate()
	
	# Inject the specific ability scene so the orb knows what it holds
	orb_instance.ability_scene = load(spawn_data["path"])
	orb_instance.position = spawn_data["pos"]
	
	return orb_instance
@abstract func start_gamemode()
@abstract func player_died(merc : Merc, killer_id: int = 0)
@abstract func _on_player_joined(player_id: int)
@abstract func _on_player_left(player_id: int)
#@abstract func custom_ready()
