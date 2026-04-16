extends CSGMesh3D

@export var damage = 1000
@onready var area = $Area3D
@onready var eaturmeat = $AudioStreamPlayer3D
@onready var meatnoticed = $AudioStreamPlayer3D3
@onready var puddingalarm = $AudioStreamPlayer3D2
@onready var safetytimer = $Timer

@export var jello : StaticBody3D

func _on_area_3d_body_entered(body: Node3D) -> void:
	
	if body is Merc:
		
		if body.is_in_group("meat_eater"):
			meatnoticed.play()
			area.monitoring = false
			safetytimer.start()
			jello.activate()
			body.remove_from_group("meat_eater")
		else:
			eaturmeat.play()
			body.take_damage.rpc_id(body.name.to_int(), damage) 

func _on_timer_timeout() -> void:
	area.monitoring = true
	puddingalarm.play()
