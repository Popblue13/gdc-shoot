extends DestructibleProp

@onready var scream = $AudioStreamPlayer3D
@onready var hurt = $AudioStreamPlayer3D2
@onready var mesh = $Eye

signal eye_closed()


func _ready():
	health = 100.0
	mesh.material_override = load("res://MapsAndGamemodes/Maps/dm_grahhh/eyeopen.tres")

# Called when the node enters the scene tree for the first time.

func _physics_process(delta):
	pass # Disables movement and gravity processing

func _process(delta):
	pass 

func _input(event):
	pass

func close():
	scream.play()
	mesh.material_override = load("res://MapsAndGamemodes/Maps/dm_grahhh/eyeclosed.tres")
	
	eye_closed.emit()
	$Timer.start()

@rpc("any_peer", "call_local", "reliable")
func take_damage(damage: float):
	if dead:return
	health -= damage
	hurt.pitch_scale = randf_range(0.8, 1.2)
	hurt.play()
	if health <= 0 and not dead:
		dead = true
		close()


func _on_timer_timeout() -> void:
	mesh.material_override = load("res://MapsAndGamemodes/Maps/dm_grahhh/eyeopen.tres")
	health = 100
	dead = false
