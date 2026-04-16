extends MultiMeshInstance3D

func _ready() -> void:
	$StaticBody3D/CollisionShape3D3.disabled = false
	$door1.visible = true
	$door2.visible = true

func _on_eye_box_eye_closed() -> void:
	$StaticBody3D/CollisionShape3D3.disabled = true
	$door1.visible = false
	$door2.visible = false
