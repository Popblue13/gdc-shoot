extends Ability
@onready var mesh = $Hydeball
@onready var area = $Area3D
var safe_merc

var ball_activated = false
func activate():
	$AudioStreamPlayer3D.playing = true
	ball_activated = true
	visible = true
	safe_merc = merc
	area.monitoring = true
	global_position = merc.global_position
	top_level = true

func _process(delta: float) -> void:
	if ball_activated == true:
		mesh.rotation.y += 0.1

func _on_area_3d_body_entered(body: Node3D) -> void:
	var damage = 1000
	if body != safe_merc and body is Merc:
		body.take_damage.rpc_id(body.name.to_int(), damage) 
