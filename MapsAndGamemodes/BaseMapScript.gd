@abstract
class_name Map extends Node3D
@export var player_spawner : MultiplayerSpawner

#implementspawnpoint system and gamemode system
#create a trello of what we need to do and a general flow chart
#call start_gamemode to start the game

func _ready() -> void:#<ALL>
	register_players()

@abstract
func start_gamemode()

@abstract
func end_gamemode()

func _game_ended(): #<1>
	if !multiplayer.is_server(): return
	pass

func register_players(): #<ALL>
	player_spawner.clear_spawnable_scenes()
	
	for key in ServerDatabase.Maps:
		var scene : PackedScene = ServerDatabase.Mercs[key]
		if scene and scene.resource_path != "":
			player_spawner.add_spawnable_scene(scene.resource_path)

func _spawn_player(spawn_data:Dictionary):
	#TODO throw error if dict does not match
	var merc_spanwed : PackedScene = ServerDatabase[spawn_data["merc_type"]]
	var merc_real : Merc = merc_spanwed.instantiate()
	
	merc_real.global_position = spawn_data["position"]
	
	return merc_real #DONT FOGET THIS BASTAD

func get_lobby_player_ids(): return int(name)
