extends HBoxContainer
class_name LobbyInfo

@onready var lobby_id: RichTextLabel = $LobbyID
@onready var player_ids: RichTextLabel = $PlayerCount
@onready var button: Button = $Button

#signal join_pressed(_lobby_id, _player_id)

func init(lobby_id : String, player_ids : Array[int]):
	await ready
	self.lobby_id.text = lobby_id
	self.player_ids.text = str(player_ids.size())
	
func _on_button_pressed() -> void:
	
	var lobby_container = get_tree().get_first_node_in_group("LobbyContainer")
	print(lobby_container)
	if lobby_container: #HACK
		lobby_container.add_player_to_lobby(lobby_id.text,  multiplayer.get_unique_id())
	#join_pressed.emit(lobby_id.text, multiplayer.get_unique_id())
