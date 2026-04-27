extends OneShotAbility

@onready var sprite = $Sprite2D
@export var guns :Array[Node3D]
@export var camera :Camera3D

var showing :bool = false

func _ready() -> void:
	merc = get_parent()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("right_click"):
		if !is_multiplayer_authority(): return
		_on_activate_just_pressed()

@rpc("any_peer", "call_local", "reliable")
func sound_play():
	$AudioStreamPlayer3D.play()

@rpc("any_peer", "call_remote", "reliable")
func _on_activate_just_pressed():
	showing = !showing
	sound_play.rpc()
	
	if !is_multiplayer_authority(): return
	match showing:
		true:
			$Control.visible = true
			for gun in guns:
				gun.visible = false
			camera.fov = 18
			merc.mouse_sensitivity = 0.002
		false:
			$Control.visible = false
			for gun in guns:
				if gun.equipped == true:
					gun.visible = true
			camera.fov = 90
			merc.mouse_sensitivity = 0.005
