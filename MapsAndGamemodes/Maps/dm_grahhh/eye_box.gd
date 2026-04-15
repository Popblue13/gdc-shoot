extends Merc

@onready var audio = $AudioStreamPlayer3D

# Called when the node enters the scene tree for the first time.
func take_damage(damage):
	audio.play()
