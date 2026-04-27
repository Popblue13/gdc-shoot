extends Node3D
@onready var arson = $".."


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if arson:
		if "ImReal" in arson:
			queue_free()
			# for some reason this is the only way I found to remove the models if they arent in the preview lol
