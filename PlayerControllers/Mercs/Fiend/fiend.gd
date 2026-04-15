class_name Fiend extends Merc

@onready var animation_player: AnimationPlayer = $cat/AnimationPlayer

func custom_process(_delta : float):
	if velocity.length() > .5:
		animation_player.play()
	else:
		animation_player.pause()


func custom_ready():
	animation_player.play("walk")
