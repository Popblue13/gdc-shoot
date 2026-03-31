extends Map
class_name SB
#sandbox

@export var player_spawn : Node3D

func _ready() -> void:
	if !multiplayer.is_server(): return
	start_gamemode()

func start_gamemode():
	return
	for i in get_lobby_player_ids():
		#_spawn_player({"default" = ServerDatabase.Mercs["default"], "position" = Vector3.ZERO})
		print('server spawned')

func end_gamemode():
	pass
