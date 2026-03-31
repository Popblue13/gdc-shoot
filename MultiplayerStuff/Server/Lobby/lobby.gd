extends Node
class_name Lobby

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

var lobby_id : int
var players_ids : Array[int]

var current_map : Map

func _ready() -> void:
	register_spawnable_maps()
	

func register_spawnable_maps(): #<ALL>
	spawner.clear_spawnable_scenes()
	
	for key in ServerDatabase.Maps:
		var scene : PackedScene = ServerDatabase.Maps[key]
		if scene and scene.resource_path != "":
			spawner.add_spawnable_scene(scene.resource_path)

func change_map(map : String): #maps hold gamemodes #<1>
	if !multiplayer.is_server(): return
	if current_map: current_map.queue_free()
	
	var new_map : Map = ServerDatabase.Maps[map].instantiate()
	new_map.name = str(lobby_id)
	add_child(new_map)
	current_map = new_map
	

func game_end():
	pass
