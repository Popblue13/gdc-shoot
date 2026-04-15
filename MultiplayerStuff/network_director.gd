extends Node

@onready var lobby_container: LobbyContainer = $LobbyContainer
@onready var join_screen: Control = $JoinScreen
@onready var btn_csdev: Button = $JoinScreen/Panel/Button
@onready var btn_local: Button = $JoinScreen/Panel/Button2

func _ready() -> void:
	if OS.has_feature("server") or "--server" in OS.get_cmdline_args():
		join_screen.hide() # Hide the UI on the server
		_setup_server()
	else:
		# We are a player. Connect the UI buttons!
		btn_csdev.pressed.connect(_on_join_csdev_pressed)
		btn_local.pressed.connect(_on_join_local_pressed)

func _on_join_csdev_pressed() -> void:
	join_screen.hide()
	_setup_client("csdev03.d.umn.edu")

func _on_join_local_pressed() -> void:
	# Stripped down to simply hide the UI and attempt connection
	join_screen.hide()
	_setup_client("127.0.0.1")

func _setup_server():
	get_window().position.x -= ceil(get_window().size.x / 2.0 + 8)
	var server_logic = ServerLogic.new()
	server_logic.lobby_container = lobby_container
	add_child(server_logic)

func _setup_client(ip: String):
	randomize()
	get_window().position.x += ceil(get_window().size.x / 2.0 + 8)
	var client_logic = ClientLogic.new()
	client_logic.lobby_container = lobby_container
	
	# Pass the requested IP to the ClientLogic script
	client_logic.set_meta("target_ip", ip) 
	
	add_child(client_logic)
