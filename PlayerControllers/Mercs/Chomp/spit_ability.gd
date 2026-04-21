extends Ability

var is_activated : bool = false
var on_cooldown : bool = false
const GLOOP = preload("uid://d0fhprspiggrl")
@onready var camera_3d: Camera3D = $"../Camera3D"
@onready var crosshair_002: Sprite2D = $"../Crosshair002"
@onready var timer: Timer = $Timer

@export var size : int = 2
@export var speed : int = 100
@export var gloop_time : float = 4
@export var cooldown : float = 0.5

func activate() -> void:
	is_activated = not is_activated
	
func _process(_delta: float) -> void:
	if not is_activated or on_cooldown:
		crosshair_002.visible = false
		return
		
	crosshair_002.visible = true
	if Input.is_action_just_pressed("left_click"):
		timer.start(cooldown)
		on_cooldown = true
		var gloop = GLOOP.instantiate()
		get_parent().get_parent().add_child(gloop)
		gloop.add_collision_exception_with(get_parent())
		gloop.scale *= size
		gloop.gloop_time = gloop_time
		gloop.global_position = get_parent().global_position
		gloop.velocity = speed * camera_3d.project_ray_normal(crosshair_002.position)


func _on_timer_timeout() -> void:
	on_cooldown = false
