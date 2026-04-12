extends Control

var current_lobby : String
@onready var vhs_off_anim: AnimatedSprite2D = $"../VHSOffAnim"


func _ready() -> void:
	ServerDatabase.connect("lobbies_updated", update_lobby_ui)
	

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("menu"):
		visible = !visible
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func update_lobby_ui():
	for i : String in ServerDatabase.Lobbies:
		if ServerDatabase.Lobbies[i].has(multiplayer.get_unique_id()):
			current_lobby = i

func _on_leave_lobby_pressed() -> void:
	# 1. Don't do anything if we are already in the home lobby
	if current_lobby == "home":
		return
	

	var lobby_container : LobbyContainer = get_tree().get_first_node_in_group("LobbyContainer")
	if lobby_container:
		var my_id = multiplayer.get_unique_id()
		# The LobbyContainer script already routes this to the server internally!
		lobby_container.wake_up_lobby('home')
		lobby_container.change_lobby("home", my_id)
	
	# 2. Play the transition animation
	vhs_off_anim.play("off")
	await vhs_off_anim.animation_finished
	hide()
