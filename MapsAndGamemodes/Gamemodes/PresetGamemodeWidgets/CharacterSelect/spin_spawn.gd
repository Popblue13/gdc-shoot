extends Marker3D

@export var rotation_speed: float = 0.8  # Radians per second
@export var is_spinning: bool = true

func _process(delta: float) -> void:
	if is_spinning:
		rotate_y(rotation_speed * delta)
# I did this because I was tired of seeing my character look buggy/jittery in the selection menu
