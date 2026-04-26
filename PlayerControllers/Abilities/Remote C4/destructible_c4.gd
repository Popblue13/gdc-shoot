extends DestructibleProp

signal reset_c4


func _ready():
	health = 1.0


func destroy_effect():
	health = 1.0
	reset_c4.emit()
	dead = false
