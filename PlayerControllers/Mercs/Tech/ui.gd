extends Control

func add_bolts(amount):
	for i in amount:
		var bolts_scene = load("res://PlayerControllers/Mercs/Tracker/dartUI.tscn").instantiate()
		$VBoxContainer.add_child(bolts_scene)

func remove_bolts(amount):
	for i in amount:
		if $VBoxContainer.get_children()[0]:
			$VBoxContainer.get_children()[0].queue_free()
		else:
			return

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	if !is_multiplayer_authority(): return
	visible = true
