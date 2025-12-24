extends Control


func _on_host_pressed() -> void:
	MultiplayerDirector.become_host()
	hide()

func _on_join_pressed() -> void:
	MultiplayerDirector.join_as_player()
	hide()
