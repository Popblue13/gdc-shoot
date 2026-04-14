extends Merc

@onready var DEBUGUI = $DEBUGUI

#nothing here! other than some basic ui and text stuff!
func custom_process(delta : float): 
	return
	DEBUGUI.text = str(snapped((velocity.length()), 0.01))

func twerk():
	$"Dancing Twerk/AnimationPlayer".play("mixamo_com")

func custom_ready():
	pass
