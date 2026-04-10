extends Control
@onready var v_box_container: VBoxContainer = $Panel/ScrollContainer/VBoxContainer
const LOBBY_INFO = preload("res://MultiplayerStuff/Server/Lobby/lobby_info.tscn")

func _ready() -> void:
	
	ServerDatabase.connect("lobbies_updated", create_lobby_views)
	create_lobby_views()
	
func create_lobby_views():
	for i in v_box_container.get_children():
		i.queue_free()
	
	for i in ServerDatabase.Lobbies:
		var lobby_info : LobbyInfo = LOBBY_INFO.instantiate()
		lobby_info.init(i, ServerDatabase.Lobbies[i]) #HACK
		v_box_container.add_child(lobby_info)
