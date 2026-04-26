extends Control

@onready var money_size: Vector2 = $"Remaining Money".size
@onready var ammo_size: Vector2 = $Ammo.size

func _ready() -> void:
	visible = is_multiplayer_authority()
	
	## Godot doesn't have a base "expand left" setting for text boxes, so this manually moves the label when it expands to keep the right edge from moving
	$"Remaining Money".minimum_size_changed.connect(
		func() -> void:
			$"Remaining Money".position += money_size - $"Remaining Money".size
			money_size = $"Remaining Money".size
	)

	return
	
#func _process(delta: float) -> void:
	#if !is_multiplayer_authority(): return
	#return
