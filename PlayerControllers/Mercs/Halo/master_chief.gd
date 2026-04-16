extends Merc
@onready var hud: Sprite2D = $Hud

func custom_ready():
	if is_multiplayer_authority(): 
		hud.show()
	else:
		hud.hide()
