extends CharacterBody3D

@onready var timer: Timer = $Timer
var gloop_time : float
var dad : Merc

func _physics_process(delta: float) -> void:
	move_and_slide()
	if get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			if get_slide_collision(i).get_collider_shape().get_parent() is Merc:
				velocity = Vector3(0,0,0)
				timer.start(gloop_time)
				reparent(get_slide_collision(i).get_collider_shape().get_parent())
				dad = get_parent()
				return
	if dad:
		dad.velocity /= 2


func _on_timer_timeout() -> void:
	queue_free()
