extends StaticBody3D

@export var tp_marker : Marker3D
@export var makes_noise:bool = false
@export var noise :AudioStreamPlayer3D


func _on_area_3d_body_entered(body: Node3D) -> void:
	
	body.global_position = tp_marker.global_position
	if makes_noise:
		noise.play()
