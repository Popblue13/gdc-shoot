extends OneShotAbility

@onready var sprite = $Sprite2D
@export var guns :Array[Node3D]
@export var camera :Camera3D

var showing :bool = false

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("right_click"):
		$AudioStreamPlayer3D.play.rpc()
		if !is_multiplayer_authority(): return
		_on_activate_just_pressed()
		

#@rpc("any_peer", "call_remote", "reliable")
func _on_activate_just_pressed():
	$AudioStreamPlayer3D.play()
	showing = !showing
	
	match showing:
		true:
			$Control.visible = true
			for gun in guns:
				gun.visible = false
			camera.fov = 18
		false:
			$Control.visible = false
			for gun in guns:
				if gun.equipped == true:
					gun.visible = true
			camera.fov = 90
