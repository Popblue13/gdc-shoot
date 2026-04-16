extends Sprite3D

var targetposition = position
var sourceposition = position
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	targetposition = Vector3(position.x+randf(), position.y+randf(), position.z+randf())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position = lerp(position, targetposition, 0.03)


func _on_timer_timeout() -> void:
	targetposition = Vector3(position.x+randf(), position.y+randf(), position.z+randf())
	if randi_range(1, 3) == 1:
		targetposition = sourceposition
