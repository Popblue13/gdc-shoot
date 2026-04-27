extends Sprite2D

var rotation_speed_default = 45.0  # Degrees per second
var rotation_speed

@export var arson_flamethrower: Node3D

func _process(delta):
	# Rotate by adding speed * delta
	if (arson_flamethrower.visible):
		spin(delta)
	else:
		pass

func spin(delta):
	if arson_flamethrower.is_firing:
		rotation_speed = rotation_speed_default*15
	elif arson_flamethrower.is_reloading:
		rotation_speed = rotation_speed_default*-30
	else:
		rotation_speed = rotation_speed_default
	rotation_degrees += rotation_speed * delta
