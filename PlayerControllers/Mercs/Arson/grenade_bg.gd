extends Sprite2D

@export var base_angle: float = -25.0      # The "rest" position (e.g., tilted 45 degrees)
@export var rotation_range: float = 5.0   # How many degrees to sway from the base
@export var cycle_speed: float = 0.8      # How fast to swing

func _ready():
	# Set the initial rotation to the base angle immediately
	rotation_degrees = base_angle
	start_sway()

func start_sway():
	var tween = create_tween().set_loops()
	
	# Rotate to the "right" of the base angle
	tween.tween_property(self, "rotation_degrees", base_angle + rotation_range, cycle_speed)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Rotate to the "left" of the base angle
	tween.tween_property(self, "rotation_degrees", base_angle - rotation_range, cycle_speed)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
