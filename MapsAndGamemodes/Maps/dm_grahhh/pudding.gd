extends StaticBody3D

@onready var area = $Area3D

func _ready() -> void:
	visible = false
	area.monitoring = false

func _on_area_3d_body_entered(body: Node3D) -> void:
	
	
	if body is Merc:
		body.health += 50
		body.speed += 0.1
		area.monitoring = false
		visible = false

func activate():
	area.monitoring = true
	visible = true
