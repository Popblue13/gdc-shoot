extends Node
@onready var lobby_container: LobbyContainer = $LobbyContainer

func _ready() -> void:
	if OS.has_feature("server") or "--server" in OS.get_cmdline_args():
		_setup_server()
	else:
		await get_tree().create_timer(1).timeout
		_setup_client()

func _setup_server():
	get_window().position.x -= ceil(get_window().size.x / 2.0 + 8)
	var server_logic = ServerLogic.new()
	server_logic.lobby_container = lobby_container
	add_child(server_logic)

func _setup_client():
	randomize()
	get_window().position.x += ceil(get_window().size.x / 2.0 + 8)
	get_window().position.y += ceil(get_window().size.y / 2.0 + randf_range(-8,8))
	var client_logic = ClientLogic.new()
	add_child(client_logic)
