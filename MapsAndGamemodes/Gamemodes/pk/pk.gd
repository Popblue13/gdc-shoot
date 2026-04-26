extends Map
class_name PK
#sandbox
const LEADER_BOARD = preload("res://MapsAndGamemodes/Gamemodes/PresetGamemodeWidgets/Leaderboard/LeaderBoard.tscn")

var leaderboard: LeaderBoard 
@export var player_spawn: Node3D
@export var respawn_delay: float = 5.0 
@export var gamemode_length = 900.0

var respawn_trackers: Dictionary[int, Dictionary] = {}

func _ready() -> void:
	leaderboard = LEADER_BOARD.instantiate()
	add_child(leaderboard)
	
func _process(delta: float) -> void:
	if !multiplayer.is_server(): return
	
	for player_id in respawn_trackers.keys():
		var tracker = respawn_trackers[player_id]
		
		if tracker["is_dead"]:
			tracker["respawn_timer"] -= delta
			if tracker["respawn_timer"] <= 0.0:
				_respawn_player(player_id)

func player_died(merc: Merc, killer_id : int = 0):
	if !multiplayer.is_server(): return
	var player_id = merc.name.to_int()
	
	# Update Map logic (Respawns)
	if respawn_trackers.has(player_id):
		respawn_trackers[player_id]["is_dead"] = true
		respawn_trackers[player_id]["respawn_timer"] = respawn_delay
	
	# Update Leaderboard logic
	if leaderboard:
		leaderboard.record_death(player_id)
		
	merc.queue_free()

func _respawn_player(player_id: int):
	respawn_trackers[player_id]["is_dead"] = false
	
	if not has_node(str(player_id)):
		player_spawner.spawn({
			"merc_type": "default", 
			"position": Vector3.ZERO,
			"peer_id": player_id
		})
		print("Player ", player_id, " respawned!")

func _on_player_joined(player_id: int) -> void:
	if not multiplayer.is_server(): return
	
	# Setup Map Respawn Tracker
	respawn_trackers[player_id] = { "is_dead": true, "respawn_timer": 0.0 }
	
	# Setup Leaderboard Stats
	if leaderboard:
		leaderboard.add_player(player_id)

func _on_player_left(player_id: int) -> void:
	if !multiplayer.is_server(): return
	
	respawn_trackers.erase(player_id)
	if leaderboard:
		leaderboard.remove_player(player_id)
	
	var merc_node = get_node_or_null(str(player_id))
	if merc_node:
		merc_node.queue_free()

func start_gamemode():
	if !multiplayer.is_server(): return
	await get_tree().create_timer(gamemode_length).timeout
	_game_ended()
