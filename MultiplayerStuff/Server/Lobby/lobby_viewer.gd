extends Control
class_name LobbyViewer
@onready var v_box_container: VBoxContainer = $Panel/ScrollContainer/VBoxContainer
const LOBBY_INFO = preload("res://MultiplayerStuff/Server/Lobby/lobby_info.tscn")
@onready var background: ColorRect = $Background
@onready var animation: AnimatedSprite2D = $Animation
@onready var panel: Panel = $Panel

func _ready() -> void:
	ServerDatabase.connect("lobbies_updated", create_lobby_views)
	create_lobby_views()
	animation.hide()
func open():
	show()
	var tween = create_tween()
	tween.tween_property(background, "modulate:a", 1.0, .3)
	await tween.finished
	animation.play("on")
	animation.show()
	panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close():
	animation.play("off")
	await animation.animation_finished
	animation.hide()
	panel.hide()
	var tween = create_tween()
	tween.tween_property(background, "modulate:a", 0.0, .3)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hide()

func switch_cams(): #could add glitch effects here
	hide()

func create_lobby_views():
	for i in v_box_container.get_children():
		i.queue_free()
	
	for i in ServerDatabase.Lobbies:
		if i != 'home':
			var lobby_info : LobbyInfo = LOBBY_INFO.instantiate()
			lobby_info.init(i, ServerDatabase.Lobbies[i]) #HACK
			v_box_container.add_child(lobby_info)


func _on_create_lobby_button_pressed() -> void:
	var lobby_container :LobbyContainer= get_tree().get_first_node_in_group("LobbyContainer")
	if lobby_container:
		lobby_container._on_create_lobby_button_pressed()

func _on_leave_seat_pressed() -> void:
	var local_id = multiplayer.get_unique_id()
	var lobby_container = get_tree().get_first_node_in_group("LobbyContainer")
	
	if lobby_container:
		# Navigate down to the exact path where the home bodies are stored
		var home_lobby : Lobby = lobby_container.get_node_or_null("home")
		var home_map = home_lobby.get_node_or_null("home")
		
		if home_map:
			# Find your specific character in the home map
			var my_body = home_map.get_node_or_null(str(local_id))
			
			# Check if the body exists, has a chair property, and is currently in a chair
			if my_body and "current_chair" in my_body and my_body.current_chair:
				my_body.current_chair.request_leave_chair.rpc_id(1)
			else:
				print("You are not currently sitting in a chair!")
		else:
			print("Could not find the home map at LobbyContainer/home/home")
