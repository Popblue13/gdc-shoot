extends Control
@onready var spectator: Button = $Spectator

signal side_chosen(side : String)
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide()
	if get_parent() is not DE:
		spectator.hide()

func _on_red_pressed() -> void:
	side_chosen.emit('red')
	hide()

func _on_blue_pressed() -> void:
	side_chosen.emit('blue')
	hide()

func _on_spectator_pressed() -> void:
	side_chosen.emit('spectator')
	hide()
