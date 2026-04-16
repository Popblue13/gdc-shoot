extends Node3D

@onready var area = $Area3D
var uses = 0

func _ready() -> void:
	visible = true
	$Area3D.monitoring = true

func _on_eye_box_eye_closed() -> void:
	visible = true
	$Area3D.monitoring = true

func _on_area_3d_body_entered(body: Node3D) -> void:
	#if not is_multiplayer_authority(): return
	
	if body is Merc and not body.is_in_group("meat_eater"):
		body.health += 5
		body.add_to_group("meat_eater")
		$AudioStreamPlayer3D.play()
		visible = false
		$Area3D.monitoring = false
