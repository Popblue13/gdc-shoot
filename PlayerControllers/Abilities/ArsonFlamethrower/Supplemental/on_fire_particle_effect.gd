extends Node3D

var velocity: Vector3 = Vector3.ZERO
var lifetime: float = 1.5 # How long the flame lasts
@onready var animated_sprite_3d: AnimatedSprite3D = $AnimatedSprite3D


func _process(delta):
	# Move the flame
	global_position += velocity * delta
	
	# Shrink it over time for a "burning out" effect
	scale -= Vector3.ONE * (delta / lifetime)
	
	# Kill the node when it's too small or old
	lifetime -= delta
	if lifetime <= 0 or scale.x <= 0:
		queue_free()
