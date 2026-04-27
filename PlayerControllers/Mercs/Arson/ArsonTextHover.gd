extends Node3D

@export var hover_height: float = 0.5   # How far up/down it moves from center
@export var cycle_speed: float = 2.0    # Time in seconds for one direction
@export var random_start: bool = true   # Prevents multiple items from moving in sync

func _ready():
	if random_start:
		# Randomize the starting position so they aren't all in sync
		var random_delay = randf_range(0.0, cycle_speed)
		get_tree().create_timer(random_delay).timeout.connect(start_hover)
	else:
		start_hover()

func start_hover():
	# Store the starting position so we hover relative to where it was placed
	var start_pos = position
	var target_pos = start_pos + Vector3(0, hover_height, 0)
	
	var tween = create_tween().set_loops().set_parallel(false)
	
	# Move Up
	tween.tween_property(self, "position", target_pos, cycle_speed)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Move Down
	tween.tween_property(self, "position", start_pos, cycle_speed)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
